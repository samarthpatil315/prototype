import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/csv_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/formatters.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../data/repositories/app_controller.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});
  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _query = '';
  String? _category;

  Future<void> _exportCsv(AppState state) async {
    final rows = <List<Object?>>[
      ['SKU', 'Product', 'Category', 'Purchase Price', 'Selling Price', 'Stock', 'Low Stock At'],
      for (final p in state.products)
        [p.sku, p.name, p.category, p.purchasePrice, p.sellingPrice, p.stock, p.lowStockThreshold],
    ];
    await Share.share(CsvService.encode(rows), subject: 'ORBITAL Inventory');
  }

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['csv'], withData: true);
    if (result == null || result.files.first.bytes == null) return;
    final rows = CsvService.decodeWithHeaders(
        utf8.decode(result.files.first.bytes!));
    final c = ref.read(appControllerProvider.notifier);
    var imported = 0;
    for (final row in rows) {
      final name = row['Product'] ?? row['Name'] ?? row['name'] ?? '';
      if (name.isEmpty) continue;
      final p = c.createProduct(name);
      p.sku = row['SKU'] ?? p.sku;
      p.category = row['Category'] ?? 'General';
      p.purchasePrice = double.tryParse(row['Purchase Price'] ?? '') ?? 0;
      p.sellingPrice = double.tryParse(row['Selling Price'] ?? '') ?? 0;
      p.stock = int.tryParse(row['Stock'] ?? '') ?? 0;
      c.saveProduct(p);
      imported++;
    }
    if (mounted) showSnack(context, 'Imported $imported product(s)');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final categories = {for (final p in state.products) p.category}.toList()..sort();
    final list = state.products.where((p) {
      final q = p.name.toLowerCase().contains(_query.toLowerCase()) ||
          p.sku.toLowerCase().contains(_query.toLowerCase());
      return q && (_category == null || p.category == _category);
    }).toList();
    final totalValue = state.products.fold<double>(0, (s, p) => s + p.stockValue);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'export') _exportCsv(state);
              if (v == 'import') _importCsv();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export', child: Text('Export CSV')),
              PopupMenuItem(value: 'import', child: Text('Import CSV')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final name = await showTextInputDialog(context,
              title: 'Add product', label: 'Product name');
          if (name != null && name.isNotEmpty) {
            final p = ref.read(appControllerProvider.notifier).createProduct(name);
            if (mounted) _openEditor(p.id);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryChip('Products', '${state.products.length}'),
                ),
                Expanded(
                  child: _SummaryChip('Stock value', Formatters.inr(totalValue)),
                ),
                Expanded(
                  child: _SummaryChip(
                    'Low stock',
                    '${state.lowStockProducts.length}',
                    alert: state.lowStockProducts.isNotEmpty,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBar(
              hintText: 'Search products or SKU…',
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (categories.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _category == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                  const SizedBox(width: 8),
                  for (final cat in categories) ...[
                    ChoiceChip(
                      label: Text(cat),
                      selected: _category == cat,
                      onSelected: (_) => setState(() => _category = cat),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No products found',
                    message: 'Add products or import a CSV to manage stock, pricing and low-stock alerts.',
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final p = list[i];
                      return Card(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: ListTile(
                          leading: Icon(
                            p.isLowStock
                                ? Icons.warning_amber_outlined
                                : Icons.inventory_2_outlined,
                            color: p.isLowStock
                                ? Colors.red.shade700
                                : AppColors.deepGreen,
                          ),
                          title: Text(p.name),
                          subtitle: Text(
                              '${p.sku} • ${p.category} • Buy ${Formatters.inr(p.purchasePrice)} / Sell ${Formatters.inr(p.sellingPrice)}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${p.stock} in stock',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: p.isLowStock
                                          ? Colors.red.shade700
                                          : null)),
                              if (p.isLowStock)
                                const Text('LOW STOCK',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.red,
                                        fontWeight: FontWeight.w700)),
                            ],
                          ),
                          onTap: () => _openEditor(p.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openEditor(String id) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ProductEditor(productId: id),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip(this.label, this.value, {this.alert = false});
  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: alert ? Colors.red.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: alert ? Colors.red.shade700 : null)),
            Text(label,
                style: const TextStyle(fontSize: 11, color: AppColors.mutedText)),
          ],
        ),
      ),
    );
  }
}

class _ProductEditor extends ConsumerStatefulWidget {
  const _ProductEditor({required this.productId});
  final String productId;
  @override
  ConsumerState<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends ConsumerState<_ProductEditor> {
  Product? get _product =>
      ref.read(appControllerProvider.notifier).productById(widget.productId);

  @override
  Widget build(BuildContext context) {
    ref.watch(appControllerProvider);
    final p = _product;
    if (p == null) return const SizedBox.shrink();
    final controller = ref.read(appControllerProvider.notifier);
    void save({int? change, String reason = 'Manual adjustment'}) {
      controller.saveProduct(p, stockChange: change, reason: reason);
      setState(() {});
    }

    final history =
        ref.read(appControllerProvider).movements.where((m) => m.productId == p.id).toList();

    return Padding(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text('Product', style: Theme.of(context).textTheme.titleLarge)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    controller.deleteProduct(p.id);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            _text('Product name', p.name, (v) { p.name = v; save(); }),
            _text('Product ID / SKU', p.sku, (v) { p.sku = v; save(); }),
            _text('Category', p.category, (v) { p.category = v; save(); }),
            Row(
              children: [
                Expanded(child: _num('Purchase price (₹)', p.purchasePrice, (v) { p.purchasePrice = v; save(); })),
                const SizedBox(width: 10),
                Expanded(child: _num('Selling price (₹)', p.sellingPrice, (v) { p.sellingPrice = v; save(); })),
              ],
            ),
            Row(
              children: [
                Expanded(child: _int('Low-stock alert at', p.lowStockThreshold, (v) { p.lowStockThreshold = v; save(); })),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Margin: ${Formatters.inr(p.margin)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Stock: ${p.stock}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () async {
                    final qty = await showTextInputDialog(context,
                        title: 'Stock out', label: 'Quantity', submitLabel: 'Remove');
                    final n = int.tryParse(qty ?? '');
                    if (n != null && n > 0) save(change: -n, reason: 'Stock out (manual)');
                  },
                  icon: const Icon(Icons.remove),
                  label: const Text('Out'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () async {
                    final qty = await showTextInputDialog(context,
                        title: 'Stock in', label: 'Quantity', submitLabel: 'Add');
                    final n = int.tryParse(qty ?? '');
                    if (n != null && n > 0) save(change: n, reason: 'Stock in (manual)');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('In'),
                ),
              ],
            ),
            if (history.isNotEmpty) ...[
              const Divider(height: 28),
              const Text('Stock movement history',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              for (final m in history.take(8))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    m.change >= 0 ? Icons.arrow_downward : Icons.arrow_upward,
                    color: m.change >= 0 ? AppColors.deepGreen : Colors.red,
                    size: 18,
                  ),
                  title: Text('${m.change >= 0 ? '+' : ''}${m.change} — ${m.reason}'),
                  subtitle: Text(Formatters.dateTime(m.at)),
                ),
            ],
            const SizedBox(height: 8),
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
    );
  }

  Widget _text(String label, String value, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      ),
    );
  }

  Widget _num(String label, double value, ValueChanged<double> onChanged) {
    return TextFormField(
      initialValue: value == 0 ? '' : Formatters.number(value),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      onChanged: (v) => onChanged(double.tryParse(v.replaceAll(',', '')) ?? 0),
    );
  }

  Widget _int(String label, int value, ValueChanged<int> onChanged) {
    return TextFormField(
      initialValue: '$value',
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
    );
  }
}
