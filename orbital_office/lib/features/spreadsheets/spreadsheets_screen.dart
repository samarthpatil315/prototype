import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/csv_service.dart';
import '../../core/services/formula_engine.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/formatters.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../data/repositories/app_controller.dart';

class SpreadsheetsScreen extends ConsumerWidget {
  const SpreadsheetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spreadsheets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_customize_outlined),
            tooltip: 'Templates',
            onPressed: () => context.push('/templates'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create/spreadsheet'),
        icon: const Icon(Icons.add),
        label: const Text('New Sheet'),
      ),
      body: state.spreadsheets.isEmpty
          ? EmptyState(
              icon: Icons.grid_on_outlined,
              title: 'No spreadsheets yet',
              message: 'Create a sheet with real formulas — SUM, AVERAGE, IF and more.',
              actionLabel: 'New Spreadsheet',
              onAction: () => context.push('/create/spreadsheet'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.spreadsheets.length,
              itemBuilder: (context, i) {
                final s = state.spreadsheets[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.grid_on, color: AppColors.deepGreen),
                    title: Text(s.title),
                    subtitle: Text(
                        '${s.cells.length} cells • ${Formatters.relative(s.updatedAt)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref
                          .read(appControllerProvider.notifier)
                          .deleteSpreadsheet(s.id),
                    ),
                    onTap: () => context.push('/spreadsheet/${s.id}'),
                  ),
                );
              },
            ),
    );
  }
}

// ------------------------------------------------------------------ Editor
class SpreadsheetEditorScreen extends ConsumerStatefulWidget {
  const SpreadsheetEditorScreen({super.key, required this.sheetId});
  final String sheetId;
  @override
  ConsumerState<SpreadsheetEditorScreen> createState() =>
      _SpreadsheetEditorScreenState();
}

class _SpreadsheetEditorScreenState
    extends ConsumerState<SpreadsheetEditorScreen> {
  final _formulaBar = TextEditingController();
  String _selected = 'A1';
  bool _loaded = false;
  String _title = '';
  int _rows = 30;
  int _cols = 12;
  Map<String, String> _cells = {};
  final Set<String> _currencyCells = {};
  bool _highlightLarge = false;
  String _filterText = '';

  SpreadsheetDoc? get _sheet =>
      ref.read(appControllerProvider.notifier).spreadsheetById(widget.sheetId);

  void _load() {
    if (_loaded) return;
    final s = _sheet;
    if (s == null) return;
    _title = s.title;
    _rows = s.rows;
    _cols = s.columns;
    _cells = Map.of(s.cells);
    _syncFormulaBar();
    _loaded = true;
  }

  void _syncFormulaBar() {
    _formulaBar.text = _cells[_selected] ?? '';
  }

  void _commitFormulaBar() {
    setState(() {
      final v = _formulaBar.text.trim();
      if (v.isEmpty) {
        _cells.remove(_selected);
      } else {
        _cells[_selected] = v;
      }
    });
    _save();
  }

  void _save() {
    final s = _sheet;
    if (s == null) return;
    s.title = _title;
    s.cells = Map.of(_cells);
    s.rows = _rows;
    s.columns = _cols;
    ref.read(appControllerProvider.notifier).saveSpreadsheet(s);
  }

  String get _selectedDisplay {
    final values = FormulaEngine(_cells).evaluateAll();
    return values[_selected]?.display ?? '';
  }

  bool _rowVisible(int row) {
    if (_filterText.isEmpty) return true;
    for (var c = 0; c < _cols; c++) {
      final raw = _cells[CellRef.format(c, row)] ?? '';
      if (raw.toLowerCase().contains(_filterText.toLowerCase())) return true;
    }
    return false;
  }

  void _sortByColumn(int col, {required bool ascending}) {
    // Keep row 1 as header; sort data rows beneath it by computed value.
    final engine = FormulaEngine(_cells);
    final dataRows = <int>[];
    for (var r = 1; r < _rows; r++) {
      final hasData = List.generate(_cols, (c) => _cells[CellRef.format(c, r)])
          .any((v) => (v ?? '').isNotEmpty);
      if (hasData) dataRows.add(r);
    }
    final snapshots = {
      for (final r in dataRows)
        r: {for (var c = 0; c < _cols; c++) c: _cells[CellRef.format(c, r)]}
    };
    double sortKey(int r) =>
        engine.evaluateCell(CellRef.format(col, r)).number ?? double.nan;
    dataRows.sort((a, b) {
      final ka = sortKey(a);
      final kb = sortKey(b);
      if (ka.isNaN && kb.isNaN) return 0;
      if (ka.isNaN) return 1;
      if (kb.isNaN) return -1;
      return ascending ? ka.compareTo(kb) : kb.compareTo(ka);
    });
    setState(() {
      var target = 1;
      for (final sourceRow in dataRows) {
        for (var c = 0; c < _cols; c++) {
          final addr = CellRef.format(c, target);
          final v = snapshots[sourceRow]![c];
          if (v == null || v.isEmpty) {
            _cells.remove(addr);
          } else {
            _cells[addr] = v;
          }
        }
        target++;
      }
    });
    _save();
    showSnack(context, 'Sorted by column ${CellRef.indexToColumn(col)}');
  }

  Future<void> _exportCsv() async {
    final values = FormulaEngine(_cells).evaluateAll();
    final rows = <List<Object?>>[
      for (var r = 0; r < _rows; r++)
        [for (var c = 0; c < _cols; c++) values[CellRef.format(c, r)]?.display ?? ''],
    ];
    // Trim trailing empty rows/columns lightly by sharing as-is: CSV is exact.
    await Share.share(CsvService.encode(rows), subject: _title);
  }

  Future<void> _exportXlsx() async {
    try {
      final excel = xls.Excel.createExcel();
      final sheet = excel['Sheet1'];
      final values = FormulaEngine(_cells).evaluateAll();
      for (var r = 0; r < _rows; r++) {
        for (var c = 0; c < _cols; c++) {
          final v = values[CellRef.format(c, r)];
          if (v == null || v.isEmpty) continue;
          sheet
              .cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
              .value = v.number != null
              ? xls.DoubleCellValue(v.number!)
              : xls.TextCellValue(v.display);
        }
      }
      final bytes = excel.encode();
      if (bytes == null) throw Exception('encode failed');
      await Share.shareXFiles(
        [XFile.fromData(Uint8List.fromList(bytes), name: '$_title.xlsx', mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        subject: _title,
      );
    } catch (_) {
      if (mounted) showSnack(context, 'XLSX export is not available on this device. Use CSV export instead.');
    }
  }

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) {
      if (mounted) showSnack(context, 'Could not read that file on this device.');
      return;
    }
    final rows = CsvService.decode(utf8.decode(bytes));
    setState(() {
      _cells = {};
      _rows = rows.length.clamp(10, 200);
      _cols = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m).clamp(4, 40);
      for (var r = 0; r < rows.length; r++) {
        for (var c = 0; c < rows[r].length; c++) {
          final v = rows[r][c].toString();
          if (v.isNotEmpty) _cells[CellRef.format(c, r)] = v;
        }
      }
    });
    _save();
    if (mounted) showSnack(context, 'CSV imported');
  }

  void _showChart() {
    final parsed = CellRef.parse(_selected);
    final col = parsed?.$1 ?? 0;
    final engine = FormulaEngine(_cells);
    final data = <(String, double)>[];
    for (var r = 1; r < _rows; r++) {
      final v = engine.evaluateCell(CellRef.format(col, r));
      if (v.number != null) {
        final label = _cells[CellRef.format(0, r)] ?? 'Row ${r + 1}';
        data.add((label, v.number!));
      }
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chart — Column ${CellRef.indexToColumn(col)}'),
        content: SizedBox(
          width: double.maxFinite,
          height: 260,
          child: data.isEmpty
              ? const Center(child: Text('No numeric values in this column.'))
              : BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: const FlTitlesData(
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    barGroups: [
                      for (var i = 0; i < data.length; i++)
                        BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: data[i].$2,
                            width: 18,
                            color: AppColors.deepGreen,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ]),
                    ],
                  ),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _formulaBar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _load();
    if (_sheet == null) {
      return const Scaffold(
          body: EmptyState(icon: Icons.error_outline, title: 'Spreadsheet not found', message: 'It may have been deleted.'));
    }
    final values = FormulaEngine(_cells).evaluateAll();

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'csv':
                  _exportCsv();
                case 'xlsx':
                  _exportXlsx();
                case 'import':
                  _importCsv();
                case 'chart':
                  _showChart();
                case 'rename':
                  showTextInputDialog(context,
                          title: 'Rename spreadsheet', label: 'Title', initial: _title)
                      .then((name) {
                    if (name != null && name.isNotEmpty) {
                      setState(() => _title = name);
                      _save();
                    }
                  });
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'chart', child: Text('Chart selected column')),
              PopupMenuItem(value: 'csv', child: Text('Export CSV')),
              PopupMenuItem(value: 'xlsx', child: Text('Export XLSX')),
              PopupMenuItem(value: 'import', child: Text('Import CSV')),
              PopupMenuItem(value: 'rename', child: Text('Rename')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Formula bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: Theme.of(context).cardColor,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.deepGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_selected,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 6),
                const Text('fx', style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.mutedText)),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _formulaBar,
                    decoration: const InputDecoration(
                      hintText: 'Value or formula, e.g. =SUM(A1:A5)',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _commitFormulaBar(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.check), onPressed: _commitFormulaBar),
              ],
            ),
          ),
          if ((values[_selected]?.isError ?? false))
            Container(
              width: double.infinity,
              color: Colors.red.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                'Formula error in $_selected: ${values[_selected]!.error}. Check references and syntax.',
                style: TextStyle(color: Colors.red.shade800, fontSize: 12),
              ),
            )
          else if (_selectedDisplay.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Text('$_selected = $_selectedDisplay',
                  style: const TextStyle(fontSize: 12, color: AppColors.mutedText)),
            ),
          // Toolbar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                _tool(Icons.sort_by_alpha, 'Sort ↑', () {
                  final p = CellRef.parse(_selected);
                  if (p != null) _sortByColumn(p.$1, ascending: true);
                }),
                _tool(Icons.sort, 'Sort ↓', () {
                  final p = CellRef.parse(_selected);
                  if (p != null) _sortByColumn(p.$1, ascending: false);
                }),
                _tool(Icons.currency_rupee, _currencyCells.contains(_selected) ? '₹ On' : '₹ Format', () {
                  setState(() {
                    if (!_currencyCells.add(_selected)) _currencyCells.remove(_selected);
                  });
                }),
                _tool(Icons.highlight, _highlightLarge ? 'Highlight >1000: On' : 'Highlight >1000', () {
                  setState(() => _highlightLarge = !_highlightLarge);
                }),
                _tool(Icons.filter_alt_outlined, _filterText.isEmpty ? 'Filter rows' : 'Filter: $_filterText', () async {
                  final q = await showTextInputDialog(context,
                      title: 'Filter rows containing', label: 'Text', initial: _filterText);
                  if (q != null) setState(() => _filterText = q);
                }),
                _tool(Icons.view_column_outlined, 'Add column', () {
                  setState(() => _cols = (_cols + 1).clamp(1, 40));
                  _save();
                }),
                _tool(Icons.view_agenda_outlined, 'Add row', () {
                  setState(() => _rows = (_rows + 1).clamp(1, 200));
                  _save();
                }),
                _tool(Icons.functions, 'Functions: SUM  AVERAGE  COUNT  MIN  MAX  IF', () {}),
              ],
            ),
          ),
          const Divider(height: 1),
          // Grid
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Column headers (frozen header row)
                    Row(
                      children: [
                        const _CornerCell(''),
                        for (var c = 0; c < _cols; c++)
                          _HeaderCell(
                            CellRef.indexToColumn(c),
                            selected: CellRef.parse(_selected)?.$1 == c,
                            onTap: () => setState(() {
                              _selected = CellRef.format(c, 0);
                              _syncFormulaBar();
                            }),
                          ),
                      ],
                    ),
                    for (var r = 0; r < _rows; r++)
                      if (_rowVisible(r))
                        Row(
                          children: [
                            _CornerCell('${r + 1}'),
                            for (var c = 0; c < _cols; c++)
                              _GridCell(
                                address: CellRef.format(c, r),
                                value: values[CellRef.format(c, r)],
                                selected: _selected == CellRef.format(c, r),
                                isHeaderRow: r == 0,
                                currency: _currencyCells.contains(CellRef.format(c, r)),
                                highlight: _highlightLarge &&
                                    (values[CellRef.format(c, r)]?.number ?? 0) > 1000,
                                onTap: () => setState(() {
                                  _selected = CellRef.format(c, r);
                                  _syncFormulaBar();
                                }),
                              ),
                          ],
                        ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Formulas recalculate automatically, including dependent cells. Circular references show #CYCLE!.',
              style: TextStyle(fontSize: 11, color: AppColors.mutedText),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tool(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: onTap,
      ),
    );
  }
}

class _CornerCell extends StatelessWidget {
  const _CornerCell(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text, {required this.selected, required this.onTap});
  final String text;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 104,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.deepGreen.withValues(alpha: 0.15)
              : AppColors.lightGrey,
          border: Border.all(color: Colors.grey.shade300, width: 0.5),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.address,
    required this.value,
    required this.selected,
    required this.isHeaderRow,
    required this.currency,
    required this.highlight,
    required this.onTap,
  });

  final String address;
  final CellValue? value;
  final bool selected;
  final bool isHeaderRow;
  final bool currency;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = value;
    String text = v?.display ?? '';
    if (currency && v?.number != null) text = Formatters.inr(v!.number!);
    Color bg = Colors.white;
    if (isHeaderRow) bg = AppColors.warmIvory;
    if (highlight) bg = AppColors.premiumGold.withValues(alpha: 0.25);
    if (v?.isError ?? false) bg = Colors.red.shade50;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 104,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(
            color: selected ? AppColors.deepGreen : Colors.grey.shade300,
            width: selected ? 1.8 : 0.5,
          ),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isHeaderRow ? FontWeight.w700 : FontWeight.normal,
            color: (v?.isError ?? false) ? Colors.red.shade700 : null,
            fontFeatures: AppTheme.tabular,
          ),
        ),
      ),
    );
  }
}
