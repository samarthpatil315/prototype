import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/repositories/app_controller.dart';

/// Workspace hub (bottom-nav item 2): every office module in one grid,
/// plus folders for organising files.
class WorkspaceScreen extends ConsumerWidget {
  const WorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final modules = <(String, IconData, String, String)>[
      ('Documents', Icons.description_outlined, '${state.documents.length} files', '/documents'),
      ('Spreadsheets', Icons.grid_on_outlined, '${state.spreadsheets.length} files', '/spreadsheets'),
      ('Presentations', Icons.slideshow_outlined, '${state.presentations.length} decks', '/presentations'),
      ('Templates', Icons.dashboard_customize_outlined, 'Gallery', '/templates'),
      ('File Manager', Icons.folder_outlined, '${state.files.length} files', '/files'),
      ('AI Assistant', Icons.smart_toy_outlined, 'Draft & summarise', '/ai'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Workspace')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.isDemo) const DemoBanner(),
          const SectionHeader(title: 'Office modules'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              for (final (label, icon, sub, route) in modules)
                Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    onTap: () => context.push(route),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, color: AppColors.deepGreen, size: 28),
                          const SizedBox(height: 10),
                          Text(label,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text(sub,
                              style: const TextStyle(
                                  color: AppColors.mutedText, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SectionHeader(
            title: 'Folders',
            actionLabel: 'New folder',
            onAction: () async {
              final name = await showTextInputDialog(context,
                  title: 'New folder', label: 'Folder name');
              if (name != null && name.isNotEmpty) {
                ref.read(appControllerProvider.notifier).addFolder(name);
              }
            },
          ),
          if (state.folders.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.create_new_folder_outlined),
                title: Text('No folders yet'),
                subtitle: Text('Folders help organise your files.'),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final f in state.folders)
                  Chip(
                    avatar: const Icon(Icons.folder, size: 18, color: AppColors.premiumGold),
                    label: Text(f.name),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Business hub (bottom-nav item 4).
class BusinessScreen extends ConsumerWidget {
  const BusinessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final items = <(String, IconData, String, String)>[
      ('Invoices', Icons.receipt_long_outlined, '${state.invoices.length} invoices', '/invoices'),
      ('Quotations', Icons.request_quote_outlined, '${state.quotations.length} quotations', '/quotations'),
      ('Customers (CRM)', Icons.people_outline, '${state.customers.length} customers', '/customers'),
      ('Inventory', Icons.inventory_2_outlined, '${state.products.length} products • ${state.lowStockProducts.length} low stock', '/inventory'),
      ('Projects', Icons.folder_open_outlined, '${state.projects.length} projects', '/projects'),
      ('Tasks', Icons.check_circle_outline, '${state.pendingTasks.length} pending', '/projects?tab=tasks'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Business')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.isDemo) const DemoBanner(),
          const SizedBox(height: 8),
          for (final (label, icon, sub, route) in items)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.deepGreen.withValues(alpha: 0.1),
                  child: Icon(icon, color: AppColors.deepGreen),
                ),
                title: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(sub),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(route),
              ),
            ),
          const SizedBox(height: 8),
          Card(
            color: AppColors.forestGreen,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Outstanding balance',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(
                    '₹${state.revenueOutstanding.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${state.invoices.where((i) => i.isOverdue).length} overdue invoice(s)',
                    style: const TextStyle(color: AppColors.premiumGold, fontSize: 12),
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
