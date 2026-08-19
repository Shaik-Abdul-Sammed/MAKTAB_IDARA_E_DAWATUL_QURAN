import 'package:flutter/material.dart';
import 'package:maktab_app/config/app_colors.dart';
import 'package:maktab_app/widgets/maktab_logo.dart';

class SettingsAboutScreen extends StatelessWidget {
  const SettingsAboutScreen({super.key});

  Widget _buildFeatureHighlight({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep({
    required String stepNumber,
    required String roleTitle,
    required String instructions,
    required Color badgeColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: badgeColor,
            child: Text(
              stepNumber,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roleTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: badgeColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  instructions,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'About Maktab App',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Production App Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF004D40), Color(0xFF00695C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryTeal.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const MaktabLogo(size: 72, showGlow: true),
                    const SizedBox(height: 14),
                    const Text(
                      'MAKTAB MANAGEMENT SYSTEM',
                      style: TextStyle(
                        color: AppColors.goldAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Idara-e-Dawatul Qur\'an Educational Portal',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.goldAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.goldAccent.withValues(alpha: 0.5)),
                      ),
                      child: const Text(
                        'v2.4.0 Production Build · Offline-First Engine',
                        style: TextStyle(
                          color: AppColors.goldAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Overview Section
              const Text(
                'WHAT IS MAKTAB APP?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: Color(0xFF004D40),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                ),
                child: const Text(
                  'Maktab Management System is an enterprise-grade mobile solution built specifically for Madrasas and Maktabs. It streamlines student attendance, teacher shift verification, Quran recitation tracking (Sabaq, Sabqi, Manzil), fee history, parent WhatsApp notifications, and administrative auditing with zero downtime and offline database security.',
                  style: TextStyle(fontSize: 13.5, height: 1.5, color: Colors.black87),
                ),
              ),

              const SizedBox(height: 24),

              // Key Features
              const Text(
                'KEY CAPABILITIES & INNOVATIONS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: Color(0xFF004D40),
                ),
              ),
              const SizedBox(height: 12),

              _buildFeatureHighlight(
                icon: Icons.mic_rounded,
                title: 'AI Voice Attendance Assistant',
                description: 'Mark attendance effortlessly by speaking commands like "Ahmad Present" or "Mark all present".',
                color: const Color(0xFF00695C),
              ),
              _buildFeatureHighlight(
                icon: Icons.face_retouching_natural_rounded,
                title: 'Biometric Face & PIN Security',
                description: 'Fast camera facial verification for teachers and admins to prevent unauthorized proxy entries.',
                color: const Color(0xFF1976D2),
              ),
              _buildFeatureHighlight(
                icon: Icons.security_rounded,
                title: 'AES-256 Encrypted Offline Database',
                description: 'All records are secured on-device via SQLCipher encryption. Operates seamlessly without internet.',
                color: const Color(0xFF388E3C),
              ),
              _buildFeatureHighlight(
                icon: Icons.archive_rounded,
                title: 'Past & Deleted Students Archive',
                description: 'Soft-delete architecture preserves full historical academic, fee, and attendance data with 1-click restore.',
                color: const Color(0xFFE65100),
              ),
              _buildFeatureHighlight(
                icon: Icons.chat_rounded,
                title: 'Automated WhatsApp Parent Reporting',
                description: 'Instantly generate and send attendance alerts, fee receipts, and progress reports directly to parents.',
                color: const Color(0xFF25D366),
              ),

              const SizedBox(height: 24),

              // How To Use Guide
              const Text(
                'QUICK USER GUIDE',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: Color(0xFF004D40),
                ),
              ),
              const SizedBox(height: 12),

              _buildGuideStep(
                stepNumber: '1',
                roleTitle: 'Teacher Workflow',
                instructions: 'Select assigned Batch ➔ Mark attendance via Voice, Face, or Manual List ➔ Record Sabaq/Sabqi/Manzil ➔ Submit daily self-audit.',
                badgeColor: const Color(0xFF004D40),
              ),
              _buildGuideStep(
                stepNumber: '2',
                roleTitle: 'Admin Workflow',
                instructions: 'Assign Teachers to Batches ➔ Monitor live attendance logs ➔ Manage Student Promotions & Fees ➔ Review System Audit Trail.',
                badgeColor: const Color(0xFF1565C0),
              ),
              _buildGuideStep(
                stepNumber: '3',
                roleTitle: 'Parent & Communication',
                instructions: 'Tap WhatsApp button next to student name to send attendance updates, monthly fee receipts, or Quran progress summaries.',
                badgeColor: const Color(0xFF388E3C),
              ),

              const SizedBox(height: 24),

              // Footer & Credits
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Designed & Developed for',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'MAKTAB IDARA E DAWATUL QURAN',
                      style: TextStyle(
                        color: Color(0xFF004D40),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '© 2026 Idara-e-Dawatul Qur\'an. All Rights Reserved.',
                      style: TextStyle(color: Colors.black38, fontSize: 11),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
