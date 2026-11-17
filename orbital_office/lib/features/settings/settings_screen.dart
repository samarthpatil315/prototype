import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/repositories/app_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'Appearance'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Theme mode',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_outlined),
                          label: Text('System')),
                      ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_outlined),
                          label: Text('Light')),
                      ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_outlined),
                          label: Text('Dark')),
                    ],
                    selected: {state.themeMode},
                    onSelectionChanged: (selection) =>
                        controller.setThemeMode(selection.first),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader(title: 'Data & sync'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.sync_outlined),
                  title: const Text('Sync now'),
                  subtitle: Text(AppConfig.supabaseConfigured
                      ? 'Push pending changes to Supabase'
                      : 'Demo mode — data is stored on this device only'),
                  onTap: () async {
                    final result = await controller.syncNow();
                    if (context.mounted) showSnack(context, result);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Export my data'),
                  subtitle: const Text('Download a JSON copy of your workspace'),
                  onTap: () async {
                    final s = ref.read(appControllerProvider);
                    final data = jsonEncode({
                      'exportedAt': DateTime.now().toIso8601String(),
                      'documents': s.documents.map((e) => e.toJson()).toList(),
                      'spreadsheets': s.spreadsheets.map((e) => e.toJson()).toList(),
                      'presentations': s.presentations.map((e) => e.toJson()).toList(),
                      'invoices': s.invoices.map((e) => e.toJson()).toList(),
                      'quotations': s.quotations.map((e) => e.toJson()).toList(),
                      'customers': s.customers.map((e) => e.toJson()).toList(),
                      'products': s.products.map((e) => e.toJson()).toList(),
                      'projects': s.projects.map((e) => e.toJson()).toList(),
                      'tasks': s.tasks.map((e) => e.toJson()).toList(),
                    });
                    await Share.share(data, subject: 'ORBITAL OFFICE data export');
                  },
                ),
                const ListTile(
                  leading: Icon(Icons.storage_outlined),
                  title: Text('Offline storage'),
                  subtitle: Text(
                      'SQLite on-device database. Drafts, tasks and files work fully offline; sync resumes automatically when a backend is configured.'),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'About'),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OrbitalLogo(size: 44),
                  SizedBox(height: 10),
                  Text('ORBITAL OFFICE',
                      style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                  Text('By ORBITAL.STUDIO.3 • Work Smarter. Create Better.'),
                  SizedBox(height: 6),
                  Text(
                    'Creative Design. Smart Digital Solutions.\nInstagram: @orbital.studio.3',
                    style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
