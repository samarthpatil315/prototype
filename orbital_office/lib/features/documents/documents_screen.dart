import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/pdf_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/formatters.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../data/repositories/app_controller.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});
  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final docs = state.documents
        .where((d) => d.title.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.library_books_outlined),
            tooltip: 'Templates',
            onPressed: () => context.push('/templates'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create/document'),
        icon: const Icon(Icons.add),
        label: const Text('New Document'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBar(
              hintText: 'Search documents…',
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: docs.isEmpty
                ? EmptyState(
                    icon: Icons.description_outlined,
                    title: 'No documents found',
                    message: 'Create a document or start from a template.',
                    actionLabel: 'New Document',
                    onAction: () => context.push('/create/document'),
                  )
                : ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      return Card(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: ListTile(
                          leading: const Icon(Icons.description_outlined,
                              color: AppColors.deepGreen),
                          title: Text(d.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                              '${d.wordCount} words • ${Formatters.relative(d.updatedAt)}'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              final c = ref.read(appControllerProvider.notifier);
                              switch (v) {
                                case 'fav':
                                  c.toggleDocumentFavorite(d.id);
                                case 'dup':
                                  c.duplicateDocument(d);
                                case 'rename':
                                  final name = await showTextInputDialog(context,
                                      title: 'Rename document',
                                      label: 'Title',
                                      initial: d.title);
                                  if (name != null && name.isNotEmpty) {
                                    d.title = name;
                                    c.saveDocument(d);
                                  }
                                case 'delete':
                                  c.deleteDocument(d.id);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                  value: 'fav',
                                  child: Text(d.favorite
                                      ? 'Remove favourite'
                                      : 'Add favourite')),
                              const PopupMenuItem(
                                  value: 'rename', child: Text('Rename')),
                              const PopupMenuItem(
                                  value: 'dup', child: Text('Duplicate')),
                              const PopupMenuItem(
                                  value: 'delete', child: Text('Delete')),
                            ],
                          ),
                          onTap: () => context.push('/document/${d.id}'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Editor
class DocumentEditorScreen extends ConsumerStatefulWidget {
  const DocumentEditorScreen({super.key, required this.documentId});
  final String documentId;
  @override
  ConsumerState<DocumentEditorScreen> createState() =>
      _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends ConsumerState<DocumentEditorScreen> {
  late TextEditingController _title;
  List<DocBlock> _blocks = [];
  final List<String> _undo = [];
  final List<String> _redo = [];
  bool _loaded = false;
  bool _dirty = false;
  String _find = '';
  int _findMatches = 0;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
  }

  void _loadIfNeeded() {
    if (_loaded) return;
    final doc = ref.read(appControllerProvider.notifier).documentById(widget.documentId);
    if (doc == null) return;
    _title.text = doc.title;
    _blocks = doc.blocks
        .map((b) => DocBlock(
            type: b.type,
            text: b.text,
            table: b.table.map((r) => List<String>.of(r)).toList()))
        .toList();
    if (_blocks.isEmpty) {
      _blocks = [DocBlock(type: DocBlockType.paragraph, text: '')];
    }
    _loaded = true;
  }

  String _snapshot() => jsonEncode(_blocks.map((b) => b.toJson()).toList());

  void _pushUndo() {
    _undo.add(_snapshot());
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
  }

  void _applySnapshot(String snap) {
    final list = (jsonDecode(snap) as List)
        .map((b) => DocBlock.fromJson(Map<String, dynamic>.from(b as Map)))
        .toList();
    setState(() {
      _blocks = list;
      _dirty = true;
    });
    _persistNow();
  }

  void _mutate(void Function() fn) {
    _pushUndo();
    setState(() {
      fn();
      _dirty = true;
    });
    _persistNow();
  }

  void _persistNow() {
    final c = ref.read(appControllerProvider.notifier);
    final doc = c.documentById(widget.documentId);
    if (doc == null) return;
    doc.title = _title.text.trim().isEmpty ? 'Untitled Document' : _title.text.trim();
    doc.blocks = _blocks;
    c.saveDocument(doc);
  }

  void _save() {
    _persistNow();
    setState(() => _dirty = false);
    showSnack(context, 'Document saved');
  }

  OrbitalDocument _currentDoc() {
    final existing =
        ref.read(appControllerProvider.notifier).documentById(widget.documentId);
    return OrbitalDocument(
      id: widget.documentId,
      title: _title.text,
      blocks: _blocks,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  void dispose() {
    // Edits autosave as they happen (see _persistNow calls), so dispose
    // never needs to touch Riverpod after unmount.
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _loadIfNeeded();
    final doc = ref.watch(appControllerProvider).documents
        .where((d) => d.id == widget.documentId);
    if (doc.isEmpty) {
      return const Scaffold(body: EmptyState(icon: Icons.error_outline, title: 'Document not found', message: 'It may have been deleted.'));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Document'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: _undo.isEmpty
                ? null
                : () {
                    _redo.add(_snapshot());
                    _applySnapshot(_undo.removeLast());
                  },
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            tooltip: 'Redo',
            onPressed: _redo.isEmpty
                ? null
                : () {
                    _undo.add(_snapshot());
                    _applySnapshot(_redo.removeLast());
                  },
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'pdf':
                  await PdfService.printDocument(_currentDoc());
                case 'share':
                  await Share.share(_blocks.map((b) => b.text).join('\n'),
                      subject: _title.text);
                case 'find':
                  final q = await showTextInputDialog(context,
                      title: 'Search in document', label: 'Search text', submitLabel: 'Search');
                  if (q != null) {
                    setState(() {
                      _find = q;
                      _findMatches = _blocks
                          .where((b) => b.text.toLowerCase().contains(q.toLowerCase()))
                          .length;
                    });
                  }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pdf', child: Text('Export / Print PDF')),
              PopupMenuItem(value: 'share', child: Text('Share as text')),
              PopupMenuItem(value: 'find', child: Text('Search in document')),
            ],
          ),
          IconButton(
            icon: Icon(_dirty ? Icons.save : Icons.check_circle_outline),
            tooltip: 'Save',
            onPressed: _save,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_find.isNotEmpty)
            MaterialBanner(
              content: Text('$_findMatches block(s) match "$_find"'),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _find = ''),
                  child: const Text('Clear'),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
              decoration: const InputDecoration(
                  hintText: 'Document title', border: InputBorder.none, filled: false),
              onChanged: (_) {
                setState(() => _dirty = true);
                _persistNow();
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _blocks.length,
              onReorder: (oldIndex, newIndex) {
                _mutate(() {
                  if (newIndex > oldIndex) newIndex--;
                  final b = _blocks.removeAt(oldIndex);
                  _blocks.insert(newIndex, b);
                });
              },
              itemBuilder: (context, i) {
                final block = _blocks[i];
                return Card(
                  key: ValueKey('block-$i-${identityHashCode(block)}'),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            StatusChip(label: block.type.name),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 19),
                              onPressed: () =>
                                  _mutate(() => _blocks.removeAt(i)),
                            ),
                            const Icon(Icons.drag_handle, size: 19),
                          ],
                        ),
                        if (block.type == DocBlockType.table)
                          _TableEditor(
                            block: block,
                            onChanged: () => _mutate(() {}),
                          )
                        else if (block.type == DocBlockType.divider)
                          const Divider(color: AppColors.premiumGold, thickness: 1.4)
                        else
                          TextFormField(
                            initialValue: block.text,
                            maxLines: block.type == DocBlockType.heading ? 2 : null,
                            minLines: 1,
                            style: block.type == DocBlockType.heading
                                ? Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)
                                : null,
                            decoration: InputDecoration(
                              hintText: block.type == DocBlockType.image
                                  ? 'Image description / URL'
                                  : 'Write here…',
                              border: InputBorder.none,
                              filled: false,
                            ),
                            onChanged: (v) {
                              block.text = v;
                              _dirty = true;
                              _persistNow();
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _FormatBar(onAdd: (type) {
            _mutate(() {
              if (type == DocBlockType.table) {
                _blocks.add(DocBlock(type: type, table: [
                  ['Item', 'Details'],
                  ['', ''],
                ]));
              } else {
                _blocks.add(DocBlock(type: type, text: ''));
              }
            });
          }),
        ],
      ),
    );
  }
}

class _FormatBar extends StatelessWidget {
  const _FormatBar({required this.onAdd});
  final void Function(DocBlockType) onAdd;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              _btn(Icons.title, 'Heading', () => onAdd(DocBlockType.heading)),
              _btn(Icons.notes, 'Text', () => onAdd(DocBlockType.paragraph)),
              _btn(Icons.format_list_bulleted, 'Bullets', () => onAdd(DocBlockType.bulletList)),
              _btn(Icons.format_list_numbered, 'Numbered', () => onAdd(DocBlockType.numberedList)),
              _btn(Icons.table_chart_outlined, 'Table', () => onAdd(DocBlockType.table)),
              _btn(Icons.image_outlined, 'Image', () => onAdd(DocBlockType.image)),
              _btn(Icons.horizontal_rule, 'Divider', () => onAdd(DocBlockType.divider)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 17),
        label: Text(label),
        onPressed: onTap,
      ),
    );
  }
}

class _TableEditor extends StatefulWidget {
  const _TableEditor({required this.block, required this.onChanged});
  final DocBlock block;
  final VoidCallback onChanged;
  @override
  State<_TableEditor> createState() => _TableEditorState();
}

class _TableEditorState extends State<_TableEditor> {
  @override
  Widget build(BuildContext context) {
    final table = widget.block.table;
    if (table.isEmpty) {
      return TextButton.icon(
        onPressed: () {
          table.add(['Column 1', 'Column 2']);
          widget.onChanged();
          setState(() {});
        },
        icon: const Icon(Icons.add),
        label: const Text('Add table'),
      );
    }
    return Column(
      children: [
        for (var r = 0; r < table.length; r++)
          Row(
            children: [
              for (var c = 0; c < table[r].length; c++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: TextFormField(
                      initialValue: table[r][c],
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: r == 0 ? FontWeight.w700 : FontWeight.normal),
                      decoration: const InputDecoration(
                          isDense: true, border: OutlineInputBorder()),
                      onChanged: (v) {
                        table[r][c] = v;
                        widget.onChanged();
                      },
                    ),
                  ),
                ),
            ],
          ),
        Row(
          children: [
            TextButton.icon(
              onPressed: () {
                table.add(List.filled(table.first.length, ''));
                widget.onChanged();
                setState(() {});
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Row'),
            ),
            TextButton.icon(
              onPressed: () {
                for (final row in table) {
                  row.add('');
                }
                widget.onChanged();
                setState(() {});
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Column'),
            ),
          ],
        ),
      ],
    );
  }
}
