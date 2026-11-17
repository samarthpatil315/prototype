import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utilities/formatters.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/repositories/app_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: state.unreadNotifications == 0
                ? null
                : () => ref
                    .read(appControllerProvider.notifier)
                    .markAllNotificationsRead(),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: state.notifications.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none_outlined,
              title: 'No notifications',
              message:
                  'Low-stock alerts, due-date reminders and sync updates will appear here. Push notifications (FCM) activate when a backend is configured.',
            )
          : ListView.builder(
              itemCount: state.notifications.length,
              itemBuilder: (context, i) {
                final n = state.notifications[i];
                return Card(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  color: n.read
                      ? null
                      : AppColors.deepGreen.withValues(alpha: 0.06),
                  child: ListTile(
                    leading: Icon(
                      n.read
                          ? Icons.notifications_none_outlined
                          : Icons.notifications_active_outlined,
                      color: AppColors.deepGreen,
                    ),
                    title: Text(n.title,
                        style: TextStyle(
                            fontWeight:
                                n.read ? FontWeight.normal : FontWeight.w700)),
                    subtitle: Text('${n.body}\n${Formatters.relative(n.at)}'),
                    isThreeLine: true,
                    onTap: () {
                      ref
                          .read(appControllerProvider.notifier)
                          .markNotificationRead(n.id);
                      if (n.route != null) context.push(n.route!);
                    },
                  ),
                );
              },
            ),
    );
  }
}
