import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:maktab_app/repositories/student_repository.dart';
import 'package:maktab_app/repositories/user_repository.dart';
import 'package:maktab_app/repositories/batch_repository.dart';
import 'dart:async';
import 'package:maktab_app/models/announcement.dart';
import 'package:maktab_app/repositories/teacher_attendance_repository.dart';
import 'package:maktab_app/repositories/announcement_repository.dart';
import 'package:maktab_app/repositories/attendance_repository.dart';
import 'package:maktab_app/repositories/message_repository.dart';
import 'package:maktab_app/services/cloud_sync_service.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/cupertino.dart';
import 'package:maktab_app/config/app_colors.dart';
import 'package:maktab_app/config/app_icons.dart';
import 'package:maktab_app/config/app_routes.dart';
import 'package:maktab_app/widgets/maktab_logo.dart';
import 'package:maktab_app/widgets/animated_counter.dart';
import 'package:maktab_app/widgets/language_toggle.dart';
import 'package:maktab_app/l10n/app_localizations.dart';
import 'package:maktab_app/widgets/universal_search_delegate.dart';
import 'package:maktab_app/services/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';


class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Staggered app-name letter animations
  late AnimationController _nameController;

  int _totalStudents = 0;
  int _totalTeachers = 0;
  int _totalBatches = 0;
  int _unreadMessagesCount = 0;
  int _unreadTeacherAttendanceCount = 0;
  List<Announcement> _recentAnnouncements = [];
  bool _notificationsLoaded = false;
  Timer? _notificationsTimer;
  StreamSubscription<String>? _syncSub;
  List<Map<String, dynamic>> _recentAttendance = [];
  List<AnomalyAlert> _aiAlerts = [];
  bool _aiInsightsExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadAiInsightsExpandedState();
    _fetchDashboardStats();
    _loadNotifications();

    _notificationsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadNotifications();
    });

    _syncSub = CloudSyncService.instance.dataChangeStream.listen((col) {
      if (!mounted) return;
      if (col == 'messages' || col == 'teacher_attendance' || col == 'announcements') {
        _loadNotifications();
      } else if (col == 'students' || col == 'teachers' || col == 'batches' || col == 'attendance') {
        _fetchDashboardStats();
      }
    });

    // Main body fade+slide
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    // Staggered letter animation for app name
    _nameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  Future<void> _loadNotifications() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = auth.currentUser?.teacherId ?? auth.currentUser?.id ?? 1;
      final msgCount = await MessageRepository().getUnreadCountForReceiver(currentUserId, isAdmin: true);
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final attCount = await TeacherAttendanceRepository().getUnreadCountForDate(today);
      final announcements = await AnnouncementRepository().getRecent(limit: 5);

      if (!mounted) return;
      if (!_notificationsLoaded ||
          _unreadMessagesCount != msgCount ||
          _unreadTeacherAttendanceCount != attCount ||
          _recentAnnouncements.length != announcements.length) {
        setState(() {
          _unreadMessagesCount = msgCount;
          _unreadTeacherAttendanceCount = attCount;
          _recentAnnouncements = announcements;
          _notificationsLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('[AdminDashboard] Error in _loadNotifications: $e');
    }
  }

  Future<void> _fetchDashboardStats() async {
    final students = await StudentRepository().getAllStudents();
    final teachers = await UserRepository().getAllTeachers();
    final batches = await BatchRepository().getAllBatches();
    final recentAtt = await AttendanceRepository().getRecentStudentAttendance(limit: 5);
    final alerts = await AnalyticsService.instance.getDashboardAnomalyAlerts();

    if (mounted) {
      setState(() {
        _totalStudents = students.length;
        _totalTeachers = teachers.length;
        _totalBatches = batches.length;
        _recentAttendance = recentAtt;
        _aiAlerts = alerts;
      });
    }
  }

  Future<void> _loadAiInsightsExpandedState() async {
    final prefs = await SharedPreferences.getInstance();
    final expanded = prefs.getBool('ai_insights_expanded') ?? false;
    if (mounted && expanded != _aiInsightsExpanded) {
      setState(() {
        _aiInsightsExpanded = expanded;
      });
    }
  }

  Future<void> _toggleAiInsights() async {
    final newState = !_aiInsightsExpanded;
    setState(() {
      _aiInsightsExpanded = newState;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai_insights_expanded', newState);
  }


  @override
  void dispose() {
    _notificationsTimer?.cancel();
    _syncSub?.cancel();
    _animController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _formatManagerName(String? rawName) {
    if (rawName == null || rawName.trim().isEmpty) return 'Shaik. Abdul Rawoof';
    final trimmed = rawName.trim();
    final upper = trimmed.toUpperCase();
    if (upper.startsWith('MANAGER') || upper.startsWith('ADMIN') || upper.startsWith('K.') || upper.startsWith('SHAIK')) {
      return trimmed;
    }
    return 'Manager $trimmed';
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String route,
    Color? iconColor,
    Color? bgColor,
    String? badge,
  }) {
    final teal = AppColors.primaryTeal;
    final gold = AppColors.goldAccent;
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
              onTap: () async {
                if (route.isNotEmpty) {
                  await context.push(route);
                  _fetchDashboardStats();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$title — coming soon')),
                  );
                }
              },
              borderRadius: BorderRadius.circular(20),
              splashColor: gold.withValues(alpha: 0.2),
              highlightColor: teal.withValues(alpha: 0.05),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          (bgColor ?? Colors.white).withValues(alpha: hover ? 0.9 : 0.7),
                          (bgColor ?? Colors.white).withValues(alpha: hover ? 0.7 : 0.5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: hover ? (iconColor ?? teal).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (iconColor ?? teal).withValues(alpha: hover ? 0.2 : 0.05),
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
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Center(
                            child: SingleChildScrollView(
                              physics: const NeverScrollableScrollPhysics(),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedScale(
                                    scale: hover ? 1.05 : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: (iconColor ?? teal).withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                        boxShadow: hover ? [
                                          BoxShadow(color: (iconColor ?? teal).withValues(alpha: 0.3), blurRadius: 8)
                                        ] : [],
                                      ),
                                      child: Icon(icon, color: iconColor ?? teal, size: 24),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                      letterSpacing: 0.2,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (badge != null)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        badge,
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                            ),
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


  Widget _buildStatCard(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.20), width: 1.2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              Icon(Icons.trending_up_rounded, size: 14, color: color.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedCounter(
            count: value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        ],
      ),
    );
  }


  Widget _buildAiInsightsSection() {
    if (_aiAlerts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: _toggleAiInsights,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF004D40).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFF004D40)),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'AI Smart Insights & Alerts',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          '${_aiAlerts.length} Action Needed',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _aiInsightsExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: const Color(0xFF004D40),
                    ),
                  ],
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity, height: 0),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _aiAlerts.length > 3 ? 3 : _aiAlerts.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final alert = _aiAlerts[index];
                      final isCritical = alert.severity == AlertSeverity.critical;
                      final isWarning = alert.severity == AlertSeverity.warning;

                      final bgColor = isCritical
                          ? Colors.red.shade50
                          : isWarning
                              ? Colors.amber.shade50
                              : Colors.blue.shade50;
                      final borderColor = isCritical
                          ? Colors.red.shade200
                          : isWarning
                              ? Colors.amber.shade300
                              : Colors.blue.shade200;
                      final textColor = isCritical
                          ? Colors.red.shade900
                          : isWarning
                              ? Colors.amber.shade900
                              : Colors.blue.shade900;
                      final icon = isCritical
                          ? Icons.error_outline_rounded
                          : isWarning
                              ? Icons.warning_amber_rounded
                              : Icons.info_outline_rounded;

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, size: 18, color: textColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alert.title,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    alert.subtitle,
                                    style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.85)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                crossFadeState: _aiInsightsExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryTeal),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryTeal,
              letterSpacing: 0.3,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: AppColors.primaryTeal.withValues(alpha: 0.12))),
      ],
    );
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
            const MaktabLogo(size: 28, showGlow: true),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    loc?.translate('admin_dashboard') ?? 'Admin Portal',
                    style: const TextStyle(
                      color: AppColors.goldAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    loc?.translate('management_console') ?? 'Management Console',
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
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(AppIcons.search, size: 20),
            tooltip: loc?.translate('search') ?? 'Search',
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
            onPressed: () => showSearch(context: context, delegate: UniversalSearchDelegate()),
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
                await CloudSyncService.instance.syncAll();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Multi-device sync completed!'),
                      backgroundColor: Color(0xFF004D40),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } else if (value == 'settings') {
                context.push(AppRoutes.adminSettings);
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
                    const Icon(AppIcons.settings, color: Color(0xFF004D40), size: 18),
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
      drawer: _buildDrawer(context, auth, loc),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildNotificationsBannerSliver(),
              if (auth.provisionFailures.isNotEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFEEBA)),
                    ),
                    child: InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Teacher Provisioning Failures'),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: auth.provisionFailures
                                    .map((f) => Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Text('• $f', style: const TextStyle(fontSize: 13)),
                                        ))
                                    .toList(),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFF856404), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '⚠️ ${auth.provisionFailures.length} teacher account(s) could not be provisioned. They may not be able to log in. Tap for details.',
                              style: const TextStyle(color: Color(0xFF856404), fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (auth.provisionPwMismatches.isNotEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8D7DA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF5C6CB)),
                    ),
                    child: InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Teacher Password Mismatches'),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...auth.provisionPwMismatches
                                      .map((f) => Padding(
                                            padding: const EdgeInsets.only(bottom: 6),
                                            child: Text('• $f', style: const TextStyle(fontSize: 13)),
                                          )),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'To fix: Open Firebase Console → Authentication → Users → find <email> → Delete account → Log in again as Manager to recreate.',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF721C24)),
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.key_off_rounded, color: Color(0xFF721C24), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '🔑 ${auth.provisionPwMismatches.length} teacher account(s) have a password mismatch. Manual reset required. Tap for details.',
                              style: const TextStyle(color: Color(0xFF721C24), fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // ── Welcome banner ──────────────────────────────────────────
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
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryTeal.withValues(alpha: 0.30),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── Animated logo ──────────────────────────────────
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: MaktabLogo(
                          size: 72,
                          showGlow: true,
                          animate: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // ── Text block ─────────────────────────────────────
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FadeTransition(
                              opacity: _fadeAnim,
                              child: const Text(
                                'MAKTAB IDARA E DAWATUL QURAN',
                                style: TextStyle(
                                  color: AppColors.goldAccent,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  height: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            FadeTransition(
                              opacity: _fadeAnim,
                              child: Text(
                                greeting,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ),
                            const SizedBox(height: 2),
                            FadeTransition(
                              opacity: _fadeAnim,
                              child: Text(
                                _formatManagerName(auth.currentUser?.name),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 6),

                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Stats row ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (!constraints.hasBoundedWidth || constraints.maxWidth <= 0) {
                        return const SizedBox.shrink();
                      }
                      final isTablet = constraints.maxWidth >= 800;
                      final cardCount = isTablet ? 4 : 3;
                      final totalSpacing = 8.0 * (cardCount - 1);
                      final cardWidth = ((constraints.maxWidth - totalSpacing) / cardCount).clamp(110.0, 200.0);
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            SizedBox(width: cardWidth, child: _buildStatCard('Students', _totalStudents, AppIcons.students, AppColors.primaryTeal)),
                            const SizedBox(width: 8),
                            SizedBox(width: cardWidth, child: _buildStatCard('Teachers', _totalTeachers, AppIcons.teachers, const Color(0xFF1976D2))),
                            const SizedBox(width: 8),
                            SizedBox(width: cardWidth, child: _buildStatCard('Batches', _totalBatches, AppIcons.batches, const Color(0xFF388E3C))),
                            if (isTablet) ...[
                              const SizedBox(width: 8),
                              SizedBox(width: cardWidth, child: _buildStatCard('Attendance', 0, Icons.how_to_reg_rounded, const Color(0xFF7B1FA2))),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),


              // ── AI Insights & Anomaly Alerts ─────────────────────────────
              SliverToBoxAdapter(
                child: _buildAiInsightsSection(),
              ),

              // ── Core Management ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: _sectionHeader('Core Management', Icons.manage_accounts_rounded),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;
                    if (width <= 0) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }
                    final isTablet = width >= 800;
                    return SliverGrid(
                      delegate: SliverChildListDelegate([
                        _buildFeatureCard(context,
                          title: 'Students',
                          icon: AppIcons.students,
                          route: AppRoutes.adminStudents,
                          iconColor: AppColors.primaryTeal,
                          bgColor: Colors.white,
                        ),
                        _buildFeatureCard(context,
                          title: 'Past Students',
                          icon: Icons.archive_rounded,
                          route: AppRoutes.adminPastStudents,
                          iconColor: const Color(0xFFE65100),
                          bgColor: Colors.white,
                        ),
                        _buildFeatureCard(context,
                          title: 'Teachers',
                          icon: AppIcons.teachers,
                          route: AppRoutes.adminTeachers,
                          iconColor: const Color(0xFF1976D2),
                          bgColor: Colors.white,
                        ),
                        _buildFeatureCard(context,
                          title: 'Batches',
                          icon: AppIcons.batches,
                          route: AppRoutes.adminBatches,
                          iconColor: const Color(0xFF388E3C),
                          bgColor: Colors.white,
                        ),
                        _buildFeatureCard(context,
                          title: 'Batch Attendance',
                          icon: Icons.fact_check_rounded,
                          route: AppRoutes.adminReportsAttendanceLog,
                          iconColor: const Color(0xFF004D40),
                          bgColor: Colors.white,
                        ),
                        _buildFeatureCard(context,
                          title: 'Teacher Attendance',
                          icon: Icons.how_to_reg_rounded,
                          route: '/admin/teacher-attendance',
                          iconColor: const Color(0xFF7B1FA2),
                          bgColor: Colors.white,
                        ),
                        _buildFeatureCard(context,
                          title: 'Teacher Salary',
                          icon: Icons.payments_rounded,
                          route: '/admin/teacher-salary',
                          iconColor: const Color(0xFF2E7D32),
                          bgColor: Colors.white,
                        ),
                        _buildFeatureCard(context,
                          title: 'Payments',
                          icon: Icons.account_balance_wallet_rounded,
                          route: '/admin/payments',
                          iconColor: const Color(0xFF00796B),
                          bgColor: Colors.white,
                        ),
                       ]),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isTablet ? 6 : 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: isTablet ? 1.0 : 0.82,
                      ),
                    );
                  },
                ),
              ),

              // ── Analytics & System ───────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: _sectionHeader('Analytics & System', Icons.bar_chart_rounded),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;
                    if (width <= 0) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }
                    final isTablet = width >= 800;
                    return SliverGrid(
                      delegate: SliverChildListDelegate([
                        _buildFeatureCard(context,
                          title: 'Reports & AI',
                          icon: AppIcons.reports,
                          route: AppRoutes.adminReports,
                          iconColor: const Color(0xFF5E35B1),
                          bgColor: Colors.white,
                        ),
                        _buildFeatureCard(context,
                          title: 'Attendance Reports',
                          icon: Icons.picture_as_pdf_rounded,
                          route: '/admin/reports/attendance',
                          iconColor: const Color(0xFF004D40),
                          bgColor: Colors.white,
                        ),
                        _buildFeatureCard(context,
                          title: 'Checklist',
                          icon: AppIcons.checklist,
                          route: AppRoutes.adminChecklist,
                          iconColor: const Color(0xFF00897B),
                          bgColor: Colors.white,
                        ),
                        _buildFeatureCard(context,
                          title: 'Audit Logs',
                          icon: Icons.receipt_long_rounded,
                          route: AppRoutes.adminAuditLogs,
                          iconColor: const Color(0xFF8D6E63),
                          bgColor: Colors.white,
                        ),
                        _buildFeatureCard(context,
                          title: 'Teacher Activity',
                          icon: Icons.history_rounded,
                          route: AppRoutes.adminTeacherActivity,
                          iconColor: const Color(0xFFE53935),
                          bgColor: Colors.white,
                        ),
                        _buildFeatureCard(context,
                          title: 'Support',
                          icon: AppIcons.support,
                          route: AppRoutes.adminSupport,
                          iconColor: const Color(0xFF546E7A),
                          bgColor: Colors.white,
                        ),
                        _buildFeatureCard(context,
                          title: 'Settings',
                          icon: AppIcons.settings,
                          route: AppRoutes.adminSettings,
                          iconColor: const Color(0xFF455A64),
                          bgColor: Colors.white,
                        ),
                      ]),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isTablet ? 6 : 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: isTablet ? 1.0 : 0.82,
                      ),
                    );
                  },
                ),
              ),

              // ── Data & Tools ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: _sectionHeader('Data & Tools', Icons.build_circle_rounded),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;
                    if (width <= 0) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }
                    final isTablet = width >= 800;
                    return SliverGrid(
                      delegate: SliverChildListDelegate([
                        _buildFeatureCard(context,
                          title: 'Import Data',
                          icon: Icons.table_view_rounded,
                          route: '/admin/import-excel',
                          iconColor: const Color(0xFF2E7D32),
                          bgColor: Colors.white,
                        ),
                        _buildFeatureCard(context,
                          title: 'Contacts',
                          icon: AppIcons.contacts,
                          route: AppRoutes.adminToolsContacts,
                          iconColor: const Color(0xFF1565C0),
                          bgColor: Colors.white,
                        ),
                        _buildFeatureCard(context,
                          title: 'Calendar Sync',
                          icon: AppIcons.calendar,
                          route: AppRoutes.adminToolsCalendar,
                          iconColor: const Color(0xFFE65100),
                          bgColor: Colors.white,
                        ),
                        _buildFeatureCard(context,
                          title: 'Messages',
                          icon: Icons.chat_rounded,
                          route: AppRoutes.adminMessages,
                          iconColor: const Color(0xFF00796B),
                          bgColor: Colors.white,
                          badge: _unreadMessagesCount > 0 ? '$_unreadMessagesCount' : null,
                        ),
                        _buildFeatureCard(context,
                          title: 'WhatsApp',
                          icon: AppIcons.whatsapp,
                          route: AppRoutes.adminToolsWhatsApp,
                          iconColor: AppIcons.whatsappGreen,
                          bgColor: Colors.white,
                        ),
                      ]),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isTablet ? 5 : 4,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: isTablet ? 1.0 : 0.82,
                      ),
                    );
                  },
                ),
              ),

              // ── Recent Activity (Manager/Teacher connection) ─────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: _sectionHeader('Recent Attendance Submissions', Icons.history_rounded),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: _recentAttendance.isEmpty 
                      ? const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(child: Text("No recent attendance records", style: TextStyle(color: Colors.grey))),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recentAttendance.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final att = _recentAttendance[index];
                            final isPresent = att['status'] == 'Present';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isPresent ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                                child: Icon(
                                  isPresent ? Icons.check_circle : Icons.cancel,
                                  color: isPresent ? Colors.green : Colors.red,
                                  size: 20,
                                ),
                              ),
                              title: Text(att['student_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text('${att['batch_name']} • ${att['date']}', style: const TextStyle(fontSize: 12)),
                              trailing: Text(att['status'], style: TextStyle(
                                color: isPresent ? Colors.green : Colors.red, 
                                fontWeight: FontWeight.bold, fontSize: 12
                              )),
                            );
                          },
                        ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsBannerSliver() {
    final totalUnread = _unreadMessagesCount + _unreadTeacherAttendanceCount;
    if (totalUnread == 0 && _recentAnnouncements.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final parts = <String>[];
    if (_unreadMessagesCount > 0) {
      parts.add('$_unreadMessagesCount new message${_unreadMessagesCount > 1 ? 's' : ''}');
    }
    if (_unreadTeacherAttendanceCount > 0) {
      parts.add('$_unreadTeacherAttendanceCount teacher attendance update${_unreadTeacherAttendanceCount > 1 ? 's' : ''}');
    }
    if (parts.isEmpty && _recentAnnouncements.isNotEmpty) {
      final annCount = _recentAnnouncements.length;
      parts.add('$annCount announcement${annCount > 1 ? 's' : ''}');
    }

    if (parts.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final summaryText = parts.join(' · ');

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2F1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF80CBC4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              if (_unreadMessagesCount > 0) {
                await context.push('/admin/messages');
              } else if (_unreadTeacherAttendanceCount > 0) {
                await context.push('/admin/teacher-attendance');
              } else {
                await context.push('/admin/announcements');
              }
              if (mounted) _loadNotifications();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: Color(0xFF00695C), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      summaryText,
                      style: const TextStyle(
                        color: Color(0xFF004D40),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF00695C), size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, AuthProvider auth, AppLocalizations? loc) {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: Container(
            color: Colors.white.withValues(alpha: 0.85),
            child: Column(
              children: [
                // Drawer header
                Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 24,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                    border: Border.all(color: AppColors.goldAccent, width: 2),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.goldAccent, size: 30),
                ),
                const SizedBox(height: 12),
                Text(
                  _formatManagerName(auth.currentUser?.name),
                  style: const TextStyle(color: AppColors.goldAccent, fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Manager & Administrator',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          // Menu items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _drawerItem(context, icon: AppIcons.students, label: loc?.translate('students') ?? 'Students', route: AppRoutes.adminStudents),
                _drawerItem(context, icon: AppIcons.teachers, label: loc?.translate('teachers') ?? 'Teachers', route: AppRoutes.adminTeachers),
                _drawerItem(context, icon: Icons.how_to_reg_rounded, label: 'Teacher Attendance', route: '/admin/teacher-attendance'),
                _drawerItem(context, icon: AppIcons.batches, label: loc?.translate('batches') ?? 'Batches', route: AppRoutes.adminBatches),
                _drawerItem(context, icon: AppIcons.reports, label: loc?.translate('reports') ?? 'Reports', route: AppRoutes.adminReports),
                _drawerItem(context, icon: Icons.picture_as_pdf_rounded, label: 'Attendance Reports', route: '/admin/reports/attendance'),
                _drawerItem(context, icon: AppIcons.checklist, label: loc?.translate('checklist') ?? 'Checklist', route: AppRoutes.adminChecklist),
                _drawerItem(context, icon: Icons.chat_rounded, label: 'Messages', route: AppRoutes.adminMessages),
                _drawerItem(context, icon: Icons.account_balance_wallet_rounded, label: 'Payments', route: '/admin/payments'),
                _drawerItem(context, icon: AppIcons.settings, label: loc?.translate('settings') ?? 'Settings', route: AppRoutes.adminSettings),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _drawerItem(
                  context,
                  icon: CupertinoIcons.square_arrow_right,
                  label: loc?.translate('logout') ?? 'Logout',
                  route: '',
                  iconColor: AppColors.error,
                  textColor: AppColors.error,
                  onTap: () async {
                    await auth.logout();
                    if (context.mounted) context.go(AppRoutes.login);
                  },
                ),
              ],
            ),
          ),

          // Version footer
          Container(
            padding: const EdgeInsets.all(16),
            child: const Text('Maktab v1.0 · Offline · Secure', style: TextStyle(color: Colors.black26, fontSize: 11)),
          ),
        ],
      ),
      ),
      ),
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    Color? iconColor,
    Color? textColor,
    String? badge,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        leading: Icon(icon, color: iconColor ?? AppColors.primaryTeal, size: 22),
        title: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor ?? const Color(0xFF1A1A1A),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(10)),
                child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        trailing: Icon(Icons.chevron_right, size: 18, color: Colors.black26),
        onTap: onTap ?? () {
          Navigator.pop(context);
          if (route.isNotEmpty) context.push(route);
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
