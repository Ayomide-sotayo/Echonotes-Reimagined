import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:echonotes/core/theme.dart';

/// Screen presenting the legal Terms of Service and Privacy Policy
/// for EchoNotes with full compliance clauses (recording consent, AI disclaimers,
/// ownership guarantees, and GDPR/CCPA privacy rights).
class LegalTermsPrivacyScreen extends StatefulWidget {
  final int initialTabIndex;

  const LegalTermsPrivacyScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<LegalTermsPrivacyScreen> createState() =>
      _LegalTermsPrivacyScreenState();
}

class _LegalTermsPrivacyScreenState extends State<LegalTermsPrivacyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkScaffold : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Legal & Compliance',
          style: GoogleFonts.outfit(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF7C3AED),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor:
                  isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
              labelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Terms of Service'),
                Tab(text: 'Privacy Policy'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTermsTab(isDark),
          _buildPrivacyTab(isDark),
        ],
      ),
    );
  }

  // --- Terms of Service Content ---
  Widget _buildTermsTab(bool isDark) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        // Header Banner
        _buildHighlightBanner(
          isDark: isDark,
          title: 'EchoNotes Terms of Service',
          subtitle:
              'Last Updated: October 2026. Please read these terms carefully before recording audio or generating AI transcripts.',
          icon: Icons.gavel_rounded,
          badgeText: 'Legal Agreement',
        ),
        const SizedBox(height: 20),

        _buildSectionCard(
          isDark: isDark,
          sectionNumber: '1',
          title: 'Acceptance of Terms',
          content:
              'By accessing, downloading, or using the EchoNotes mobile application ("Service"), you agree to be legally bound by these Terms of Service. If you do not agree to these terms, you must not use or access the Service.',
        ),
        const SizedBox(height: 14),

        _buildSectionCard(
          isDark: isDark,
          sectionNumber: '2',
          title: 'Description of Service',
          content:
              'EchoNotes is an intelligent voice recording and note-taking platform designed to capture personal voice memos, meetings, lectures, and interviews, generating automated speech-to-text transcriptions and AI-assisted summaries with cloud synchronization.',
        ),
        const SizedBox(height: 14),

        _buildSectionCard(
          isDark: isDark,
          sectionNumber: '3',
          title: 'Audio Recording & Wiretap Consent Compliance',
          isWarning: true,
          content:
              'IMPORTANT LEGAL NOTICE:\n\n'
              '1. Consent Requirements: State, federal, and international laws govern the recording of oral and electronic communications. In many jurisdictions (including two-party/all-party consent states and countries), it is illegal to record a conversation without the explicit knowledge and prior consent of all participants.\n\n'
              '2. User Responsibility: You represent and warrant that prior to initiating any recording using EchoNotes, you have obtained all necessary consents, permissions, and authorizations required under applicable wiretapping, eavesdropping, and privacy laws.\n\n'
              '3. Indemnification: EchoNotes expressly disclaims any liability for unauthorized or unlawful recordings made by users. You agree to hold harmless and indemnify EchoNotes from any claims, disputes, fines, or damages arising from your recording activities.',
        ),
        const SizedBox(height: 14),

        _buildSectionCard(
          isDark: isDark,
          sectionNumber: '4',
          title: 'AI Processing & Accuracy Disclaimer',
          content:
              '1. Generative AI Notice: EchoNotes uses advanced artificial intelligence models (such as Google Gemini and cloud speech recognizers) to transcribe audio and synthesize summaries.\n\n'
              '2. Potential Inaccuracies: While we strive for high precision, AI models may mishear words, invent details ("hallucinate"), or misinterpret context due to background noise, accents, or complex technical vocabulary.\n\n'
              '3. No Professional Advice: AI-generated notes, summaries, and action items are provided strictly for informational and productivity assistance. They must NEVER be relied upon as legal, financial, medical, or life-safety advice without independent verification.',
        ),
        const SizedBox(height: 14),

        _buildSectionCard(
          isDark: isDark,
          sectionNumber: '5',
          title: 'User Ownership of Content',
          content:
              'You retain 100% full ownership, intellectual property rights, and title to all audio recordings, text notes, and personal data you create in EchoNotes. We claim no ownership over your ideas, voice memos, or created transcripts.',
        ),
        const SizedBox(height: 14),

        _buildSectionCard(
          isDark: isDark,
          sectionNumber: '6',
          title: 'Acceptable Use & Prohibited Conduct',
          content:
              'You agree not to use EchoNotes to:\n'
              '• Violate any applicable local, state, national, or international law.\n'
              '• Record or distribute non-consensual private conversations or copyrighted audio without authorization.\n'
              '• Attempt to reverse engineer, decompile, or extract the source code of the application.\n'
              '• Interfere with or disrupt the integrity or performance of cloud servers.',
        ),
        const SizedBox(height: 14),

        _buildSectionCard(
          isDark: isDark,
          sectionNumber: '7',
          title: 'Service Availability & Data Backups',
          content:
              'The Service is provided on an "AS IS" and "AS AVAILABLE" basis. While we utilize enterprise-grade cloud synchronization (Google Firebase), unexpected outages or network issues may occur. You are strongly encouraged to maintain independent backups of critical voice recordings.',
        ),
        const SizedBox(height: 14),

        _buildSectionCard(
          isDark: isDark,
          sectionNumber: '8',
          title: 'Limitation of Liability',
          content:
              'To the maximum extent permitted by applicable law, EchoNotes, its founders, and affiliates shall not be liable for any indirect, incidental, punitive, or consequential damages resulting from lost voice memos, inaccurate AI transcriptions, or service downtime.',
        ),
        const SizedBox(height: 14),

        _buildSectionCard(
          isDark: isDark,
          sectionNumber: '9',
          title: 'Account Termination & Contact',
          content:
              'You may terminate your account and delete your data at any time via Profile Settings. For any legal inquiries or questions regarding these terms, please contact us at support@echonotes.app.',
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // --- Privacy Policy Content ---
  Widget _buildPrivacyTab(bool isDark) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        // Header Banner
        _buildHighlightBanner(
          isDark: isDark,
          title: 'EchoNotes Privacy Policy',
          subtitle:
              'Your privacy is our priority. We never sell your personal data or use your private voice recordings to train public AI models.',
          icon: Icons.shield_rounded,
          badgeText: 'Data Protection',
        ),
        const SizedBox(height: 20),

        _buildSectionCard(
          isDark: isDark,
          sectionNumber: '1',
          title: 'Information We Collect',
          content:
              'We collect the following categories of information to provide the EchoNotes experience:\n\n'
              '• Account Information: Email address, username, and profile photo provided during account creation or Google Sign-In.\n'
              '• Voice Recordings & Transcripts: Audio files you explicitly record in the app and the resulting speech-to-text transcripts and summaries.\n'
              '• App Telemetry: Anonymous performance metrics, device type, and crash diagnostics to improve stability.',
        ),
        const SizedBox(height: 14),

        _buildSectionCard(
          isDark: isDark,
          sectionNumber: '2',
          title: 'How We Use Your Data',
          content:
              'We use your data solely for core application functionality:\n'
              '• To authenticate your account securely.\n'
              '• To transcribe, summarize, and categorize your voice notes.\n'
              '• To synchronize notes across your authorized devices.\n\n'
              'WE DO NOT SELL YOUR PERSONAL DATA, VOICE MEMOS, OR TRANSCRIPTS TO ADVERTISERS OR DATA BROKERS.',
        ),
        const SizedBox(height: 14),

        _buildSectionCard(
          isDark: isDark,
          sectionNumber: '3',
          title: 'AI Processing & Model Training Policy',
          content:
              '1. Secure AI Processing: Audio snippets and transcripts submitted for transcription and summarization are securely transmitted to official Google Cloud and Gemini API endpoints via encrypted connections.\n\n'
              '2. No Foundation Training: Your private voice notes and personal transcripts are NOT used to train, fine-tune, or improve public AI models.',
        ),
        const SizedBox(height: 14),

        _buildSectionCard(
          isDark: isDark,
          sectionNumber: '4',
          title: 'Data Security & Encryption',
          content:
              '• In Transit: All communications between EchoNotes and our cloud infrastructure are secured using TLS 1.3 cryptographic encryption.\n'
              '• At Rest: User data stored on Google Firebase and Cloud Firestore is encrypted at rest using industry-standard AES-256 encryption.',
        ),
        const SizedBox(height: 14),

        _buildSectionCard(
          isDark: isDark,
          sectionNumber: '5',
          title: 'Your Privacy Rights (GDPR & CCPA)',
          content:
              'Regardless of your geographic location, EchoNotes guarantees the following data rights:\n\n'
              '• Right to Access: You can review all your saved notes and transcripts at any time.\n'
              '• Right to Delete: Deleting a note in EchoNotes removes it permanently from your cloud database.\n'
              '• Right to Erasure: You may delete your complete account and all associated profile and audio records at any time from Profile Settings.\n'
              '• Right to Export: You can export transcripts as text or markdown files.',
        ),
        const SizedBox(height: 14),

        _buildSectionCard(
          isDark: isDark,
          sectionNumber: '6',
          title: 'Children’s Privacy',
          content:
              'EchoNotes is not intended for use by children under the age of 13 (or 16 in the European Economic Area). We do not knowingly collect personal information from minors.',
        ),
        const SizedBox(height: 14),

        _buildSectionCard(
          isDark: isDark,
          sectionNumber: '7',
          title: 'Privacy Contact & Data Inquiries',
          content:
              'If you have any questions, concerns, or requests regarding this Privacy Policy or your data, please contact our Data Protection Team at privacy@echonotes.app.',
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // --- UI Components ---
  Widget _buildHighlightBanner({
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required String badgeText,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7C3AED),
            const Color(0xFF6D28D9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required bool isDark,
    required String sectionNumber,
    required String title,
    required String content,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isWarning
              ? const Color(0xFFF59E0B).withOpacity(0.4)
              : (isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
          width: isWarning ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isWarning
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFEDE9FE),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  sectionNumber,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isWarning
                        ? const Color(0xFFD97706)
                        : const Color(0xFF7C3AED),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              height: 1.55,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
