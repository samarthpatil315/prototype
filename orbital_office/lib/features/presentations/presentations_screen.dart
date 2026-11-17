import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/pdf_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/formatters.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../data/repositories/app_controller.dart';

class PresentationsScreen extends ConsumerWidget {
  const PresentationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Presentations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_customize_outlined),
            tooltip: 'Templates',
            onPressed: () => context.push('/templates'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create/presentation'),
        icon: const Icon(Icons.add),
        label: const Text('New Deck'),
      ),
      body: state.presentations.isEmpty
          ? EmptyState(
              icon: Icons.slideshow_outlined,
              title: 'No presentations yet',
              message: 'Build a pitch deck or product presentation with ORBITAL templates.',
              actionLabel: 'New Presentation',
              onAction: () => context.push('/create/presentation'),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: state.presentations.length,
              itemBuilder: (context, i) {
                final p = state.presentations[i];
                final first = p.slides.isEmpty ? null : p.slides.first;
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.push('/presentation/${p.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Container(
                            color: Color(first?.background ?? 0xFFF5F0E5),
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              first?.title ?? p.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: (first?.background ?? 0xFFF5F0E5) == 0xFFF5F0E5
                                    ? AppColors.forestGreen
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(
                                  '${p.slides.length} slides • ${Formatters.relative(p.updatedAt)}',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.mutedText)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ------------------------------------------------------------------ Editor
class PresentationEditorScreen extends ConsumerStatefulWidget {
  const PresentationEditorScreen({super.key, required this.deckId});
  final String deckId;
  @override
  ConsumerState<PresentationEditorScreen> createState() =>
      _PresentationEditorScreenState();
}

class _PresentationEditorScreenState
    extends ConsumerState<PresentationEditorScreen> {
  int _index = 0;
  bool _loaded = false;
  List<Slide> _slides = [];
  String _title = '';

  static const _backgrounds = [
    0xFFF5F0E5, 0xFFFFFFFF, 0xFF073D2D, 0xFF0B513B, 0xFFD5A044, 0xFF202A26,
  ];

  PresentationDoc? get _deck =>
      ref.read(appControllerProvider.notifier).presentationById(widget.deckId);

  void _load() {
    if (_loaded) return;
    final d = _deck;
    if (d == null) return;
    _title = d.title;
    _slides = d.slides.map((s) => s.copy()).toList();
    _loaded = true;
  }

  void _save() {
    final d = _deck;
    if (d == null) return;
    d.title = _title;
    d.slides = _slides;
    ref.read(appControllerProvider.notifier).savePresentation(d);
  }

  bool get _darkBg {
    if (_slides.isEmpty) return false;
    final bg = _slides[_index].background;
    return bg == 0xFF073D2D || bg == 0xFF0B513B || bg == 0xFF202A26;
  }

  @override
  Widget build(BuildContext context) {
    _load();
    if (_deck == null) {
      return const Scaffold(
          body: EmptyState(icon: Icons.error_outline, title: 'Presentation not found', message: 'It may have been deleted.'));
    }
    final slide = _slides.isEmpty ? null : _slides[_index.clamp(0, _slides.length - 1)];

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow_outlined),
            tooltip: 'Present / Preview',
            onPressed: slide == null
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _PresentMode(slides: _slides, title: _title),
                      ),
                    ),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF',
            onPressed: () async {
              final d = _deck!;
              d.slides = _slides;
              await PdfService.printPresentation(d);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'rename') {
                showTextInputDialog(context,
                        title: 'Rename presentation', label: 'Title', initial: _title)
                    .then((name) {
                  if (name != null && name.isNotEmpty) {
                    setState(() => _title = name);
                    _save();
                  }
                });
              } else if (v == 'delete') {
                ref.read(appControllerProvider.notifier).deletePresentation(widget.deckId);
                context.pop();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete deck')),
            ],
          ),
        ],
      ),
      body: slide == null
          ? EmptyState(
              icon: Icons.slideshow_outlined,
              title: 'No slides',
              message: 'Add your first slide to begin.',
              actionLabel: 'Add Slide',
              onAction: _addSlide,
            )
          : Column(
              children: [
                // Canvas (16:9)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(slide.background),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            key: ValueKey('title-${slide.id}'),
                            initialValue: slide.title,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _darkBg ? Colors.white : AppColors.forestGreen,
                            ),
                            decoration: const InputDecoration(
                                hintText: 'Slide title',
                                border: InputBorder.none,
                                filled: false),
                            onChanged: (v) {
                              slide.title = v;
                              _save();
                            },
                          ),
                          Expanded(
                            child: TextFormField(
                              key: ValueKey('body-${slide.id}'),
                              initialValue: slide.body,
                              maxLines: null,
                              expands: true,
                              style: TextStyle(
                                  color: _darkBg ? Colors.white70 : AppColors.charcoal),
                              decoration: const InputDecoration(
                                  hintText: 'Slide text…',
                                  border: InputBorder.none,
                                  filled: false),
                              onChanged: (v) {
                                slide.body = v;
                                _save();
                              },
                            ),
                          ),
                          for (var i = 0; i < slide.bullets.length; i++)
                            Row(
                              children: [
                                Text('• ',
                                    style: TextStyle(
                                        color: _darkBg ? AppColors.premiumGold : AppColors.deepGreen,
                                        fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: TextFormField(
                                    key: ValueKey('b-${slide.id}-$i'),
                                    initialValue: slide.bullets[i],
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: _darkBg ? Colors.white : null),
                                    decoration: const InputDecoration(
                                        hintText: 'Bullet point',
                                        border: InputBorder.none,
                                        filled: false,
                                        isDense: true),
                                    onChanged: (v) {
                                      slide.bullets[i] = v;
                                      _save();
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close, size: 15, color: _darkBg ? Colors.white70 : null),
                                  onPressed: () => setState(() {
                                    slide.bullets.removeAt(i);
                                    _save();
                                  }),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 16),
                        label: const Text('Bullet'),
                        onPressed: () => setState(() {
                          slide.bullets = [...slide.bullets, ''];
                          _save();
                        }),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.image_outlined, size: 16),
                        label: Text(slide.imageUrl == null ? 'Image ref' : 'Image set'),
                        onPressed: () async {
                          final url = await showTextInputDialog(context,
                              title: 'Image URL / description',
                              label: 'Image reference',
                              initial: slide.imageUrl ?? '');
                          if (url != null) {
                            setState(() {
                              slide.imageUrl = url.isEmpty ? null : url;
                              _save();
                            });
                          }
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.bar_chart, size: 16),
                        label: const Text('Chart note'),
                        onPressed: () => setState(() {
                          slide.bullets = [...slide.bullets, 'Chart: add your data insight'];
                          _save();
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Background picker
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(right: 8, top: 12),
                        child: Text('Background', style: TextStyle(fontSize: 12)),
                      ),
                      for (final bg in _backgrounds)
                        GestureDetector(
                          onTap: () => setState(() {
                            slide.background = bg;
                            _save();
                          }),
                          child: Container(
                            width: 36,
                            height: 36,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Color(bg),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: slide.background == bg
                                    ? AppColors.premiumGold
                                    : Colors.grey.shade400,
                                width: slide.background == bg ? 3 : 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(),
                // Filmstrip
                SizedBox(
                  height: 96,
                  child: ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _slides.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final s = _slides.removeAt(oldIndex);
                        _slides.insert(newIndex, s);
                        _index = newIndex;
                        _save();
                      });
                    },
                    itemBuilder: (context, i) {
                      final s = _slides[i];
                      return GestureDetector(
                        key: ValueKey(s.id),
                        onTap: () => setState(() => _index = i),
                        child: Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 10, top: 6, bottom: 6),
                          decoration: BoxDecoration(
                            color: Color(s.background),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: i == _index ? AppColors.deepGreen : Colors.grey.shade300,
                              width: i == _index ? 2.4 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            '${i + 1}. ${s.title}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _addSlide,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Slide'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          final copy = _slides[_index].copy();
                          _slides.insert(_index + 1,
                              Slide(id: newId(), title: copy.title, body: copy.body, background: copy.background, bullets: List.of(copy.bullets), imageUrl: copy.imageUrl));
                          _index++;
                          _save();
                        }),
                        icon: const Icon(Icons.copy, size: 17),
                        label: const Text('Duplicate'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _slides.length <= 1
                            ? null
                            : () => setState(() {
                                  _slides.removeAt(_index);
                                  if (_index >= _slides.length) _index = _slides.length - 1;
                                  _save();
                                }),
                        icon: const Icon(Icons.delete_outline, size: 17),
                        label: const Text('Delete'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _addSlide() {
    setState(() {
      _slides.add(Slide(id: newId(), title: 'New Slide', body: ''));
      _index = _slides.length - 1;
      _save();
    });
  }
}

class _PresentMode extends StatefulWidget {
  const _PresentMode({required this.slides, required this.title});
  final List<Slide> slides;
  final String title;
  @override
  State<_PresentMode> createState() => _PresentModeState();
}

class _PresentModeState extends State<_PresentMode> {
  final _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.slides.length,
        itemBuilder: (context, i) {
          final s = widget.slides[i];
          final dark = s.background == 0xFF073D2D ||
              s.background == 0xFF0B513B ||
              s.background == 0xFF202A26;
          return Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Color(s.background),
                padding: const EdgeInsets.all(36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title,
                        style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: dark ? Colors.white : AppColors.forestGreen)),
                    const SizedBox(height: 16),
                    if (s.body.isNotEmpty)
                      Text(s.body,
                          style: TextStyle(
                              fontSize: 18,
                              color: dark ? Colors.white70 : AppColors.charcoal)),
                    for (final b in s.bullets)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('•  $b',
                            style: TextStyle(
                                fontSize: 17,
                                color: dark ? Colors.white : AppColors.charcoal)),
                      ),
                    const Spacer(),
                    Text('${i + 1} / ${widget.slides.length}',
                        style: TextStyle(
                            fontSize: 12,
                            color: dark ? Colors.white54 : AppColors.mutedText)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
