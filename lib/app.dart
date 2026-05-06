import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'core/constants/app_theme.dart';
import 'core/di/providers.dart';
import 'features/diary/presentation/diary_providers.dart';
import 'features/tags/presentation/tags_providers.dart';
import 'routing/app_router.dart';

class DiaryApp extends ConsumerStatefulWidget {
  const DiaryApp({super.key});

  @override
  ConsumerState<DiaryApp> createState() => _DiaryAppState();
}

class _DiaryAppState extends ConsumerState<DiaryApp>
    with WidgetsBindingObserver {
  bool _isSyncingPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_runPendingSyncIfOnline());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_runPendingSyncIfOnline());
    }
  }

  Future<void> _runPendingSyncIfOnline() async {
    if (!mounted) return;
    final isOnline = await ref.read(connectivityServiceProvider).isOnline;
    if (!isOnline) return;
    await _runPendingSync();
  }

  void _onOnlineStatusChanged(
    AsyncValue<bool>? previous,
    AsyncValue<bool> next,
  ) {
    final wasOnline = previous?.asData?.value ?? false;
    final isOnline = next.asData?.value ?? false;
    if (!wasOnline && isOnline) {
      unawaited(_runPendingSync());
    }
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(isOnlineProvider, _onOnlineStatusChanged);
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
      supportedLocales: const [Locale('en')],
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
