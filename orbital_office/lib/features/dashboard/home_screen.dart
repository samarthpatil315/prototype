import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/invoice_calculator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/formatters.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/repositories/app_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final user = state.user;
    final now = DateTime.now();

    final stats = <String, Widget>{
      'documents': StatCard(
        label: 'Documents',
        value: '${state.documents.length}',
        icon: Icons.description_outlined,
        onTap: () => context.push('/documents'),
      ),
      'spreadsheets': StatCard(
        label: 'Spreadsheets',
        value: '${state.spreadsheets.length}',
        icon: Icons.grid_on_outlined,
        color: AppColors.premiumGold,
        onTap: () => context.push('/spreadsheets'),
      ),
      'projects': StatCard(
        label: 'Active Projects',
        value: '${state.projects.length}',
        icon: Icons.folder_open_outlined,
        onTap: () => context.push('/projects'),
      ),
      'tasks': StatCard(
        label: 'Pending Tasks',
        value: '${state.pendingTasks.length}',
        icon: Icons.check_circle_outline,
        color: Colors.orange.shade700,
        onTap: () => context.push('/projects'),
      ),
      'customers': StatCard(
        label: 'Customers',
        value: '${state.customers.length}',
        icon: Icons.people_outline,
        onTap: () => context.push('/customers'),
      ),
      'revenue': StatCard(
        label: 'Outstanding',
        value: Formatters.inr(state.revenueOutstanding),
        icon: Icons.account_balance_wallet_outlined,
        color: Colors.red.shade700,
        onTap: () => context.push('/invoices'),
      ),
    };

    final orderedKeys = [
      ...state.dashboardOrder.where(stats.containsKey),
      ...stats.keys.where((k) => !state.dashboardOrder.contains(k)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const OrbitalLogo(size: 30),
            const SizedBox(width: 10),
            Text('ORBITAL OFFICE',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: state.unreadNotifications > 0,
              label: Text('${state.unreadNotifications}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined),
            tooltip: 'AI Assistant',
            onPressed: () => context.push('/ai'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.read(appControllerProvider.notifier).syncNow(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (state.isDemo) const DemoBanner(),
            const SizedBox(height: 14),
            Text('${Formatters.greeting(now)}, ${user?.name.split(' ').first ?? 'there'}',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            Text(Formatters.date(now),
                style: const TextStyle(color: AppColors.mutedText)),
            SectionHeader(
              title: 'Your workspace',
              actionLabel: 'Customise',
              onAction: () => _customise(context, ref, stats.keys.toList()),
            ),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [for (final k in orderedKeys) stats[k]!],
            ),
            const SectionHeader(title: 'Quick create'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _QuickAction('Document', Icons.description_outlined, () => context.push('/create/document')),
                _QuickAction('Spreadsheet', Icons.grid_on_outlined, () => context.push('/create/spreadsheet')),
                _QuickAction('Presentation', Icons.slideshow_outlined, () => context.push('/create/presentation')),
                _QuickAction('Invoice', Icons.receipt_long_outlined, () => context.push('/create/invoice')),
                _QuickAction('Customer', Icons.person_add_outlined, () => context.push('/create/customer')),
                _QuickAction('Project', Icons.folder_open_outlined, () => context.push('/create/project')),
              ],
            ),
            const SectionHeader(title: 'Business analytics'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invoice totals (₹)',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Text(
                      'Collected ${Formatters.inr(state.revenueCollected)} • Outstanding ${Formatters.inr(state.revenueOutstanding)}',
                      style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(height: 170, child: _RevenueChart(state: state)),
                  ],
                ),
              ),
            ),
            SectionHeader(
              title: 'Recent files',
              actionLabel: 'All files',
              onAction: () => context.push('/files'),
            ),
            if (state.files.isEmpty)
              const EmptyState(
                icon: Icons.folder_open_outlined,
                title: 'No files yet',
                message: 'Create your first document, spreadsheet or presentation.',
              )
            else
              for (final f in state.files.take(5))
                Card(
                  child: ListTile(
                    leading: Icon(_iconFor(f.kind.name), color: AppColors.deepGreen),
                    title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('Edited ${Formatters.relative(f.updatedAt)}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openFile(context, f.kind.name, f.linkedId),
                  ),
                ),
            const SectionHeader(title: 'Recent activity'),
            if (state.pendingTasks.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.celebration_outlined, color: AppColors.premiumGold),
                  title: Text('All caught up'),
                  subtitle: Text('No pending tasks right now.'),
                ),
              )
            else
              for (final t in state.pendingTasks.take(4))
                Card(
                  child: CheckboxListTile(
                    value: false,
                    title: Text(t.title),
                    subtitle: Text(
                        '${t.priority.label} priority${t.dueDate != null ? ' • Due ${Formatters.date(t.dueDate!)}' : ''}'),
                    onChanged: (_) {
                      t.status = TaskStatus.completed;
                      ref.read(appControllerProvider.notifier).saveTask(t);
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _customise(BuildContext context, WidgetRef ref, List<String> keys) async {
    final controller = ref.read(appControllerProvider.notifier);
    var order = [...ref.read(appControllerProvider).dashboardOrder];
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Customise dashboard'),
        content: SizedBox(
          width: double.maxFinite,
          child: StatefulBuilder(
            builder: (context, setState) => ReorderableListView(
              shrinkWrap: true,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = order.removeAt(oldIndex);
                  order.insert(newIndex, item);
                });
              },
              children: [
                for (final k in order)
                  ListTile(key: ValueKey(k), title: Text(k), leading: const Icon(Icons.drag_handle)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              controller.setDashboardOrder(order);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

void _openFile(BuildContext context, String kind, String? linkedId) {
  if (linkedId == null) return;
  switch (kind) {
    case 'document':
      context.push('/document/$linkedId');
    case 'spreadsheet':
      context.push('/spreadsheet/$linkedId');
    case 'presentation':
      context.push('/presentation/$linkedId');
    case 'invoice':
    case 'quotation':
      context.push('/billing/$linkedId');
    default:
      context.push('/files');
  }
}

IconData _iconFor(String kind) => switch (kind) {
      'document' => Icons.description_outlined,
      'spreadsheet' => Icons.grid_on_outlined,
      'presentation' => Icons.slideshow_outlined,
      'invoice' || 'quotation' => Icons.receipt_long_outlined,
      'pdf' => Icons.picture_as_pdf_outlined,
      'image' => Icons.image_outlined,
      'csv' => Icons.table_chart_outlined,
      _ => Icons.insert_drive_file_outlined,
    };

class _QuickAction extends StatelessWidget {
  const _QuickAction(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: AppColors.forestGreen),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.white,
      side: BorderSide(color: AppColors.charcoal.withValues(alpha: 0.1)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final invoices = state.invoices.take(6).toList().reversed.toList();
    if (invoices.isEmpty) {
      return const Center(
        child: Text('Create an invoice to see analytics here.',
            style: TextStyle(color: AppColors.mutedText)),
      );
    }
    final maxY = invoices
        .map((i) => i.totals.grandTotal)
        .fold<double>(0, (a, b) => a > b ? a : b);
    return BarChart(
      BarChartData(
        maxY: (maxY <= 0 ? 1000 : maxY * 1.2),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= invoices.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(invoices[i].number.replaceAll('INV-', ''),
                      style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < invoices.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: invoices[i].totals.grandTotal,
                width: 22,
                borderRadius: BorderRadius.circular(6),
                color: invoices[i].paymentStatus == PaymentStatus.paid
                    ? AppColors.deepGreen
                    : AppColors.premiumGold,
              ),
            ]),
        ],
      ),
    );
  }
}
