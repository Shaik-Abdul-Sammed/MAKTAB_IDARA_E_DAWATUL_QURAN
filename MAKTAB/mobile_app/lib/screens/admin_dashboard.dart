import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maktab_app/providers/auth_provider.dart';
import 'package:maktab_app/repositories/student_repository.dart';
import 'package:maktab_app/repositories/user_repository.dart';
import 'package:maktab_app/repositories/batch_repository.dart';
import 'package:maktab_app/repositories/attendance_repository.dart';
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
  List<Map<String, dynamic>> _recentAttendance = [];



  @override
  void initState() {
    super.initState();
    _fetchDashboardStats();


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



  Future<void> _fetchDashboardStats() async {
    final students = await StudentRepository().getAllStudents();
    final teachers = await UserRepository().getAllTeachers();
    final batches = await BatchRepository().getAllBatches();
    final recentAtt = await AttendanceRepository().getRecentStudentAttendance(limit: 5);
    if (mounted) {
      setState(() {
        _totalStudents = students.length;
        _totalTeachers = teachers.length;
        _totalBatches = batches.length;
        _recentAttendance = recentAtt;
      });
    }
  }


  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // ── Feature card ──────────────────────────────────────────────────────────

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
                                    color: (iconColor ?? teal).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                    boxShadow: hover ? [
                                      BoxShadow(color: (iconColor ?? teal).withValues(alpha: 0.3), blurRadius: 8)
                                    ] : [],
                                  ),
                                  child: Icon(icon, color: iconColor ?? teal, size: 28),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 13,
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


  Widget _buildStatCard(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
              Icon(Icons.trending_up_rounded, size: 16, color: color.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedCounter(
            count: value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        ],
      ),
    );
  }


  // ── Section header ────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryTeal),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryTeal,
              letterSpacing: 0.3,
            )),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: AppColors.primaryTeal.withValues(alpha: 0.12))),
      ],
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
            const MaktabLogo(size: 30, showGlow: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc?.translate('admin_dashboard') ?? 'Admin Portal',
                    style: const TextStyle(
                      color: AppColors.goldAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const Text(
                    'Management Console',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
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
            },
          ),
          IconButton(
              icon: const Icon(AppIcons.search, size: 22),
              onPressed: () => showSearch(context: context, delegate: UniversalSearchDelegate()),
            ),
          IconButton(
              icon: const Icon(AppIcons.settings, size: 22),
              onPressed: () => context.push(AppRoutes.adminSettings),
            ),
          const LanguageToggle(),
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
                                auth.currentUser?.name ?? 'Administrator',
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
                      final isTablet = constraints.maxWidth >= 800;
                      return Row(
                        children: [
                          Expanded(child: _buildStatCard('Students', _totalStudents, AppIcons.students, AppColors.primaryTeal)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildStatCard('Teachers', _totalTeachers, AppIcons.teachers, const Color(0xFF1976D2))),
                          const SizedBox(width: 10),
                          Expanded(child: _buildStatCard('Batches', _totalBatches, AppIcons.batches, const Color(0xFF388E3C))),
                          if (isTablet) ...[
                            const SizedBox(width: 10),
                            Expanded(child: _buildStatCard('Attendance', 0, Icons.how_to_reg_rounded, const Color(0xFF7B1FA2))),
                          ],
                        ],
                      );
                    },
                  ),
                ),
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
                    final isTablet = constraints.crossAxisExtent >= 800;
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
                    final isTablet = constraints.crossAxisExtent >= 800;
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
                    final isTablet = constraints.crossAxisExtent >= 800;
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
                const Text('Administrator', style: TextStyle(color: AppColors.goldAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  auth.currentUser?.name ?? 'Super Admin',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                _drawerItem(context, icon: AppIcons.checklist, label: loc?.translate('checklist') ?? 'Checklist', route: AppRoutes.adminChecklist),
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
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor ?? const Color(0xFF1A1A1A),
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
