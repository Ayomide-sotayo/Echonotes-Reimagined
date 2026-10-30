/**
 * EchoNotes Cloud Functions - Phase 8 Collection AI Assistant
 * Provides authenticated, owner-isolated cross-note retrieval and Gemini 2.5 Flash grounded Q&A.
 */

import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { chunkNote, BM25Ranker, NoteSource, Passage } from './bm25';
import { generateGroundedAnswer, GroundedCitation } from './gemini';

// Initialize Firebase Admin SDK
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

// Configurable beta limits
const DAILY_USER_QUERY_LIMIT = 15;
const MIN_REQUEST_INTERVAL_MS = 2500; // 2.5s cooldown
const MAX_QUESTION_LENGTH = 500;
const MAX_NOTES_PER_COLLECTION = 50;
const TOP_K_PASSAGES = 5;

export interface AskCollectionAIRequest {
  collectionId: string;
  question: string;
  conversationId?: string;
}

export interface AskCollectionAIResponse {
  answer: string;
  citations: GroundedCitation[];
  isInsufficientEvidence: boolean;
  conversationId: string;
  messageId: string;
  dailyQueriesRemaining: number;
}

/**
 * Cloud Function: askCollectionAI
 */
export const askCollectionAI = onCall<AskCollectionAIRequest>(
  {
    cors: true,
    maxInstances: 10,
    timeoutSeconds: 60,
  },
  async (request): Promise<AskCollectionAIResponse> => {
    const startTime = Date.now();

    // 1. Authenticate caller
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'User must be authenticated to use Collection AI.');
    }

    const { collectionId, question, conversationId: clientConversationId } = request.data || {};

    // 2. Validate input parameters
    if (!collectionId || typeof collectionId !== 'string' || collectionId.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'Valid collectionId is required.');
    }

    const trimmedQuestion = (question || '').trim();
    if (trimmedQuestion.length < 2) {
      throw new HttpsError('invalid-argument', 'Question is too short (min 2 characters).');
    }
    if (trimmedQuestion.length > MAX_QUESTION_LENGTH) {
      throw new HttpsError('invalid-argument', `Question exceeds maximum length of ${MAX_QUESTION_LENGTH} characters.`);
    }

    // 3. Verify Collection Ownership
    const colDocRef = db.collection('collections').doc(collectionId.trim());
    const colDocSnap = await colDocRef.get();

    if (!colDocSnap.exists) {
      throw new HttpsError('not-found', 'Collection not found.');
    }

    const colData = colDocSnap.data();
    if (!colData || colData.userId !== uid) {
      throw new HttpsError('permission-denied', 'You do not have permission to access this collection.');
    }

    const collectionName = colData.name || 'Collection';

    // 4. Atomic Rate-Limiting & Daily Quota Guard
    const todayStr = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
    const usageDocRef = db.collection('users').doc(uid).collection('usage').doc('daily_ai');

    let queriesRemaining = DAILY_USER_QUERY_LIMIT;

    await db.runTransaction(async (transaction) => {
      const usageSnap = await transaction.get(usageDocRef);
      const usageData = usageSnap.data() || {};

      const recordedDate = usageData.date || '';
      let currentCount = recordedDate === todayStr ? (usageData.count || 0) : 0;
      const lastTimestamp = usageData.lastRequestTimestamp ? usageData.lastRequestTimestamp.toMillis() : 0;

      // Cooldown check
      const elapsed = startTime - lastTimestamp;
      if (elapsed < MIN_REQUEST_INTERVAL_MS) {
        throw new HttpsError('resource-exhausted', 'Please wait a moment before sending another question.');
      }

      // Daily limit check
      if (currentCount >= DAILY_USER_QUERY_LIMIT) {
        throw new HttpsError('resource-exhausted', `Daily AI limit of ${DAILY_USER_QUERY_LIMIT} questions reached. Limit resets tomorrow.`);
      }

      currentCount += 1;
      queriesRemaining = DAILY_USER_QUERY_LIMIT - currentCount;

      transaction.set(usageDocRef, {
        date: todayStr,
        count: currentCount,
        lastRequestTimestamp: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    });

    // 5. Retrieve Collection Notes (Owner-scoped strictly by Firestore query)
    const notesSnap = await db
      .collection('notes')
      .where('userId', '==', uid)
      .where('collectionId', '==', collectionId.trim())
      .limit(MAX_NOTES_PER_COLLECTION)
      .get();

    const noteSources: NoteSource[] = [];
    for (const doc of notesSnap.docs) {
      const nData = doc.data();
      const content = (nData.transcription || nData.summary || '').trim();
      if (content.length > 0) {
        noteSources.push({
          id: doc.id,
          title: nData.title || 'Untitled Note',
          type: nData.type || 'text',
          content,
          createdAt: nData.createdAt?.toDate ? nData.createdAt.toDate().toISOString() : undefined
        });
      }
    }

    // 6. Passage Chunking & BM25 Scoring
    const allPassages: Passage[] = [];
    for (const note of noteSources) {
      const passages = chunkNote(note, 350, 50);
      allPassages.push(...passages);
    }

    const ranker = new BM25Ranker(1.5, 0.75);
    const scoredPassages = ranker.rank(trimmedQuestion, allPassages, TOP_K_PASSAGES);

    // 7. Execute Grounded Generation via Gemini 2.5 Flash
    const apiKey = process.env.GEMINI_API_KEY || '';
    if (!apiKey) {
      throw new HttpsError('internal', 'AI service configuration missing on server.');
    }

    const qaResult = await generateGroundedAnswer(apiKey, trimmedQuestion, scoredPassages, collectionName);

    // 8. Conversation Persistence (under /users/{uid}/conversations)
    let convId = clientConversationId?.trim();
    if (!convId || convId.length === 0) {
      // Auto-create new conversation document
      const newConvRef = db.collection('users').doc(uid).collection('conversations').doc();
      convId = newConvRef.id;

      // Extract brief title from question (max 40 chars)
      const convTitle = trimmedQuestion.length > 40 ? trimmedQuestion.slice(0, 37) + '...' : trimmedQuestion;

      await newConvRef.set({
        id: convId,
        title: convTitle,
        collectionId: collectionId.trim(),
        collectionName,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessage: qaResult.answer.slice(0, 80),
        messageCount: 2
      });
    } else {
      // Update existing conversation doc
      await db.collection('users').doc(uid).collection('conversations').doc(convId).set({
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessage: qaResult.answer.slice(0, 80),
        messageCount: admin.firestore.FieldValue.increment(2)
      }, { merge: true });
    }

    const messagesCol = db.collection('users').doc(uid).collection('conversations').doc(convId).collection('messages');

    // Store user question
    await messagesCol.add({
      sender: 'user',
      text: trimmedQuestion,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Store assistant answer with verified citations
    const assistantMsgRef = await messagesCol.add({
      sender: 'assistant',
      text: qaResult.answer,
      citations: qaResult.citations,
      isInsufficientEvidence: qaResult.isInsufficientEvidence,
      modelUsed: qaResult.modelUsed,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // 9. Operational Logging (Audit without private student transcript text)
    const durationMs = Date.now() - startTime;
    console.log(`[AskCollectionAI] uid=${uid} col=${collectionId} notes=${noteSources.length} passages=${allPassages.length} citations=${qaResult.citations.length} duration=${durationMs}ms`);

    return {
      answer: qaResult.answer,
      citations: qaResult.citations,
      isInsufficientEvidence: qaResult.isInsufficientEvidence,
      conversationId: convId,
      messageId: assistantMsgRef.id,
      dailyQueriesRemaining: queriesRemaining
    };
  }
);
