import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/invoice_calculator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/formatters.dart';
import '../../core/utilities/validators.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../data/repositories/app_controller.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});
  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _query = '';
  LeadStage? _stageFilter;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final list = state.customers.where((c) {
      final matchesQuery = c.name.toLowerCase().contains(_query.toLowerCase()) ||
          c.businessName.toLowerCase().contains(_query.toLowerCase());
      final matchesStage = _stageFilter == null || c.stage == _stageFilter;
      return matchesQuery && matchesStage;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Customers — CRM')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final name = await showTextInputDialog(context,
              title: 'Add customer', label: 'Customer name');
          if (name != null && name.isNotEmpty) {
            final c = ref.read(appControllerProvider.notifier).createCustomer(name);
            if (mounted) _openEditor(context, c.id);
          }
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Customer'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SearchBar(
              hintText: 'Search customers…',
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All stages'),
                  selected: _stageFilter == null,
                  onSelected: (_) => setState(() => _stageFilter = null),
                ),
                const SizedBox(width: 8),
                for (final s in LeadStage.values) ...[
                  ChoiceChip(
                    label: Text(s.label),
                    selected: _stageFilter == s,
                    onSelected: (_) => setState(() => _stageFilter = s),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          // Pipeline summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    for (final s in LeadStage.values)
                      Text(
                        '${s.label}: ${state.customers.where((c) => c.stage == s).length}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.people_outline,
                    title: 'No customers found',
                    message: 'Add customers and track them from New lead to Converted.',
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final c = list[i];
                      return Card(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.deepGreen.withValues(alpha: 0.12),
                            child: Text(
                              c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
                              style: const TextStyle(
                                  color: AppColors.forestGreen,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                          title: Text(c.name),
                          subtitle: Text([
                            if (c.businessName.isNotEmpty) c.businessName,
                            if (c.followUpDate != null)
                              'Follow-up ${Formatters.date(c.followUpDate!)}',
                          ].join(' • ')),
                          trailing: StatusChip(
                            label: c.stage.label,
                            color: c.stage == LeadStage.converted
                                ? AppColors.deepGreen
                                : c.stage == LeadStage.closed
                                    ? Colors.grey.shade700
                                    : AppColors.premiumGold,
                          ),
                          onTap: () => _openEditor(context, c.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openEditor(BuildContext context, String id) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CustomerEditor(customerId: id),
    );
  }
}

class _CustomerEditor extends ConsumerStatefulWidget {
  const _CustomerEditor({required this.customerId});
  final String customerId;
  @override
  ConsumerState<_CustomerEditor> createState() => _CustomerEditorState();
}

class _CustomerEditorState extends ConsumerState<_CustomerEditor> {
  final _form = GlobalKey<FormState>();

  Customer? get _customer =>
      ref.read(appControllerProvider.notifier).customerById(widget.customerId);

  @override
  Widget build(BuildContext context) {
    ref.watch(appControllerProvider);
    final c = _customer;
    if (c == null) return const SizedBox.shrink();
    void save() {
      ref.read(appControllerProvider.notifier).saveCustomer(c);
      setState(() {});
    }

    final history = [
      ...ref.read(appControllerProvider).invoices.where((i) => i.customerId == c.id),
      ...ref.read(appControllerProvider).quotations.where((i) => i.customerId == c.id),
    ];

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Customer details',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      ref.read(appControllerProvider.notifier).deleteCustomer(c.id);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field('Name', c.name, (v) { c.name = v; save(); }, validator: (v) => Validators.required(v, 'Name')),
              _field('Business name', c.businessName, (v) { c.businessName = v; save(); }),
              _field('Email', c.email, (v) { c.email = v; save(); }, validator: (v) => v == null || v.isEmpty ? null : Validators.email(v)),
              _field('Phone', c.phone, (v) { c.phone = v; save(); }, validator: (v) => Validators.phone(v)),
              _field('Address', c.address, (v) { c.address = v; save(); }),
              _field('Service requirements', c.requirements, (v) { c.requirements = v; save(); }),
              _field('Lead source', c.leadSource, (v) { c.leadSource = v; save(); }),
              _field('Notes / history', c.notes, (v) { c.notes = v; save(); }, maxLines: 3),
              DropdownButtonFormField<LeadStage>(
                value: c.stage,
                decoration: const InputDecoration(labelText: 'Lead stage'),
                items: [
                  for (final s in LeadStage.values)
                    DropdownMenuItem(value: s, child: Text('${s.label} (${s.code})')),
                ],
                onChanged: (s) {
                  if (s != null) { c.stage = s; save(); }
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Follow-up date'),
                subtitle: Text(c.followUpDate == null
                    ? 'Not set'
                    : Formatters.date(c.followUpDate!)),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: c.followUpDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) { c.followUpDate = d; save(); }
                },
              ),
              if (history.isNotEmpty) ...[
                const Divider(),
                const Text('Billing history',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                for (final h in history)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${h.number} — ${Formatters.money(h.totals.grandTotal, symbol: h.currencySymbol)}'),
                    subtitle: Text(Formatters.date(h.issueDate)),
                  ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, String value, ValueChanged<String> onChanged,
      {int maxLines = 1, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: value,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        validator: validator,
        onChanged: onChanged,
      ),
    );
  }
}
