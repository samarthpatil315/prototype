
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utilities/formatters.dart';
import '../../core/utilities/validators.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/repositories/app_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final user = state.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.forestGreen,
                    child: Text(user?.initials ?? 'O',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? 'Guest',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800)),
                        Text(user?.email ?? '',
                            style: const TextStyle(color: AppColors.mutedText)),
                        if (user?.businessName.isNotEmpty ?? false)
                          Text(user!.businessName,
                              style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  if (state.isDemo) const StatusChip(label: 'DEMO', color: AppColors.premiumGold),
                ],
              ),
            ),
          ),
          const SectionHeader(title: 'Account'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit profile'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _editProfile(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  subtitle: const Text('Theme, sync, storage and about'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings'),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  trailing: state.unreadNotifications > 0
                      ? StatusChip(label: '${state.unreadNotifications} new')
                      : const Icon(Icons.chevron_right),
                  onTap: () => context.push('/notifications'),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Workspace summary'),
          Card(
            child: Column(
              children: [
                _row('Documents', '${state.documents.length}'),
                _row('Spreadsheets', '${state.spreadsheets.length}'),
                _row('Presentations', '${state.presentations.length}'),
                _row('Customers', '${state.customers.length}'),
                _row('Collected revenue',
                    Formatters.inr(state.revenueCollected)),
                _row('Outstanding',
                    Formatters.inr(state.revenueOutstanding)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(appControllerProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Log Out'),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => _confirmDelete(context, ref),
            icon: Icon(Icons.delete_forever_outlined, color: Colors.red.shade700),
            label: Text('Delete Account',
                style: TextStyle(color: Colors.red.shade700)),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              'ORBITAL OFFICE • BY ORBITAL.STUDIO.3\nWork Smarter. Create Better.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.mutedText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: Text(value,
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontFeatures: AppTheme.tabular)),
    );
  }

  Future<void> _editProfile(BuildContext context, WidgetRef ref) async {
    final user = ref.read(appControllerProvider).user;
    if (user == null) return;
    final name = TextEditingController(text: user.name);
    final business = TextEditingController(text: user.businessName);
    final phone = TextEditingController(text: user.phone);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: 10),
              TextField(controller: business, decoration: const InputDecoration(labelText: 'Business name')),
              const SizedBox(height: 10),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: user.email,
                enabled: false,
                decoration: const InputDecoration(labelText: 'Email (cannot be changed here)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (Validators.required(name.text, 'Name') == null) {
                ref.read(appControllerProvider.notifier).updateProfile(
                      name: name.text.trim(),
                      businessName: business.text.trim(),
                      phone: phone.text.trim(),
                    );
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
            'This removes your account and signs you out. Local demo/workspace data on this device remains until you clear app storage. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final err = await ref.read(appControllerProvider.notifier).deleteAccount();
      if (context.mounted) {
        if (err == null) {
          context.go('/login');
        } else {
          showSnack(context, err);
        }
      }
    }
  }
}
