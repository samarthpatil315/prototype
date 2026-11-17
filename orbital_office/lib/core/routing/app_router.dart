import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/invoice_calculator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../data/repositories/app_controller.dart';
import '../../features/ai_assistant/ai_assistant_screen.dart';
import '../../features/authentication/auth_screens.dart';
import '../../features/crm/customers_screen.dart';
import '../../features/dashboard/home_screen.dart';
import '../../features/documents/documents_screen.dart';
import '../../features/file_manager/files_screen.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/invoices/invoices_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/presentations/presentations_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/projects/projects_screen.dart';
import '../../features/spreadsheets/spreadsheets_screen.dart';
import '../../features/templates/templates_screen.dart';
import '../../features/workspace/workspace_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot', builder: (_, __) => const ForgotPasswordScreen()),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _ShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/workspace', builder: (_, __) => const WorkspaceScreen()),
          ]),
          // The Create branch is a placeholder; tapping Create opens the
          // visual creation sheet instead of navigating (see _ShellScaffold).
          StatefulShellBranch(routes: [
            GoRoute(path: '/create-menu', builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/business', builder: (_, __) => const BusinessScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),

      GoRoute(path: '/documents', builder: (_, __) => const DocumentsScreen()),
      GoRoute(
        path: '/document/:id',
        builder: (_, state) =>
            DocumentEditorScreen(documentId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/spreadsheets', builder: (_, __) => const SpreadsheetsScreen()),
      GoRoute(
        path: '/spreadsheet/:id',
        builder: (_, state) =>
            SpreadsheetEditorScreen(sheetId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/presentations', builder: (_, __) => const PresentationsScreen()),
      GoRoute(
        path: '/presentation/:id',
        builder: (_, state) =>
            PresentationEditorScreen(deckId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/invoices',
        builder: (_, __) => const BillingListScreen(kind: BillingKind.invoice),
      ),
      GoRoute(
        path: '/quotations',
        builder: (_, __) => const BillingListScreen(kind: BillingKind.quotation),
      ),
      GoRoute(
        path: '/billing/:id',
        builder: (_, state) =>
            BillingEditorScreen(billingId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/customers', builder: (_, __) => const CustomersScreen()),
      GoRoute(path: '/inventory', builder: (_, __) => const InventoryScreen()),
      GoRoute(
        path: '/projects',
        builder: (_, state) => ProjectsScreen(
          initialTab: state.uri.queryParameters['tab'] == 'tasks' ? 1 : 0,
        ),
      ),
      GoRoute(path: '/ai', builder: (_, __) => const AiAssistantScreen()),
      GoRoute(path: '/templates', builder: (_, __) => const TemplatesScreen()),
      GoRoute(path: '/files', builder: (_, __) => const FilesScreen()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/create/:type',
        builder: (_, state) =>
            CreateDispatcher(type: state.pathParameters['type']!),
      ),
    ],
  );
}

class _ShellScaffold extends ConsumerWidget {
  const _ShellScaffold({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const _labels = ['Home', 'Workspace', 'Create', 'Business', 'Profile'];
  static const _icons = [
    Icons.home_outlined,
    Icons.workspaces_outlined,
    Icons.add_circle,
    Icons.business_center_outlined,
    Icons.person_outlined,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex == 2
            ? 0
            : navigationShell.currentIndex,
        onDestinationSelected: (index) {
          if (index == 2) {
            _showCreateSheet(context);
            return;
          }
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: [
          for (var i = 0; i < _labels.length; i++)
            NavigationDestination(
              icon: Icon(
                _icons[i],
                size: i == 2 ? 30 : 24,
                color: i == 2 ? AppColors.deepGreen : null,
              ),
              label: _labels[i],
            ),
        ],
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Create something exceptional",
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              children: [
                for (final action in createActions)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.push(action.route);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.deepGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(action.icon,
                              color: AppColors.forestGreen, size: 26),
                        ),
                        const SizedBox(height: 6),
                        Text(action.label,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Handles `/create/:type`: creates the entity, then replaces itself with
/// the matching editor/list so "quick create" is one tap end-to-end.
class CreateDispatcher extends ConsumerStatefulWidget {
  const CreateDispatcher({super.key, required this.type});
  final String type;
  @override
  ConsumerState<CreateDispatcher> createState() => _CreateDispatcherState();
}

class _CreateDispatcherState extends ConsumerState<CreateDispatcher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _create());
  }

  Future<void> _create() async {
    final c = ref.read(appControllerProvider.notifier);
    switch (widget.type) {
      case 'document':
        final d = c.createDocument();
        context.pushReplacement('/document/${d.id}');
      case 'spreadsheet':
        final s = c.createSpreadsheet();
        context.pushReplacement('/spreadsheet/${s.id}');
      case 'presentation':
        final p = c.createPresentation();
        context.pushReplacement('/presentation/${p.id}');
      case 'invoice':
        final i = c.createBilling(BillingKind.invoice);
        context.pushReplacement('/billing/${i.id}');
      case 'quotation':
        final q = c.createBilling(BillingKind.quotation);
        context.pushReplacement('/billing/${q.id}');
      case 'customer':
        final name = await showTextInputDialog(context,
            title: 'Add customer', label: 'Customer name');
        if (name != null && name.isNotEmpty) c.createCustomer(name);
        if (mounted) context.pushReplacement('/customers');
      case 'project':
        final name = await showTextInputDialog(context,
            title: 'New project', label: 'Project name');
        if (name != null && name.isNotEmpty) c.createProject(name);
        if (mounted) context.pushReplacement('/projects');
      case 'task':
        final name = await showTextInputDialog(context,
            title: 'New task', label: 'Task title');
        if (name != null && name.isNotEmpty) c.createTask(name);
        if (mounted) context.pushReplacement('/projects?tab=tasks');
      case 'product':
        final name = await showTextInputDialog(context,
            title: 'Add product', label: 'Product name');
        if (name != null && name.isNotEmpty) c.createProduct(name);
        if (mounted) context.pushReplacement('/inventory');
      default:
        context.pushReplacement('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
