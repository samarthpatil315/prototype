import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/invoice_calculator.dart';
import '../../core/services/pdf_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/formatters.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../data/repositories/app_controller.dart';

class BillingListScreen extends ConsumerWidget {
  const BillingListScreen({super.key, required this.kind});
  final BillingKind kind;

  bool get _isInvoice => kind == BillingKind.invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final list = _isInvoice ? state.invoices : state.quotations;
    return Scaffold(
      appBar: AppBar(title: Text(_isInvoice ? 'Invoices' : 'Quotations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(_isInvoice ? '/create/invoice' : '/create/quotation'),
        icon: const Icon(Icons.add),
        label: Text(_isInvoice ? 'New Invoice' : 'New Quotation'),
      ),
      body: list.isEmpty
          ? EmptyState(
              icon: Icons.receipt_long_outlined,
              title: _isInvoice ? 'No invoices yet' : 'No quotations yet',
              message: 'Create professional, print-ready ${kind.name}s with automatic totals (INR by default).',
              actionLabel: _isInvoice ? 'New Invoice' : 'New Quotation',
              onAction: () => context.push(_isInvoice ? '/create/invoice' : '/create/quotation'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final inv = list[i];
                final t = inv.totals;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.deepGreen.withValues(alpha: 0.1),
                      child: const Icon(Icons.receipt_long, color: AppColors.deepGreen),
                    ),
                    title: Text('${inv.number} • ${inv.customerName.isEmpty ? 'Walk-in customer' : inv.customerName}'),
                    subtitle: Text(
                        '${Formatters.date(inv.issueDate)} • ${Formatters.money(t.grandTotal, symbol: inv.currencySymbol)}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (_isInvoice)
                          StatusChip(
                            label: inv.isOverdue
                                ? 'OVERDUE'
                                : inv.paymentStatus.name.toUpperCase(),
                            color: inv.paymentStatus == PaymentStatus.paid
                                ? AppColors.deepGreen
                                : inv.isOverdue
                                    ? Colors.red.shade700
                                    : Colors.orange.shade800,
                          )
                        else
                          const StatusChip(label: 'QUOTATION'),
                        if (_isInvoice && t.balanceDue > 0)
                          Text('Due ${Formatters.money(t.balanceDue, symbol: inv.currencySymbol)}',
                              style: const TextStyle(fontSize: 11, color: AppColors.mutedText)),
                      ],
                    ),
                    onTap: () => context.push('/billing/${inv.id}'),
                  ),
                );
              },
            ),
    );
  }
}

// ------------------------------------------------------------------ Editor
class BillingEditorScreen extends ConsumerStatefulWidget {
  const BillingEditorScreen({super.key, required this.billingId});
  final String billingId;
  @override
  ConsumerState<BillingEditorScreen> createState() => _BillingEditorScreenState();
}

class _BillingEditorScreenState extends ConsumerState<BillingEditorScreen> {
  InvoiceDoc? get _doc =>
      ref.read(appControllerProvider.notifier).billingById(widget.billingId);

  void _save() {
    final d = _doc;
    if (d != null) ref.read(appControllerProvider.notifier).saveBilling(d);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final doc = state.invoices
        .followedBy(state.quotations)
        .where((i) => i.id == widget.billingId);
    if (doc.isEmpty) {
      return const Scaffold(
          body: EmptyState(icon: Icons.error_outline, title: 'Not found', message: 'This document may have been deleted.'));
    }
    final inv = doc.first;
    final isInvoice = inv.kind == BillingKind.invoice;
    final totals = inv.totals;

    return Scaffold(
      appBar: AppBar(
        title: Text('${isInvoice ? 'Invoice' : 'Quotation'} ${inv.number}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Print / Preview PDF',
            onPressed: () => PdfService.printInvoice(inv),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share PDF',
            onPressed: () => PdfService.shareInvoice(inv),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              final c = ref.read(appControllerProvider.notifier);
              switch (v) {
                case 'payment':
                  final amount = await showTextInputDialog(context,
                      title: 'Record payment',
                      label: 'Amount (${inv.currencySymbol})',
                      submitLabel: 'Record');
                  final parsed = double.tryParse(amount ?? '');
                  if (parsed != null && parsed > 0) {
                    inv.amountPaid += parsed;
                    _save();
                  }
                case 'convert':
                  final created = c.convertQuotationToInvoice(inv);
                  if (context.mounted) context.pushReplacement('/billing/${created.id}');
                case 'delete':
                  c.deleteBilling(inv);
                  if (context.mounted) context.pop();
              }
            },
            itemBuilder: (_) => [
              if (isInvoice)
                const PopupMenuItem(value: 'payment', child: Text('Record payment')),
              if (!isInvoice)
                const PopupMenuItem(value: 'convert', child: Text('Convert to invoice')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _field('Business name', inv.businessName, (v) { inv.businessName = v; _save(); }),
                  _field('Business address', inv.businessAddress, (v) { inv.businessAddress = v; _save(); }),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String?>(
                    value: inv.customerId,
                    decoration: const InputDecoration(labelText: 'Customer (from CRM)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Walk-in / type below')),
                      for (final c in state.customers)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (id) {
                      inv.customerId = id;
                      if (id != null) {
                        final c = ref.read(appControllerProvider.notifier).customerById(id);
                        if (c != null) {
                          inv.customerName = c.name;
                          inv.customerAddress = c.address;
                        }
                      }
                      _save();
                    },
                  ),
                  _field('Customer name', inv.customerName, (v) { inv.customerName = v; _save(); }),
                  _field('Customer address', inv.customerAddress, (v) { inv.customerAddress = v; _save(); }),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Issue date', style: TextStyle(fontSize: 12)),
                          subtitle: Text(Formatters.date(inv.issueDate)),
                          trailing: const Icon(Icons.calendar_month_outlined),
                          onTap: () async {
                            final d = await showDatePicker(
                                context: context,
                                initialDate: inv.issueDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100));
                            if (d != null) { inv.issueDate = d; _save(); }
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Due date', style: TextStyle(fontSize: 12)),
                          subtitle: Text(Formatters.date(inv.dueDate)),
                          trailing: const Icon(Icons.event_outlined),
                          onTap: () async {
                            final d = await showDatePicker(
                                context: context,
                                initialDate: inv.dueDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100));
                            if (d != null) { inv.dueDate = d; _save(); }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader(title: 'Items'),
          for (var i = 0; i < inv.items.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('desc-${inv.id}-$i'),
                            initialValue: inv.items[i].description,
                            decoration: const InputDecoration(labelText: 'Description'),
                            onChanged: (v) { inv.items[i].description = v; _save(); },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: inv.items.length <= 1
                              ? null
                              : () { inv.items.removeAt(i); _save(); },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _numField('Qty', inv.items[i].quantity, (v) { inv.items[i].quantity = v; _save(); })),
                        const SizedBox(width: 8),
                        Expanded(child: _numField('Unit price (₹)', inv.items[i].unitPrice, (v) { inv.items[i].unitPrice = v; _save(); })),
                        const SizedBox(width: 8),
                        Expanded(child: _numField('Discount %', inv.items[i].discountPercent, (v) { inv.items[i].discountPercent = v; _save(); })),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Line total: ${Formatters.money(inv.items[i].asInput.net, symbol: inv.currencySymbol)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () {
              inv.items.add(InvoiceItem(description: 'Item', quantity: 1, unitPrice: 0));
              _save();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Item'),
          ),
          const SectionHeader(title: 'Totals & tax'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _numField('Invoice discount %', inv.discountPercent, (v) { inv.discountPercent = v; _save(); })),
                      const SizedBox(width: 8),
                      Expanded(child: _field('Tax label (e.g. GST)', inv.taxLabel, (v) { inv.taxLabel = v; _save(); })),
                      const SizedBox(width: 8),
                      Expanded(child: _numField('Tax %', inv.taxPercent, (v) { inv.taxPercent = v; _save(); })),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tax is fully configurable. Leave at 0% if tax does not apply to your business — ORBITAL never assumes your tax registration.',
                      style: TextStyle(fontSize: 11, color: AppColors.mutedText),
                    ),
                  ),
                  const Divider(height: 24),
                  _totalRow('Subtotal', totals.subtotal, inv),
                  if (totals.lineDiscountTotal > 0)
                    _totalRow('Item discounts', -totals.lineDiscountTotal, inv),
                  if (totals.invoiceDiscountAmount > 0)
                    _totalRow('Invoice discount', -totals.invoiceDiscountAmount, inv),
                  if (totals.taxAmount > 0)
                    _totalRow('${inv.taxLabel.isEmpty ? 'Tax' : inv.taxLabel} (${Formatters.number(inv.taxPercent)}%)', totals.taxAmount, inv),
                  const Divider(),
                  _totalRow('Grand Total', totals.grandTotal, inv, bold: true),
                  if (isInvoice) ...[
                    _totalRow('Paid', totals.amountPaid, inv),
                    _totalRow('Balance Due', totals.balanceDue, inv, bold: true),
                    const SizedBox(height: 8),
                    StatusChip(
                      label: inv.isOverdue ? 'OVERDUE' : inv.paymentStatus.name.toUpperCase(),
                      color: inv.paymentStatus == PaymentStatus.paid
                          ? AppColors.deepGreen
                          : inv.isOverdue
                              ? Colors.red.shade700
                              : Colors.orange.shade800,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: inv.notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes (printed on PDF)'),
            onChanged: (v) { inv.notes = v; _save(); },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _field(String label, String value, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      ),
    );
  }

  Widget _numField(String label, double value, ValueChanged<double> onChanged) {
    return TextFormField(
      initialValue: value == 0 ? '' : Formatters.number(value),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, isDense: true),
      onChanged: (v) => onChanged(double.tryParse(v.replaceAll(',', '')) ?? 0),
    );
  }

  Widget _totalRow(String label, double value, InvoiceDoc inv, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
      fontFeatures: AppTheme.tabular,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(Formatters.money(value, symbol: inv.currencySymbol), style: style),
        ],
      ),
    );
  }
}
