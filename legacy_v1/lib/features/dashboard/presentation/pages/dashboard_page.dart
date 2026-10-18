import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../widgets/home_tab.dart';
import '../widgets/account_tab.dart';
import '../widgets/futuristic_bottom_nav.dart';
import '../../../attendance/presentation/pages/attendance_tab.dart';
import '../../../schedule/presentation/pages/schedule_tab.dart';
import '../../../attendance/presentation/pages/performance_tab.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    HomeTab(),
    AttendanceTab(),
    ScheduleTab(),
    PerformanceTab(),
    AccountTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      extendBody: true,
      bottomNavigationBar: FuturisticBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
