import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/presentation/auth_providers.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/diary/presentation/diary_list_screen.dart';
import '../features/diary/presentation/diary_detail_screen.dart';
import '../features/diary/presentation/diary_editor_screen.dart';
import '../features/tags/presentation/tags_screen.dart';
import '../features/share/presentation/public_share_screen.dart';
import '../features/share/presentation/share_links_screen.dart';
import 'adaptive_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = _GoRouterRefreshNotifier(ref);
  ref.onDispose(authRefresh.dispose);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final authAsync = ref.read(authNotifierProvider);
      if (authAsync.isLoading || !authAsync.hasValue) return null;

      final isLoggedIn = authAsync.value == true;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final isPublicShare = state.matchedLocation.startsWith('/share/');

      if (isPublicShare) return null;
      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),

      // Public share (no auth)
      GoRoute(
        path: '/share/:token',
        builder: (_, state) =>
            PublicShareScreen(token: state.pathParameters['token']!),
      ),

      // Shell with navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppAdaptiveScaffold(
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/diary',
            builder: (_, __) => const DiaryListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, __) => const DiaryEditorScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) {
                  final localId =
                      int.tryParse(state.pathParameters['id'] ?? '');
                  return localId == null
                      ? const _NotFoundScreen()
                      : DiaryDetailScreen(localId: localId);
                },
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) {
                      final localId =
                          int.tryParse(state.pathParameters['id'] ?? '');
                      return localId == null
                          ? const _NotFoundScreen()
                          : DiaryEditorScreen(localId: localId);
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/tags',
            builder: (_, __) => const TagsScreen(),
            routes: [
              GoRoute(
                path: ':id/entries',
                builder: (_, state) {
                  final localId =
                      int.tryParse(state.pathParameters['id'] ?? '');
                  return localId == null
                      ? const _NotFoundScreen()
                      : TagEntriesScreen(tagLocalId: localId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/shares',
            builder: (_, __) => const AllShareLinksScreen(),
          ),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

class _GoRouterRefreshNotifier extends ChangeNotifier {
  _GoRouterRefreshNotifier(Ref ref) {
    ref.listen<AsyncValue<bool>>(
      authNotifierProvider,
      (_, __) => notifyListeners(),
    );
  }
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const Center(child: Text('Page not found')),
    );
  }
}
