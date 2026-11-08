import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/booking_request_manager.dart';
import 'partner_home_screen.dart';
import 'earnings_tab.dart';
import 'profile_tab.dart';
import '../../jobs/presentation/jobs_list_tab.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Sync any pending booking proposals when technician enters main shell
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BookingRequestManager().syncPendingRequests();
    });
  }

  void _onTabChange(int index) {
    if (_currentIndex != index) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentIndex = index.clamp(0, 3);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 4 Core Tabs: Duty, Bookings, Earnings, Profile
    final List<Widget> tabs = [
      PartnerHomeScreen(onNavigateTab: _onTabChange),
      const JobsListTab(),
      const EarningsTab(),
      const ProfileTab(),
    ];

    final navItems = [
      const _ShellNavItem(
        icon: Icons.radar_rounded,
        activeIcon: Icons.radar_rounded,
        label: 'Duty',
      ),
      const _ShellNavItem(
        icon: Icons.calendar_month_outlined,
        activeIcon: Icons.calendar_month_rounded,
        label: 'Bookings',
      ),
      const _ShellNavItem(
        icon: Icons.account_balance_wallet_outlined,
        activeIcon: Icons.account_balance_wallet_rounded,
        label: 'Earnings',
      ),
      const _ShellNavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Captain Hub',
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFEEE8E2), width: 1)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF222222).withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              final isSelected = index == _currentIndex;

              return InkWell(
                onTap: () => _onTabChange(index),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? 16 : 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF46B12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFF46B12).withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? item.activeIcon : item.icon,
                        color: isSelected ? Colors.white : const Color(0xFF77716C),
                        size: 22,
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Text(
                          item.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
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


