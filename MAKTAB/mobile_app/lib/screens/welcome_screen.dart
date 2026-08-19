import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF004D40),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF004D40), Color(0xFF00332B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Logo / Icon area
                FadeTransition(
                  opacity: _fadeIn,
                  child: SlideTransition(
                    position: _slideUp,
                    child: Column(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: const Color(0xFFFFD700),
                              width: 3.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                                blurRadius: 24,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/ic_launcher.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.auto_stories,
                                size: 60,
                                color: Color(0xFFFFD700),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 22,
                            fontFamily: 'Amiri',
                            height: 1.8,
                          ),
                          textAlign: TextAlign.center,
                          textScaler: TextScaler.noScaling,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'MAKTAB',
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                          textScaler: TextScaler.noScaling,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Idara-e-Dawatul Qur\'an',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                          textScaler: TextScaler.noScaling,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 2,
                          width: 70,
                          color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Manage your Maktab classes,\nstudents, and progress — offline & secure.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                // Action Buttons
                FadeTransition(
                  opacity: _fadeIn,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Register / Get Started
                      ElevatedButton(
                        key: const Key('btn_get_started'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: const Color(0xFF004D40),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                        ),
                        onPressed: () => context.go('/register'),
                        child: const Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Already registered → go to Login
                      OutlinedButton(
                        key: const Key('btn_already_registered'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white30, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => context.go('/login'),
                        child: const Text(
                          'I already have an account',
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                const Text(
                  'v1.0 · Offline · Secure',
                  style: TextStyle(color: Colors.white24, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
