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
import 'package:moerderspiel/presentation/screens/codename/codename_lobby_screen.dart';
import 'package:moerderspiel/presentation/screens/codename/codename_game_screen.dart';
import 'package:moerderspiel/presentation/screens/game/rps_tournament_screen.dart';
import 'package:moerderspiel/presentation/screens/game/tasks_screen.dart';
import 'package:moerderspiel/presentation/screens/home/home_screen.dart';
import 'package:moerderspiel/presentation/screens/kniffel/kniffel_leaderboard_screen.dart';
import 'package:moerderspiel/presentation/screens/kniffel/kniffel_screen.dart';
import 'package:moerderspiel/presentation/screens/lootbox/lootbox_screen.dart';
import 'package:moerderspiel/presentation/screens/profile/profile_screen.dart';
import 'package:moerderspiel/presentation/screens/splash_screen.dart';

final _splashDelayProvider = FutureProvider<void>((ref) async {
  await Future.delayed(const Duration(seconds: 2));
});

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (previous, next) {
      // Only re-evaluate router when login state actually changes, not on token refresh etc.
      final wasLoggedIn = previous?.value?.session != null;
      final nowLoggedIn = next.value?.session != null;
      final wasLoading = previous?.isLoading ?? true;
      final nowLoading = next.isLoading;
      if (wasLoggedIn != nowLoggedIn || wasLoading != nowLoading) {
        notifyListeners();
      }
    });
    _ref.listen(_splashDelayProvider, (_, next) {
      if (next.hasValue) notifyListeners();
    });
  }
  final Ref _ref;

  bool get isLoading =>
      _ref.read(authStateProvider).isLoading ||
      _ref.read(_splashDelayProvider).isLoading;

  bool get isLoggedIn =>
      _ref.read(authStateProvider).value?.session != null;
}

Page<void> _page(Widget child, GoRouterState state) => NoTransitionPage(
      key: state.pageKey,
      child: child,
    );

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
      GoRoute(path: '/splash',         pageBuilder: (_, s) => _page(const SplashScreen(), s)),
      GoRoute(path: '/auth/login',     pageBuilder: (_, s) => _page(const LoginScreen(), s)),
      GoRoute(path: '/auth/register',  pageBuilder: (_, s) => _page(const RegisterScreen(), s)),
      GoRoute(path: '/home',           pageBuilder: (_, s) => _page(const HomeScreen(), s)),
      GoRoute(path: '/profile',        pageBuilder: (_, s) => _page(const ProfileScreen(), s)),
      GoRoute(path: '/lootbox',        pageBuilder: (_, s) => _page(const LootboxScreen(), s)),
      GoRoute(path: '/kniffel',        pageBuilder: (_, s) => _page(const KniffelScreen(), s)),
      GoRoute(path: '/kniffel/leaderboard', pageBuilder: (_, s) => _page(const KniffelLeaderboardScreen(), s)),
      GoRoute(path: '/rps-tournament',      pageBuilder: (_, s) => _page(const RpsTournamentScreen(), s)),
      GoRoute(
        path: '/codename/:sessionId/lobby',
        pageBuilder: (_, s) => _page(CodenameLobbyScreen(sessionId: s.pathParameters['sessionId']!), s),
      ),
      GoRoute(
        path: '/codename/:sessionId',
        pageBuilder: (_, s) => _page(CodenameGameScreen(sessionId: s.pathParameters['sessionId']!), s),
      ),
      GoRoute(path: '/game/create',    pageBuilder: (_, s) => _page(const CreateGameScreen(), s)),
      GoRoute(
        path: '/game/join',
        pageBuilder: (_, s) => _page(JoinGameScreen(initialCode: s.uri.queryParameters['code']), s),
      ),
      GoRoute(
        path: '/game/:gameId/lobby',
        pageBuilder: (_, s) => _page(LobbyScreen(gameId: s.pathParameters['gameId']!), s),
      ),
      GoRoute(
        path: '/game/:gameId',
        pageBuilder: (_, s) => _page(GameScreen(gameId: s.pathParameters['gameId']!), s),
        routes: [
          GoRoute(path: 'target',      pageBuilder: (_, s) => _page(TargetScreen(gameId: s.pathParameters['gameId']!), s)),
          GoRoute(path: 'tasks',       pageBuilder: (_, s) => _page(TasksScreen(gameId: s.pathParameters['gameId']!), s)),
          GoRoute(path: 'report-kill', pageBuilder: (_, s) => _page(ReportKillScreen(gameId: s.pathParameters['gameId']!), s)),
          GoRoute(path: 'history',     pageBuilder: (_, s) => _page(KillHistoryScreen(gameId: s.pathParameters['gameId']!), s)),
          GoRoute(path: 'over',           pageBuilder: (_, s) => _page(GameOverScreen(gameId: s.pathParameters['gameId']!), s)),
          GoRoute(path: 'admin',          pageBuilder: (_, s) => _page(AdminScreen(gameId: s.pathParameters['gameId']!), s)),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Seite nicht gefunden: ${state.error}')),
    ),
  );
});
