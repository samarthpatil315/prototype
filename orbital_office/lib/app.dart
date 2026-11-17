import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/app_controller.dart';

class OrbitalApp extends ConsumerStatefulWidget {
  const OrbitalApp({super.key});

  @override
  ConsumerState<OrbitalApp> createState() => _OrbitalAppState();
}

class _OrbitalAppState extends ConsumerState<OrbitalApp> {
  late final GoRouter _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(
      appControllerProvider.select((s) => s.themeMode),
    );
    return MaterialApp.router(
      title: 'ORBITAL OFFICE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
