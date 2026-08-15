import 'package:flutter/material.dart';
import 'dashboard_page.dart';
import 'earnings_tab.dart';
import 'notifications_tab.dart';
import 'profile_tab.dart';
import '../../jobs/presentation/jobs_list_tab.dart';
import '../../../core/theme/app_colors.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _currentIndex = 0;

  void _onTabChange(int index) {
    setState(() {
      _currentIndex = index.clamp(0, 4);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      DashboardPage(onNavigateTab: _onTabChange),
      const JobsListTab(),
      const EarningsTab(),
      const NotificationsTab(),
      const ProfileTab(),
    ];

    final navItems = [
      const _ShellNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
      const _ShellNavItem(icon: Icons.work_outline_rounded, activeIcon: Icons.work_rounded, label: 'Jobs'),
      const _ShellNavItem(icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded, label: 'Earnings'),
      const _ShellNavItem(icon: Icons.notifications_outlined, activeIcon: Icons.notifications_rounded, label: 'Notifications'),
      const _ShellNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              final isSelected = index == _currentIndex;

              return InkWell(
                onTap: () => _onTabChange(index),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? 12 : 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryLight : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? item.activeIcon : item.icon,
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _ShellNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _ShellNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
