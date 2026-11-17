import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utilities/formatters.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../data/repositories/app_controller.dart';

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});
  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  String _query = '';
  OfficeFileKind? _kindFilter;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<OfficeFile> _filtered(AppState state) {
    return state.files.where((f) {
      var base = f.name.toLowerCase().contains(_query.toLowerCase());
      if (_kindFilter != null) base = base && f.kind == _kindFilter;
      return base;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final all = _filtered(state);
    final recent = [...all]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final favourites = all.where((f) => f.favorite).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('File Manager'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'My Files'),
            Tab(text: 'Recent'),
            Tab(text: 'Favourites'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBar(
              hintText: 'Search files…',
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All types'),
                  selected: _kindFilter == null,
                  onSelected: (_) => setState(() => _kindFilter = null),
                ),
                const SizedBox(width: 8),
                for (final k in OfficeFileKind.values) ...[
                  ChoiceChip(
                    label: Text(k.name),
                    selected: _kindFilter == k,
                    onSelected: (_) => setState(() => _kindFilter = k),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _FileList(files: all),
                _FileList(files: recent.take(15).toList()),
                _FileList(files: favourites, emptyMessage: 'Favourite files will appear here.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FileList extends ConsumerWidget {
  const _FileList({required this.files, this.emptyMessage});
  final List<OfficeFile> files;
  final String? emptyMessage;

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _open(BuildContext context, OfficeFile f) {
    if (f.linkedId == null) return;
    switch (f.kind) {
      case OfficeFileKind.document:
        context.push('/document/${f.linkedId}');
      case OfficeFileKind.spreadsheet:
        context.push('/spreadsheet/${f.linkedId}');
      case OfficeFileKind.presentation:
        context.push('/presentation/${f.linkedId}');
      case OfficeFileKind.invoice:
      case OfficeFileKind.quotation:
        context.push('/billing/${f.linkedId}');
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (files.isEmpty) {
      return EmptyState(
        icon: Icons.folder_open_outlined,
        title: 'No files here',
        message: emptyMessage ?? 'Create a document, spreadsheet, presentation or invoice to see it here.',
      );
    }
    final controller = ref.read(appControllerProvider.notifier);
    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, i) {
        final f = files[i];
        return Card(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: ListTile(
            leading: Icon(_icon(f.kind), color: AppColors.deepGreen),
            title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
                '${f.kind.name} • ${_size(f.sizeBytes)} • ${Formatters.relative(f.updatedAt)}'),
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                switch (v) {
                  case 'open':
                    _open(context, f);
                  case 'rename':
                    final current = f.name.contains('.')
                        ? f.name.substring(0, f.name.lastIndexOf('.'))
                        : f.name;
                    final name = await showTextInputDialog(context,
                        title: 'Rename file', label: 'Name', initial: current);
                    if (name != null && name.isNotEmpty) {
                      controller.renameFile(f.id, name);
                    }
                  case 'delete':
                    controller.deleteFile(f.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'open', child: Text('Open')),
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
            onTap: () => _open(context, f),
          ),
        );
      },
    );
  }

  IconData _icon(OfficeFileKind k) => switch (k) {
        OfficeFileKind.document => Icons.description_outlined,
        OfficeFileKind.spreadsheet => Icons.grid_on_outlined,
        OfficeFileKind.presentation => Icons.slideshow_outlined,
        OfficeFileKind.invoice || OfficeFileKind.quotation => Icons.receipt_long_outlined,
        OfficeFileKind.pdf => Icons.picture_as_pdf_outlined,
        OfficeFileKind.image => Icons.image_outlined,
        OfficeFileKind.csv => Icons.table_chart_outlined,
        OfficeFileKind.other => Icons.insert_drive_file_outlined,
      };
}
