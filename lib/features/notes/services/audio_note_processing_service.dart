import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echonotes/features/notes/data/notes_model.dart';
import 'package:echonotes/services/assembly_ai_services.dart';
import 'package:echonotes/services/gemini_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AudioProcessingPhase {
  validating,
  uploading,
  transcribing,
  generatingAi,
  saving,
  completed,
  failed,
}

class AudioProcessingProgress {
  final AudioProcessingPhase phase;
  final String message;
  final double progress; // 0.0 to 1.0

  const AudioProcessingProgress({
    required this.phase,
    required this.message,
    required this.progress,
  });
}

/// Robust service orchestrating audio upload, AssemblyAI transcription,
/// Gemini smart titling/summary, and Firestore storage.
class AudioNoteProcessingService {
  final AssemblyAIService _assemblyAIService = AssemblyAIService();
  final GeminiService _geminiService = GeminiService();

  /// Process an audio file into a saved Firestore Note.
  /// [onProgress] receives progressive stage updates.
  /// [isCancelled] can be passed to abort mid-operation.
  /// [collectionId] is reserved for Phase 7 collection compatibility.
  Future<Note?> processAndSaveAudio({
    required File audioFile,
    required String originalName,
    required String fileExtension,
    String? mimeType,
    String? collectionId,
    String? collectionName,
    void Function(AudioProcessingProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User authentication session expired. Please sign in.');
    }

    // Phase 1: Validation
    onProgress?.call(
      const AudioProcessingProgress(
        phase: AudioProcessingPhase.validating,
        message: 'Validating recording format & integrity…',
        progress: 0.10,
      ),
    );

    if (!audioFile.existsSync() || audioFile.lengthSync() == 0) {
      throw Exception('The shared audio file is empty or could not be read.');
    }

    if (isCancelled?.call() == true) return null;

    // Phase 2: Upload to Supabase Storage
    onProgress?.call(
      const AudioProcessingProgress(
        phase: AudioProcessingPhase.uploading,
        message: 'Securing and uploading audio to private cloud…',
        progress: 0.25,
      ),
    );

    final cleanExt = fileExtension.replaceAll('.', '').toLowerCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storageFileName = '${user.uid}/$timestamp.$cleanExt';

    final effectiveMime = mimeType ?? _guessMimeType(cleanExt);

    await Supabase.instance.client.storage
        .from('audio_bucket')
        .upload(
          storageFileName,
          audioFile,
          fileOptions: FileOptions(
            contentType: effectiveMime,
            upsert: true,
          ),
        );

    final audioUrl = Supabase.instance.client.storage
        .from('audio_bucket')
        .getPublicUrl(storageFileName);

    if (isCancelled?.call() == true) return null;

    // Phase 3: Transcribe Speech with AssemblyAI
    onProgress?.call(
      const AudioProcessingProgress(
        phase: AudioProcessingPhase.transcribing,
        message: 'Transcribing speech with acoustic AI…',
        progress: 0.55,
      ),
    );

    final audioBytes = await audioFile.readAsBytes();
    final transcription = await _assemblyAIService.transcribeAudio(
      audioUrl,
      audioBytes: audioBytes,
    );

    if (isCancelled?.call() == true) return null;

    // Phase 4: Smart Title & Summary via Gemini
    onProgress?.call(
      const AudioProcessingProgress(
        phase: AudioProcessingPhase.generatingAi,
        message: 'Generating smart title and key insights…',
        progress: 0.80,
      ),
    );

    final hasSpeech = transcription != null &&
        transcription.trim().isNotEmpty &&
        transcription != '[No speech detected]';

    String title;
    String? aiSummary;

    if (hasSpeech) {
      try {
        title = await _geminiService.generateTitle(transcription);
      } catch (_) {
        title = originalName.isNotEmpty
            ? _stripExtension(originalName)
            : 'Audio Note';
      }

      try {
        aiSummary = await _geminiService.summarizeText(transcription);
      } catch (_) {
        aiSummary = null;
      }
    } else {
      title = originalName.isNotEmpty
          ? _stripExtension(originalName)
          : 'Voice Recording';
    }

    if (isCancelled?.call() == true) return null;

    // Phase 5: Save to Firestore
    onProgress?.call(
      const AudioProcessingProgress(
        phase: AudioProcessingPhase.saving,
        message: 'Saving note to your library…',
        progress: 0.95,
      ),
    );

    final noteData = {
      'userId': user.uid,
      'title': title,
      'createdAt': FieldValue.serverTimestamp(),
      'audioUrl': audioUrl,
      'transcription': transcription,
      'summary': aiSummary,
      'aiSummary': aiSummary,
      'type': 'audio',
      // Phase 7 Collections
      if (collectionId != null && collectionId.isNotEmpty)
        'collectionId': collectionId,
      if (collectionName != null && collectionName.isNotEmpty)
        'collectionName': collectionName,
    };

    final docRef = await FirebaseFirestore.instance
        .collection('notes')
        .add(noteData);

    final createdNote = Note(
      id: docRef.id,
      userId: user.uid,
      title: title,
      createdAt: DateTime.now(),
      audioUrl: audioUrl,
      transcription: transcription,
      summary: aiSummary,
      aiSummary: aiSummary,
      type: 'audio',
      collectionId: collectionId,
      collectionName: collectionName,
    );

    onProgress?.call(
      const AudioProcessingProgress(
        phase: AudioProcessingPhase.completed,
        message: 'Import and transcription complete! 🎉',
        progress: 1.0,
      ),
    );

    return createdNote;
  }

  static String _guessMimeType(String ext) {
    switch (ext) {
      case 'opus':
        return 'audio/opus';
      case 'ogg':
        return 'audio/ogg';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'flac':
        return 'audio/flac';
      default:
        return 'audio/octet-stream';
    }
  }

  static String _stripExtension(String filename) {
    final lastDot = filename.lastIndexOf('.');
    if (lastDot > 0) {
      return filename.substring(0, lastDot);
    }
    return filename;
  }
}
