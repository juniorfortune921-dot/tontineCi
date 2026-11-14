import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_screen.dart';
import '../../features/contributions/presentation/contributions_screen.dart';
import '../../features/groups/presentation/groups_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/rounds/presentation/rounds_screen.dart';
import '../widgets/app_shell.dart';

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier() {
    _subscription = FirebaseAuth.instance
        .authStateChanges()
        .listen((_) => notifyListeners());
  }

  late final StreamSubscription<User?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final _authRefreshNotifier = _AuthRefreshNotifier();

final appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: _authRefreshNotifier,
  redirect: (context, state) {
    final isSigningIn = state.matchedLocation == '/auth';
    if (FirebaseAuth.instance.currentUser == null && !isSigningIn) {
      return '/auth';
    }
    return null;
  },
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/groups',
          builder: (context, state) => const GroupsScreen(),
        ),
        GoRoute(
          path: '/rounds',
          builder: (context, state) => const RoundsScreen(),
        ),
        GoRoute(
          path: '/contributions',
          builder: (context, state) => const ContributionsScreen(),
        ),
      ],
    ),
    GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
  ],
);