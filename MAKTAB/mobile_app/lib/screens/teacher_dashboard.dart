import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:maktab_app/repositories/message_repository.dart';
import 'package:maktab_app/repositories/teacher_attendance_repository.dart';
import 'package:maktab_app/repositories/salary_repository.dart';
import 'package:maktab_app/services/cloud_sync_service.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Notifications state
  int _unreadMessagesCount = 0;
  int _unreadAttendanceCount = 0;
  int _unreadSalaryCount = 0;
  int get _totalUnreadNotifications =>
      _unreadMessagesCount + _unreadAttendanceCount + _unreadSalaryCount;

  StreamSubscription<String>? _syncSub;

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

    _loadNotifications();

    _syncSub = CloudSyncService.instance.dataChangeStream.listen((col) {
      if (!mounted) return;
      if (col == 'messages' || col == 'teacher_attendance' || col == 'announcements') {
        _loadNotifications();
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _bodyCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final canonicalTeacherId =
          auth.currentUser?.teacherId ?? auth.currentUser?.id ?? 0;

      final prefs = await SharedPreferences.getInstance();
      final lastBellSeenStr =
          prefs.getString('teacher_bell_last_seen_$canonicalTeacherId');
      final lastBellSeen =
          lastBellSeenStr != null ? DateTime.tryParse(lastBellSeenStr) : null;

      final unreadMsg = await MessageRepository()
          .getUnreadCountForReceiver(canonicalTeacherId, isAdmin: false);

      final atts = await TeacherAttendanceRepository()
          .getAttendanceByTeacher(canonicalTeacherId);
      final unreadAtt = lastBellSeen == null
          ? (atts.isNotEmpty ? 1 : 0)
          : atts.where((a) {
              final d = DateTime.tryParse(a.date);
              return d != null && d.isAfter(lastBellSeen);
            }).length;

      final salaryPayments =
          await SalaryRepository().getPaymentsForTeacher(canonicalTeacherId);
      final unreadSalary = lastBellSeen == null
          ? (salaryPayments.isNotEmpty ? 1 : 0)
          : salaryPayments.where((p) {
              final d = DateTime.tryParse(p.createdAt) ??
                  DateTime.tryParse(p.paymentDate);
              return d != null && d.isAfter(lastBellSeen);
            }).length;

      if (!mounted) return;
      setState(() {
        _unreadMessagesCount = unreadMsg;
        _unreadAttendanceCount = unreadAtt;
        _unreadSalaryCount = unreadSalary;
      });
    } catch (e) {
      debugPrint('[TeacherDashboard] Error loading notifications: $e');
    }
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedScale(
                                scale: hover ? 1.05 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: cardColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                    boxShadow: hover ? [
                                      BoxShadow(color: cardColor.withValues(alpha: 0.3), blurRadius: 8)
                                    ] : [],
                                  ),
                                  child: Icon(icon, color: cardColor, size: 26),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: cardColor,
                                  letterSpacing: 0.2,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
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


  String _formatTeacherName(String? rawName) {
    if (rawName == null || rawName.trim().isEmpty) return 'Teacher';
    final trimmed = rawName.trim();
    final upper = trimmed.toUpperCase();
    if (upper.startsWith('MOULANA') ||
        upper.startsWith('SHAIK') ||
        upper.startsWith('USTAD') ||
        upper.startsWith('HAFIZ') ||
        upper.startsWith('K.')) {
      return trimmed;
    }
    return 'Ustad $trimmed';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
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
        centerTitle: false,
        titleSpacing: 0,
        title: Row(
          children: [
            const MaktabLogo(size: 28, showGlow: true, animate: false),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                  Text(
                    loc?.translate('teacher_portal') ?? 'Educator Console',
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
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
          // TODO(push): Integrate FCM for OS-level notifications.
          // Requires: (1) FCM project setup, (2) Cloud Function trigger,
          // (3) FCM token registration in AuthProvider,
          // (4) permission prompt on Android 13+ / iOS.
          // See RELEASE_NOTES.md "Known limitations" section.
          // Bell notifications icon with badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, size: 22),
                tooltip: 'Notifications',
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                padding: EdgeInsets.zero,
                onPressed: () async {
                  await context.push('/teacher/notifications');
                  if (mounted) _loadNotifications();
                },
              ),
              if (_totalUnreadNotifications > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      _totalUnreadNotifications > 99 ? '99+' : '$_totalUnreadNotifications',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 20),
            tooltip: loc?.translate('search') ?? 'Search',
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
            onPressed: () =>
                showSearch(context: context, delegate: UniversalSearchDelegate()),
          ),
          const LanguageToggle(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.white),
            tooltip: 'Dashboard Tools',
            onSelected: (value) async {
              if (value == 'sync') {
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
              } else if (value == 'settings') {
                context.push('/teacher/settings');
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'sync',
                child: Row(
                  children: [
                    const Icon(Icons.sync_rounded, color: Color(0xFF004D40), size: 18),
                    const SizedBox(width: 10),
                    Text(loc?.translate('sync') ?? 'Sync Devices'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    const Icon(Icons.settings_outlined, color: Color(0xFF004D40), size: 18),
                    const SizedBox(width: 10),
                    Text(loc?.translate('settings') ?? 'Settings'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
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
                          _formatTeacherName(auth.currentUser?.name),
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
              label: 'Home',
              route: '/teacher/home',
            ),
            _drawerTile(
              context,
              icon: CupertinoIcons.square_list_fill,
              label: 'Attendance',
              route: '/teacher/attendance',
            ),
            _drawerTile(
              context,
              icon: CupertinoIcons.person_2_fill,
              label: 'Students',
              route: '/teacher/students',
            ),
            _drawerTile(
              context,
              icon: CupertinoIcons.book_fill,
              label: 'Sabaq',
              route: '/teacher/quran_progress',
            ),
            _drawerTile(
              context,
              icon: Icons.account_balance_wallet_rounded,
              label: 'Fees',
              route: '/teacher/fees',
            ),
            _drawerTile(
              context,
              icon: Icons.payments_rounded,
              label: 'My Salary',
              route: '/teacher/salary',
            ),
            _drawerTile(
              context,
              icon: Icons.groups_rounded,
              label: 'My Batches',
              route: '/teacher/batches',
            ),
            _drawerTile(
              context,
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Messages',
              route: '/teacher/messages',
            ),
            _drawerTile(
              context,
              icon: Icons.settings_rounded,
              label: 'Settings',
              route: '/settings',
            ),
            const Divider(height: 24),
            ListTile(
              leading: const Icon(CupertinoIcons.square_arrow_right,
                  color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
                                  _formatTeacherName(auth.currentUser?.name),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
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
                      _buildDashboardCard(context, 'Attendance',
                          CupertinoIcons.square_list_fill, '/teacher/attendance'),
                      _buildDashboardCard(context, 'Students',
                          CupertinoIcons.person_2_fill, '/teacher/students',
                          color: const Color(0xFF00695C)),
                      _buildDashboardCard(context, 'Sabaq',
                          CupertinoIcons.book_fill, '/teacher/quran_progress'),
                      _buildDashboardCard(context, 'My Batches',
                          Icons.groups_rounded, '/teacher/batches',
                          color: AppColors.goldAccent),
                      _buildDashboardCard(
                          context,
                          'Messages',
                          Icons.chat_bubble_outline_rounded,
                          '/teacher/messages',
                          color: const Color(0xFF388E3C)),
                      _buildDashboardCard(
                          context,
                          'Fees',
                          Icons.account_balance_wallet_rounded,
                          '/teacher/fees',
                          color: const Color(0xFFE65100)),
                      _buildDashboardCard(
                          context,
                          'My Salary',
                          Icons.payments_rounded,
                          '/teacher/salary',
                          color: const Color(0xFF2E7D32)),
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
