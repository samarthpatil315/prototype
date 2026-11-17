import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/ai_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../data/repositories/app_controller.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});
  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String raw) async {
    final prompt = raw.trim();
    if (prompt.isEmpty || _busy) return;
    final controller = ref.read(appControllerProvider.notifier);
    controller.addChatMessage(ChatMessage(
        id: newId(), text: prompt, fromUser: true, at: DateTime.now()));
    _input.clear();
    setState(() => _busy = true);
    _scrollDown();

    var text = await AiService.generate(prompt);
    // Spreadsheet analysis: enrich demo replies with live sheet numbers.
    if (prompt.toLowerCase().contains('spreadsheet') ||
        prompt.toLowerCase().contains('sales')) {
      final state = ref.read(appControllerProvider);
      if (state.spreadsheets.isNotEmpty) {
        text += '\n\nYour workspace has ${state.spreadsheets.length} spreadsheet(s). '
            'Open one and use the chart button to visualise a column.';
      }
    }
    controller.addChatMessage(ChatMessage(
        id: newId(), text: text, fromUser: false, at: DateTime.now()));
    if (mounted) setState(() => _busy = false);
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final chat = state.chat;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy_outlined, color: AppColors.deepGreen),
            SizedBox(width: 8),
            Text('AI Office Assistant'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear conversation',
            onPressed: () =>
                ref.read(appControllerProvider.notifier).clearChat(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: AppColors.premiumGold.withValues(alpha: 0.15),
            child: const Text(
              'Demo AI mode: template-based drafts generated on-device. Nothing is sent to an AI provider until a Supabase backend is configured. Drafts are not verified — always review before use.',
              style: TextStyle(fontSize: 11.5),
            ),
          ),
          Expanded(
            child: chat.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const EmptyState(
                        icon: Icons.smart_toy_outlined,
                        title: 'How can I help?',
                        message: 'Ask for a business letter, email, proposal, meeting notes, invoice descriptions or a task list.',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in AiService.suggestedPrompts)
                            ActionChip(
                              label: Text(s, style: const TextStyle(fontSize: 12)),
                              onPressed: () => _send(s),
                            ),
                        ],
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(14),
                    itemCount: chat.length,
                    itemBuilder: (context, i) {
                      final m = chat[i];
                      return Align(
                        alignment:
                            m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.82),
                          decoration: BoxDecoration(
                            color: m.fromUser
                                ? AppColors.forestGreen
                                : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: m.fromUser
                                ? null
                                : Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(
                                m.text,
                                style: TextStyle(
                                    color: m.fromUser ? Colors.white : null),
                              ),
                              if (!m.fromUser) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 4,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () async {
                                        await Clipboard.setData(
                                            ClipboardData(text: m.text));
                                        if (context.mounted) {
                                          showSnack(context, 'Copied to clipboard');
                                        }
                                      },
                                      icon: const Icon(Icons.copy, size: 15),
                                      label: const Text('Copy', style: TextStyle(fontSize: 12)),
                                    ),
                                    TextButton.icon(
                                      onPressed: () {
                                        final c = ref.read(
                                            appControllerProvider.notifier);
                                        final doc = c.createDocument(
                                          title: 'AI Draft',
                                          blocks: [
                                            DocBlock(type: DocBlockType.heading, text: 'AI Draft'),
                                            DocBlock(type: DocBlockType.paragraph, text: m.text),
                                          ],
                                        );
                                        context.push('/document/${doc.id}');
                                      },
                                      icon: const Icon(Icons.note_add_outlined, size: 15),
                                      label: const Text('Insert into document', style: TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('ORBITAL AI is drafting…'),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Ask ORBITAL AI… e.g. "Draft a professional email"',
                      ),
                      onSubmitted: _send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : () => _send(_input.text),
                    child: const Icon(Icons.send),
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
