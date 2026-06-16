import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moerderspiel/presentation/providers/auth_provider.dart';
import 'package:moerderspiel/presentation/screens/auth/login_screen.dart';
import 'package:moerderspiel/presentation/screens/auth/register_screen.dart';
import 'package:moerderspiel/presentation/screens/game/admin_screen.dart';
import 'package:moerderspiel/presentation/screens/game/create_game_screen.dart';
import 'package:moerderspiel/presentation/screens/game/game_over_screen.dart';
import 'package:moerderspiel/presentation/screens/game/game_screen.dart';
import 'package:moerderspiel/presentation/screens/game/join_game_screen.dart';
import 'package:moerderspiel/presentation/screens/game/kill_history_screen.dart';
import 'package:moerderspiel/presentation/screens/game/lobby_screen.dart';
import 'package:moerderspiel/presentation/screens/game/report_kill_screen.dart';
import 'package:moerderspiel/presentation/screens/game/target_screen.dart';
import 'package:moerderspiel/presentation/screens/game/tasks_screen.dart';
import 'package:moerderspiel/presentation/screens/home/home_screen.dart';
import 'package:moerderspiel/presentation/screens/profile/profile_screen.dart';
import 'package:moerderspiel/presentation/screens/splash_screen.dart';

final _splashDelayProvider = FutureProvider<void>((ref) async {
  await Future.delayed(const Duration(seconds: 2));
});

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(_splashDelayProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;

  bool get isLoading =>
      _ref.read(authStateProvider).isLoading ||
      _ref.read(_splashDelayProvider).isLoading;

  bool get isLoggedIn =>
      _ref.read(authStateProvider).value?.session != null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isSplash = loc == '/splash';
      final isAuthRoute = loc.startsWith('/auth');

      if (notifier.isLoading) return isSplash ? null : '/splash';

      final isLoggedIn = notifier.isLoggedIn;

      if (isSplash) return isLoggedIn ? '/home' : '/auth/login';
      if (!isLoggedIn && !isAuthRoute) return '/auth/login';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/game/create', builder: (_, __) => const CreateGameScreen()),
      GoRoute(path: '/game/join', builder: (_, state) {
        final code = state.uri.queryParameters['code'];
        return JoinGameScreen(initialCode: code);
      }),
      GoRoute(
        path: '/game/:gameId/lobby',
        builder: (_, state) => LobbyScreen(gameId: state.pathParameters['gameId']!),
      ),
      GoRoute(
        path: '/game/:gameId',
        builder: (_, state) => GameScreen(gameId: state.pathParameters['gameId']!),
        routes: [
          GoRoute(
            path: 'target',
            builder: (_, state) => TargetScreen(gameId: state.pathParameters['gameId']!),
          ),
          GoRoute(
            path: 'tasks',
            builder: (_, state) => TasksScreen(gameId: state.pathParameters['gameId']!),
          ),
          GoRoute(
            path: 'report-kill',
            builder: (_, state) => ReportKillScreen(gameId: state.pathParameters['gameId']!),
          ),
          GoRoute(
            path: 'history',
            builder: (_, state) => KillHistoryScreen(gameId: state.pathParameters['gameId']!),
          ),
          GoRoute(
            path: 'over',
            builder: (_, state) => GameOverScreen(gameId: state.pathParameters['gameId']!),
          ),
          GoRoute(
            path: 'admin',
            builder: (_, state) => AdminScreen(gameId: state.pathParameters['gameId']!),
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Seite nicht gefunden: ${state.error}')),
    ),
  );
});
