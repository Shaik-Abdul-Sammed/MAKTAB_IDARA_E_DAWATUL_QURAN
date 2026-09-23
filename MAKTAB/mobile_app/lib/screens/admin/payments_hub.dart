import 'package:flutter/material.dart';
import 'package:maktab_app/config/app_colors.dart';
import 'package:maktab_app/screens/fees/fee_management_screen.dart';
import 'package:maktab_app/screens/admin/teacher_salary_management_screen.dart';

class PaymentsHubScreen extends StatelessWidget {
  const PaymentsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payments'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          ),
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppColors.goldAccent,
            tabs: [
              Tab(icon: Icon(Icons.school_rounded), text: 'Student Fees'),
              Tab(icon: Icon(Icons.payments_rounded), text: 'Teacher Salary'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            FeeManagementScreenBody(),
            TeacherSalaryScreenBody(),
          ],
        ),
      ),
    );
  }
}
