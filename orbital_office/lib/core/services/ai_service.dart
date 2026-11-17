import 'supabase_service.dart';

/// AI Office Assistant.
///
/// Online path: prompts are sent to the `ai_assistant` Supabase Edge
/// Function, which holds the provider API key server-side. The key is never
/// present in Flutter source or in the shipped app.
///
/// Offline/demo path: a transparent, template-based draft generator. Its
/// output is always labelled as an unverified demo draft — the assistant
/// never claims generated content has been verified.
class AiService {
  const AiService._();

  static const String demoDisclaimer =
      '\n\n— Demo AI (offline, template-based). This draft has NOT been '
      'verified. Review and edit before sending or publishing.';

  static Future<String> generate(String prompt) async {
    final remote = await SupabaseService.instance.invokeAiAssistant(prompt);
    if (remote != null && remote.trim().isNotEmpty) return remote;
    return demoGenerate(prompt);
  }

  static const List<String> suggestedPrompts = [
    'Write a business letter requesting a quotation',
    'Draft a professional follow-up email to a customer',
    'Create a business proposal outline for a new client',
    'Generate a task list for launching a product',
    'Write invoice descriptions for design services',
    'Create meeting notes template for a client call',
    'Summarize: paste your text after the word Summarize',
  ];

  /// Deterministic offline generator used in demo mode and as a fallback.
  /// Pure and unit-testable.
  static String demoGenerate(String prompt) {
    final p = prompt.trim();
    final lower = p.toLowerCase();

    if (lower.startsWith('summarize') || lower.startsWith('summarise')) {
      var text = p.substring(p.indexOf(':') + 1).trim();
      if (text.isEmpty || text == p) {
        text = p;
      }
      final sentences =
          text.split(RegExp(r'(?<=[.!?])\s+')).where((s) => s.trim().isNotEmpty).toList();
      final points = sentences.take(4).map((s) => '• ${s.trim()}').join('\n');
      return 'Summary (key points):\n$points$demoDisclaimer';
    }

    if (lower.contains('task list') || lower.contains('tasks for')) {
      final topic = _after(p, ['tasks for', 'task list for', 'task list']);
      return 'Task list${topic.isEmpty ? '' : ' — $topic'}:\n'
          '1. Define the goal and deadline\n'
          '2. List materials, people and budget needed\n'
          '3. Assign an owner to each task\n'
          '4. Set milestones and review dates\n'
          '5. Track progress in Projects → Kanban\n'
          '6. Review results and note learnings$demoDisclaimer';
    }

    if (lower.contains('invoice description')) {
      return 'Suggested invoice descriptions:\n'
          '• Creative design services — concept, design and final artwork delivery\n'
          '• Brand identity package — logo suite, colour palette and usage guide\n'
          '• Social media creative set — platform-ready posts and stories\n'
          '• Website design & development — responsive pages with CMS setup\n'
          '• Product promotional video — script, edit and final export$demoDisclaimer';
    }

    if (lower.contains('email')) {
      return 'Subject: Follow-up on our recent conversation\n\n'
          'Dear Customer,\n\n'
          'Thank you for your time and interest in our services. '
          'As discussed, we are sharing the next steps and would be glad to '
          'answer any questions you may have.\n\n'
          'Please let us know a convenient time to proceed.\n\n'
          'Warm regards,\nYour Name\nORBITAL OFFICE$demoDisclaimer';
    }

    if (lower.contains('letter')) {
      return 'To,\nThe Manager,\n[Company Name]\n\n'
          'Subject: Request for Quotation\n\n'
          'Respected Sir/Madam,\n\n'
          'We are writing to request a detailed quotation for the products/services '
          'mentioned in our requirement. Kindly share your best pricing, delivery '
          'timeline and payment terms at the earliest.\n\n'
          'Looking forward to your response.\n\n'
          'Yours faithfully,\n[Your Name]\n[Your Business]$demoDisclaimer';
    }

    if (lower.contains('proposal')) {
      return 'Business Proposal — Outline\n\n'
          '1. Introduction: who we are and what we do\n'
          '2. Understanding of your requirement\n'
          '3. Proposed solution and deliverables\n'
          '4. Timeline and milestones\n'
          '5. Investment and payment terms\n'
          '6. Why ORBITAL — our creative process\n'
          '7. Next steps$demoDisclaimer';
    }

    if (lower.contains('meeting')) {
      return 'Meeting Notes\n\n'
          'Date: \nAttendees: \n\n'
          'Agenda:\n• \n\nDecisions taken:\n• \n\nAction items:\n'
          '• Task — Owner — Due date\n\nNext meeting:$demoDisclaimer';
    }

    if (lower.contains('report')) {
      return 'Business Report — Structure\n\n'
          'Executive Summary\nKey Highlights\n• \n\nPerformance Overview\n• \n\n'
          'Challenges\n• \n\nRecommendations\n• \n\nConclusion$demoDisclaimer';
    }

    return 'Here is a draft based on your prompt:\n\n'
        '"$p"\n\n'
        'Suggested structure:\n• Start with a clear headline\n'
        '• Add 3–4 short supporting points\n'
        '• End with a specific call to action$demoDisclaimer';
  }

  static String _after(String text, List<String> markers) {
    final lower = text.toLowerCase();
    for (final m in markers) {
      final i = lower.indexOf(m);
      if (i >= 0) {
        var rest = text.substring(i + m.length).trim();
        if (rest.startsWith(':')) rest = rest.substring(1).trim();
        return rest;
      }
    }
    return '';
  }
}
