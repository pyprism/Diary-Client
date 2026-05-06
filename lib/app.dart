import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'core/constants/app_theme.dart';
import 'features/diary/presentation/diary_providers.dart';
import 'features/tags/presentation/tags_providers.dart';
import 'routing/app_router.dart';

class DiaryApp extends ConsumerStatefulWidget {
  const DiaryApp({super.key});

  @override
  ConsumerState<DiaryApp> createState() => _DiaryAppState();
}

class _DiaryAppState extends ConsumerState<DiaryApp> {
  Timer? _pendingSyncTimer;
  bool _isSyncingPending = false;

  @override
  void initState() {
    super.initState();
    unawaited(_runPendingSync());
    _pendingSyncTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_runPendingSync()),
    );
  }

  Future<void> _runPendingSync() async {
    if (!mounted || _isSyncingPending) return;
    _isSyncingPending = true;
    try {
      await ref.read(tagRepositoryProvider).syncPendingTags();
      await ref.read(diaryRepositoryProvider).syncPendingDiaries();
    } finally {
      _isSyncingPending = false;
    }
  }

  @override
  void dispose() {
    _pendingSyncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Diary',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
      ],
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
