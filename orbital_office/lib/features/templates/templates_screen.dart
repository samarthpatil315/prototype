import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../data/repositories/app_controller.dart';
import '../../data/repositories/template_catalog.dart';

class TemplatesScreen extends ConsumerStatefulWidget {
  const TemplatesScreen({super.key});
  @override
  ConsumerState<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends ConsumerState<TemplatesScreen> {
  String _query = '';
  String _category = 'All';
  bool _favouritesOnly = false;

  void _useTemplate(TemplateItem t) {
    final c = ref.read(appControllerProvider.notifier);
    c.markTemplateUsed(t.id);
    final now = DateTime.now();
    switch (t.kind) {
      case TemplateKind.document:
        final doc = TemplateCatalog.buildDocument(t.id, newId(), now);
        final created = c.createDocument(title: doc.title, blocks: doc.blocks);
        context.push('/document/${created.id}');
      case TemplateKind.spreadsheet:
        final sheet = TemplateCatalog.buildSpreadsheet(t.id, newId(), now);
        final created = c.createSpreadsheet(title: sheet.title, cells: sheet.cells);
        context.push('/spreadsheet/${created.id}');
      case TemplateKind.presentation:
        final deck = TemplateCatalog.buildPresentation(t.id, newId(), now, (_) => newId());
        final created = c.createPresentation(title: deck.title, slides: deck.slides);
        context.push('/presentation/${created.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    var list = TemplateCatalog.all.where((t) {
      final q = t.title.toLowerCase().contains(_query.toLowerCase()) ||
          t.description.toLowerCase().contains(_query.toLowerCase());
      final cat = _category == 'All' || t.category == _category;
      final fav = !_favouritesOnly || state.favoriteTemplates.contains(t.id);
      return q && cat && fav;
    }).toList();
    // Favourites and recently used float to the top.
    list.sort((a, b) {
      final af = state.favoriteTemplates.contains(a.id) ? 0 : 1;
      final bf = state.favoriteTemplates.contains(b.id) ? 0 : 1;
      return af.compareTo(bf);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Template Gallery')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBar(
              hintText: 'Search templates…',
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('★ Favourites'),
                  selected: _favouritesOnly,
                  onSelected: (v) => setState(() => _favouritesOnly = v),
                ),
                const SizedBox(width: 8),
                for (final cat in TemplateCatalog.categories) ...[
                  ChoiceChip(
                    label: Text(cat),
                    selected: _category == cat && !_favouritesOnly,
                    onSelected: (_) => setState(() {
                      _category = cat;
                      _favouritesOnly = false;
                    }),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          if (state.recentTemplates.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Recently used',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final id in state.recentTemplates)
                    if (TemplateCatalog.all.any((t) => t.id == id))
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(TemplateCatalog.all
                              .firstWhere((t) => t.id == id)
                              .title),
                          onPressed: () => _useTemplate(TemplateCatalog.all
                              .firstWhere((t) => t.id == id)),
                        ),
                      ),
                ],
              ),
            ),
          ],
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.dashboard_customize_outlined,
                    title: 'No templates found',
                    message: 'Try another search or category.',
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final t = list[i];
                      final fav = state.favoriteTemplates.contains(t.id);
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _preview(t),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 92,
                                width: double.infinity,
                                color: switch (t.kind) {
                                  TemplateKind.document => AppColors.deepGreen,
                                  TemplateKind.spreadsheet => AppColors.premiumGold,
                                  TemplateKind.presentation => AppColors.forestGreen,
                                },
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      switch (t.kind) {
                                        TemplateKind.document => Icons.description_outlined,
                                        TemplateKind.spreadsheet => Icons.grid_on_outlined,
                                        TemplateKind.presentation => Icons.slideshow_outlined,
                                      },
                                      color: Colors.white,
                                    ),
                                    const Spacer(),
                                    Text(t.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13)),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Text(t.description,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12, color: AppColors.mutedText)),
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                                        color: fav ? Colors.red : null, size: 20),
                                    onPressed: () => ref
                                        .read(appControllerProvider.notifier)
                                        .toggleTemplateFavorite(t.id),
                                  ),
                                  StatusChip(label: t.category),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () => _useTemplate(t),
                                    child: const Text('Use'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _preview(TemplateItem t) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            StatusChip(label: '${t.category} • ${t.kind.name}'),
            const SizedBox(height: 12),
            Text(t.description),
            const SizedBox(height: 8),
            const Text(
              'Original ORBITAL template. Using it creates an editable copy in your workspace — the template itself is never modified.',
              style: TextStyle(fontSize: 12, color: AppColors.mutedText),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _useTemplate(t);
                },
                icon: const Icon(Icons.add),
                label: const Text('Use This Template'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
