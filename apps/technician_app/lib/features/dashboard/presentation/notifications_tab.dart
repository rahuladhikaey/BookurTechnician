import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    const List<_PartnerNotification> notifications = [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All alerts marked as read.')),
                );
              },
              child: const Text('Mark all read', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: AppColors.textSecondary),
                  SizedBox(height: AppSpacing.s),
                  Text(
                    'No notifications yet',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 15),
                  ),
                  SizedBox(height: AppSpacing.xxs),
                  Text(
                    'You will receive broadcast alerts and job updates here.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.m),
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s),
        itemBuilder: (context, index) {
          final notif = notifications[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.m),
              side: BorderSide(color: notif.isUnread ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border),
            ),
            color: notif.isUnread ? AppColors.primary.withValues(alpha: 0.03) : AppColors.card,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: notif.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(notif.icon, color: notif.color, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notif.title,
                                style: TextStyle(
                                  fontWeight: notif.isUnread ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 13.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (notif.isUnread)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notif.body,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notif.time,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PartnerNotification {
  final String title;
  final String body;
  final String time;
  final IconData icon;
  final Color color;
  final bool isUnread;

  const _PartnerNotification({
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    required this.color,
    required this.isUnread,
  });
}
