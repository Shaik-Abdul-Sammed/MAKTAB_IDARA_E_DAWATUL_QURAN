import 'package:flutter/material.dart';
import 'package:maktab_app/config/app_colors.dart';
import 'package:maktab_app/repositories/student_repository.dart';
import 'package:maktab_app/repositories/attendance_repository.dart';


class AnimatedAnalyticsScreen extends StatefulWidget {
  const AnimatedAnalyticsScreen({super.key});

  @override
  State<AnimatedAnalyticsScreen> createState() => _AnimatedAnalyticsScreenState();
}

class _AnimatedAnalyticsScreenState extends State<AnimatedAnalyticsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _chartAnim;

  int _selectedMonth = DateTime.now().month;
  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  final int _totalWorkingDays = 26;
  int _daysPresent = 0;
  final int _holidays = 4;
  int _leavesTaken = 0;
  int _totalStudents = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _chartAnim = CurvedAnimation(parent: _animController, curve: Curves.elasticOut);
  }


  Future<void> _fetchData() async {
    
    try {
      final students = await StudentRepository().getAllStudents();
      final attendances = await AttendanceRepository().getAllAttendance();
      
      int present = 0;
      int leaves = 0;
      
      for (var a in attendances) {
        if (a.date.startsWith('${DateTime.now().year}-${_selectedMonth.toString().padLeft(2, '0')}')) {
          if (a.status == 'Present') {
            present++;
          } else if (a.status == 'Leave') {
            leaves++;
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _totalStudents = students.length;
          _daysPresent = present > 0 ? (present / (students.isEmpty ? 1 : students.length)).ceil() : 0;
          _leavesTaken = leaves > 0 ? (leaves / (students.isEmpty ? 1 : students.length)).ceil() : 0;
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, String sub) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(sub, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _build3DBar(String label, double heightRatio, Color color) {
    return AnimatedBuilder(
      animation: _chartAnim,
      builder: (context, child) {
        final animatedHeight = 160 * heightRatio * _chartAnim.value;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '${(heightRatio * 100).toInt()}%',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Container(
              width: 24,
              height: animatedHeight.clamp(4.0, 160.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.7), color],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(3, 3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendancePercentage = ((_daysPresent / _totalWorkingDays) * 100).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Analytics & 3D Reports',
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month Selector Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Monthly Analysis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryTeal)),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedMonth,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primaryTeal),
                        items: List.generate(12, (index) {
                          return DropdownMenuItem(
                            value: index + 1,
                            child: Text(_months[index], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          );
                        }),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedMonth = val;
                              _animController.reset();
                              _animController.forward();
                              _fetchData();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Overview Key Metrics Grid
              Row(
                children: [
                  _buildMetricCard('Days Present', '$_daysPresent / $_totalWorkingDays', Icons.check_circle_rounded, AppColors.success, '$attendancePercentage%'),
                  const SizedBox(width: 10),
                  _buildMetricCard('Holidays Calc', '$_holidays Days', Icons.beach_access_rounded, AppColors.goldAccent, 'Fridays'),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  _buildMetricCard('Leaves Taken', '$_leavesTaken Days', Icons.event_busy_rounded, AppColors.error, 'Approved'),
                  const SizedBox(width: 10),
                  _buildMetricCard('Total Students', '$_totalStudents Enrolled', Icons.groups_rounded, const Color(0xFF1976D2), 'Active'),
                ],
              ),

              const SizedBox(height: 20),

              // 3D Animated Bar Chart Container
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryTeal.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bar_chart_rounded, color: AppColors.primaryTeal, size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'Weekly Attendance Trend',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryTeal),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.goldAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('3D Graph', style: TextStyle(color: AppColors.primaryTeal, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Bar Chart Visualization
                    SizedBox(
                      height: 200,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _build3DBar('Week 1', 0.92, AppColors.primaryTeal),
                          _build3DBar('Week 2', 0.85, const Color(0xFF1976D2)),
                          _build3DBar('Week 3', 0.96, AppColors.success),
                          _build3DBar('Week 4', 0.88, const Color(0xFF7B1FA2)),
                        ],
                      ),
                    ),
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
