import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:maktab_app/services/cloud_sync_service.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/cupertino.dart';
import 'package:maktab_app/config/app_colors.dart';
import 'package:maktab_app/widgets/language_toggle.dart';
import 'package:maktab_app/widgets/maktab_logo.dart';
import 'package:maktab_app/l10n/app_localizations.dart';
import 'package:maktab_app/widgets/universal_search_delegate.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard>
    with TickerProviderStateMixin {
  // Main body fade+slide
  late AnimationController _bodyCtrl;
  late Animation<double> _bodyFade;
  late Animation<Offset> _bodySlide;

  // Staggered app-name letter animations
  late AnimationController _nameCtrl;
  final List<String> _appNameChars = 'MAKTAB'.split('');
  late List<Animation<double>> _charFades;
  late List<Animation<Offset>> _charSlides;

  @override
  void initState() {
    super.initState();

    _bodyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
    _bodyFade =
        CurvedAnimation(parent: _bodyCtrl, curve: Curves.easeOut);
    _bodySlide =
        Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _bodyCtrl, curve: Curves.easeOutCubic));

    _nameCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    final int n = _appNameChars.length;
    _charFades = List.generate(n, (i) {
      final start = i / n * 0.55;
      final end = (start + 0.45).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _nameCtrl,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });
    _charSlides = List.generate(n, (i) {
      final start = i / n * 0.55;
      final end = (start + 0.45).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.7),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _nameCtrl,
          curve: Interval(start, end, curve: Curves.easeOutBack),
        ),
      );
    });
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }


  Widget _buildDashboardCard(
    BuildContext context,
    String title,
    IconData icon,
    String route, {
    Color? color,
  }) {
    final cardColor = color ?? AppColors.primaryTeal;
    final isHovering = ValueNotifier(false);
    return MouseRegion(
      onEnter: (_) => isHovering.value = true,
      onExit: (_) => isHovering.value = false,
      child: ValueListenableBuilder(
        valueListenable: isHovering,
        builder: (context, hover, child) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (route.isNotEmpty) {
                  context.push(route);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$title module coming soon')),
                  );
                }
              },
              borderRadius: BorderRadius.circular(20),
              splashColor: cardColor.withValues(alpha: 0.2),
              highlightColor: cardColor.withValues(alpha: 0.05),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: hover ? 0.9 : 0.7),
                          Colors.white.withValues(alpha: hover ? 0.7 : 0.5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: hover ? cardColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cardColor.withValues(alpha: hover ? 0.2 : 0.05),
                          blurRadius: hover ? 15 : 10,
                          offset: Offset(0, hover ? 8 : 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Glass reflection highlight
                        Positioned(
                          top: -20,
                          left: -20,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedScale(
                                scale: hover ? 1.1 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: cardColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                    boxShadow: hover ? [
                                      BoxShadow(color: cardColor.withValues(alpha: 0.3), blurRadius: 8)
                                    ] : [],
                                  ),
                                  child: Icon(icon, color: cardColor, size: 28),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: cardColor,
                                  letterSpacing: 0.2,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final loc = AppLocalizations.of(context);
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning ☀️'
        : now.hour < 17
            ? 'Good Afternoon 🌤️'
            : 'Good Evening 🌙';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Row(
          children: [
            const MaktabLogo(size: 30, showGlow: true, animate: false),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc?.translate('teacher_dashboard') ?? 'Teacher Portal',
                    style: const TextStyle(
                      color: AppColors.goldAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const Text(
                    'Educator Console',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF004D40), Color(0xFF00695C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded, size: 22),
            tooltip: 'Sync Devices Now',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 12),
                      Text('Syncing data with cloud…'),
                    ],
                  ),
                  duration: Duration(seconds: 2),
                ),
              );
              final maktabId = await CloudSyncService.instance.getMaktabId();
              await CloudSyncService.instance.pullAllDataForMaktab(maktabId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Multi-device sync completed!'),
                    backgroundColor: Color(0xFF004D40),
                    duration: Duration(seconds: 2),
                  ),
                );
                setState(() {});
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 22),
            onPressed: () =>
                showSearch(context: context, delegate: UniversalSearchDelegate()),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            onPressed: () => context.push('/teacher/settings'),
          ),
          const LanguageToggle(),
        ],
      ),

      // ── Drawer ────────────────────────────────────────────────────────────
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Drawer header with animated logo
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF004D40), Color(0xFF00695C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo + app name row
                  Row(
                    children: [
                      MaktabLogo(size: 52, showGlow: true, animate: true),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'MAKTAB',
                            style: TextStyle(
                              color: AppColors.goldAccent,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                            ),
                          ),
                          Text(
                            'Educator Portal',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Teacher name
                  Row(
                    children: [
                      const Icon(CupertinoIcons.person_fill,
                          color: Colors.white70, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Ustad ${auth.currentUser?.name ?? 'Teacher'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            _drawerTile(
              context,
              icon: CupertinoIcons.house_fill,
              label: 'Home Hub',
              route: '/teacher/home',
            ),
            _drawerTile(
              context,
              icon: CupertinoIcons.square_list_fill,
              label: loc?.translate('attendance') ?? 'Attendance Register',
              route: '/teacher/attendance',
            ),
            _drawerTile(
              context,
              icon: CupertinoIcons.book_fill,
              label: loc?.translate('quran_progress') ?? 'Quran Recitation Log',
              route: '/teacher/quran_progress',
            ),
            _drawerTile(
              context,
              icon: Icons.groups_rounded,
              label: 'My Batches',
              route: '/teacher/batches',
            ),
            _drawerTile(
              context,
              icon: Icons.notifications_active_rounded,
              label: 'Notification Center',
              route: '/teacher/notifications',
              color: const Color(0xFF6A1B9A),
            ),
            _drawerTile(
              context,
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Parent Enquiries & Messages',
              route: '/teacher/messages',
              color: const Color(0xFF388E3C),
            ),
            _drawerTile(
              context,
              icon: CupertinoIcons.graph_square_fill,
              label: loc?.translate('reports') ?? 'Reports & Analytics',
              route: '/teacher/reports',
              color: const Color(0xFF1565C0),
            ),
            _drawerTile(
              context,
              icon: CupertinoIcons.checkmark_square_fill,
              label: loc?.translate('checklist') ?? 'Daily Checklist',
              route: '/teacher/checklist',
            ),
            _drawerTile(
              context,
              icon: Icons.campaign_rounded,
              label: 'Announcements',
              route: '/teacher/announcements',
              color: const Color(0xFFE65100),
            ),
            _drawerTile(
              context,
              icon: Icons.menu_book_rounded,
              label: 'Syllabus Tracker',
              route: '/teacher/syllabus-tracker',
              color: const Color(0xFF0277BD),
            ),
            _drawerTile(
              context,
              icon: Icons.monitor_heart_rounded,
              label: 'Student Health & Emergency',
              route: '/teacher/health',
              color: const Color(0xFFD81B60),
            ),
            _drawerTile(
              context,
              icon: Icons.gavel_rounded,
              label: 'Behavior & Incidents',
              route: '/teacher/behavior',
              color: const Color(0xFF5D4037),
            ),
            _drawerTile(
              context,
              icon: Icons.fact_check_rounded,
              label: 'Self-Audit Submission',
              route: '/teacher/checklist-entry',
              color: const Color(0xFF00695C),
            ),
            _drawerTile(
              context,
              icon: Icons.history_edu_rounded,
              label: 'Self-Audit History',
              route: '/teacher/checklist-history',
              color: const Color(0xFF455A64),
            ),
            _drawerTile(
              context,
              icon: Icons.help_outline_rounded,
              label: 'Support & FAQ',
              route: '/teacher/support',
              color: Colors.blueGrey,
            ),
            const Divider(height: 24),
            ListTile(
              leading: const Icon(CupertinoIcons.square_arrow_right,
                  color: Colors.red),
              title: Text(
                loc?.translate('logout') ?? 'Logout',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              onTap: () async {
                await auth.logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),

      // ── Body ────────────────────────────────────────────────────────────────
      body: FadeTransition(
        opacity: _bodyFade,
        child: SlideTransition(
          position: _bodySlide,
          child: SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Hero welcome banner ───────────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF004D40), Color(0xFF00695C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryTeal.withValues(alpha: 0.30),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Animated logo with pulse ring
                        MaktabLogo(size: 70, showGlow: true, animate: true),
                        const SizedBox(width: 16),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Staggered "MAKTAB" letter animation
                              AnimatedBuilder(
                                animation: _nameCtrl,
                                builder: (_, _) {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(
                                      _appNameChars.length,
                                      (i) => FadeTransition(
                                        opacity: _charFades[i],
                                        child: SlideTransition(
                                          position: _charSlides[i],
                                          child: Text(
                                            _appNameChars[i],
                                            style: const TextStyle(
                                              color: AppColors.goldAccent,
                                              fontSize: 24,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 3.5,
                                              height: 1.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 3),
                              FadeTransition(
                                opacity: _bodyFade,
                                child: Text(
                                  greeting,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              ),
                              const SizedBox(height: 2),
                              FadeTransition(
                                opacity: _bodyFade,
                                child: Text(
                                  'Ustad ${auth.currentUser?.name ?? 'Teacher'}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 6),
                              FadeTransition(
                                opacity: _bodyFade,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.goldAccent
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: AppColors.goldAccent
                                            .withValues(alpha: 0.4)),
                                  ),
                                  child: const Text(
                                    '🕌 Idara-e-Dawatul Qur\'an',
                                    style: TextStyle(
                                        color: AppColors.goldAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Quick hub button row ─────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: FilledButton.icon(
                      onPressed: () => context.push('/teacher/home'),
                      icon: const Icon(Icons.dashboard_rounded, size: 18),
                      label: const Text(
                        'Open Teacher Home Hub',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.goldAccent,
                        foregroundColor: const Color(0xFF004D40),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),

                // ── Section label ────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 18,
                          decoration: BoxDecoration(
                            color: AppColors.goldAccent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Quick Access',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Dashboard grid ───────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                    ),
                    delegate: SliverChildListDelegate([
                      _buildDashboardCard(context, 'Mark Attendance',
                          CupertinoIcons.square_list_fill, '/teacher/attendance'),
                      _buildDashboardCard(context, 'Quran Recitation',
                          CupertinoIcons.book_fill, '/teacher/quran_progress'),
                      _buildDashboardCard(
                          context,
                          'Messages Inbox',
                          Icons.chat_bubble_outline_rounded,
                          '/teacher/messages',
                          color: const Color(0xFF388E3C)),
                      _buildDashboardCard(
                          context,
                          'Notifications',
                          Icons.notifications_active_rounded,
                          '/teacher/notifications',
                          color: const Color(0xFF6A1B9A)),
                      _buildDashboardCard(context, 'Daily Checklist',
                          CupertinoIcons.checkmark_square_fill, '/teacher/checklist'),
                      _buildDashboardCard(
                          context,
                          'Reports & Analytics',
                          CupertinoIcons.graph_square_fill,
                          '/teacher/reports',
                          color: const Color(0xFF1565C0)),
                      _buildDashboardCard(
                          context,
                          'Syllabus Tracker',
                          Icons.menu_book_rounded,
                          '/teacher/syllabus-tracker',
                          color: const Color(0xFF0277BD)),
                      _buildDashboardCard(
                          context,
                          'Health & Emergency',
                          Icons.monitor_heart_rounded,
                          '/teacher/health',
                          color: const Color(0xFFD81B60)),
                      _buildDashboardCard(
                          context,
                          'Behavior Log',
                          Icons.gavel_rounded,
                          '/teacher/behavior',
                          color: const Color(0xFF5D4037)),
                      _buildDashboardCard(
                          context,
                          'Self-Audit Entry',
                          Icons.fact_check_rounded,
                          '/teacher/checklist-entry',
                          color: const Color(0xFF00695C)),
                      _buildDashboardCard(
                          context,
                          'Audit History',
                          Icons.history_edu_rounded,
                          '/teacher/checklist-history',
                          color: const Color(0xFF455A64)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _drawerTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    Color? color,
  }) {
    final tileColor = color ?? AppColors.primaryTeal;
    return ListTile(
      leading: Icon(icon, color: tileColor, size: 22),
      title: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      onTap: () {
        Navigator.of(context).pop(); // close drawer
        context.push(route);
      },
      horizontalTitleGap: 10,
      minLeadingWidth: 24,
    );
  }
}
