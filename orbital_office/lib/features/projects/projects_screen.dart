import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/invoice_calculator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/formatters.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../data/repositories/app_controller.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 3, vsync: this, initialIndex: widget.initialTab);

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects & Tasks'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.folder_open_outlined), text: 'Projects'),
            Tab(icon: Icon(Icons.view_kanban_outlined), text: 'Kanban'),
            Tab(icon: Icon(Icons.calendar_month_outlined), text: 'Calendar'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (_tabs.index == 0) {
            final name = await showTextInputDialog(context,
                title: 'New project', label: 'Project name');
            if (name != null && name.isNotEmpty) {
              ref.read(appControllerProvider.notifier).createProject(name);
            }
          } else {
            final name = await showTextInputDialog(context,
                title: 'New task', label: 'Task title');
            if (name != null && name.isNotEmpty) {
              ref.read(appControllerProvider.notifier).createTask(name);
            }
          }
        },
        icon: const Icon(Icons.add),
        label: Text(_tabs.index == 0 ? 'New Project' : 'New Task'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ProjectsTab(state: state),
          _KanbanTab(state: state),
          _CalendarTab(state: state),
        ],
      ),
    );
  }
}

class _ProjectsTab extends ConsumerWidget {
  const _ProjectsTab({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.projects.isEmpty) {
      return const EmptyState(
        icon: Icons.folder_open_outlined,
        title: 'No projects yet',
        message: 'Create a project, add tasks and track progress to completion.',
      );
    }
    final controller = ref.read(appControllerProvider.notifier);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.projects.length,
      itemBuilder: (context, i) {
        final p = state.projects[i];
        final progress = controller.projectProgress(p.id);
        final projectTasks =
            state.tasks.where((t) => t.projectId == p.id).toList();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(p.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_task),
                      tooltip: 'Add task',
                      onPressed: () async {
                        final name = await showTextInputDialog(context,
                            title: 'Task for ${p.title}', label: 'Task title');
                        if (name != null && name.isNotEmpty) {
                          controller.createTask(name, projectId: p.id);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => controller.deleteProject(p.id),
                    ),
                  ],
                ),
                if (p.description.isNotEmpty) Text(p.description),
                if (p.deadline != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Deadline: ${Formatters.date(p.deadline!)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.mutedText)),
                  ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.lightGrey,
                  color: AppColors.deepGreen,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 6),
                Text('${(progress * 100).round()}% complete • ${projectTasks.length} tasks',
                    style: const TextStyle(fontSize: 12)),
                for (final t in projectTasks)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: t.status == TaskStatus.completed,
                    title: Text(t.title,
                        style: TextStyle(
                            decoration: t.status == TaskStatus.completed
                                ? TextDecoration.lineThrough
                                : null)),
                    subtitle: Text('${t.priority.label} • ${t.status.label}'),
                    onChanged: (done) {
                      t.status =
                          done == true ? TaskStatus.completed : TaskStatus.toDo;
                      controller.saveTask(t);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _KanbanTab extends ConsumerWidget {
  const _KanbanTab({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appControllerProvider.notifier);
    if (state.tasks.isEmpty) {
      return const EmptyState(
        icon: Icons.view_kanban_outlined,
        title: 'No tasks yet',
        message: 'Tasks you create appear here in a Kanban board.',
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final status in TaskStatus.values)
            SizedBox(
              width: 270,
              child: Card(
                color: AppColors.lightGrey,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(status.label,
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(width: 8),
                          StatusChip(
                              label:
                                  '${state.tasks.where((t) => t.status == status).length}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final t in state.tasks.where((t) => t.status == status))
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.title,
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  children: [
                                    StatusChip(
                                      label: t.priority.label,
                                      color: t.priority == TaskPriority.high
                                          ? Colors.red.shade700
                                          : t.priority == TaskPriority.medium
                                              ? Colors.orange.shade800
                                              : Colors.grey.shade700,
                                    ),
                                    if (t.dueDate != null)
                                      StatusChip(
                                          label: Formatters.date(t.dueDate!),
                                          color: Colors.blueGrey),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  children: [
                                    for (final s in TaskStatus.values)
                                      if (s != status)
                                        TextButton(
                                          onPressed: () {
                                            t.status = s;
                                            controller.saveTask(t);
                                          },
                                          child: Text('Move to ${s.label}',
                                              style: const TextStyle(fontSize: 11)),
                                        ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18),
                                      onPressed: () => controller.deleteTask(t.id),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CalendarTab extends StatelessWidget {
  const _CalendarTab({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final dated = state.tasks.where((t) => t.dueDate != null).toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    final byDay = <String, List<TaskItem>>{};
    for (final t in dated) {
      final key = Formatters.date(t.dueDate!);
      byDay.putIfAbsent(key, () => []).add(t);
    }
    if (byDay.isEmpty) {
      return const EmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'Nothing scheduled',
        message: 'Tasks with due dates and project deadlines will appear here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in byDay.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(entry.key,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          for (final t in entry.value)
            Card(
              child: ListTile(
                leading: Icon(
                  t.status == TaskStatus.completed
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: AppColors.deepGreen,
                ),
                title: Text(t.title),
                subtitle: Text('${t.priority.label} priority • ${t.status.label}'),
              ),
            ),
        ],
        if (state.projects.any((p) => p.deadline != null)) ...[
          const Padding(
            padding: EdgeInsets.only(top: 16, bottom: 6),
            child: Text('Project deadlines',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          for (final p in state.projects.where((p) => p.deadline != null))
            Card(
              child: ListTile(
                leading: const Icon(Icons.flag_outlined, color: AppColors.premiumGold),
                title: Text(p.title),
                subtitle: Text('Deadline ${Formatters.date(p.deadline!)}'),
              ),
            ),
        ],
      ],
    );
  }
}
