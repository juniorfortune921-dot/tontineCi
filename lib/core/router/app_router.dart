import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_screen.dart';
import '../../features/contributions/presentation/contributions_screen.dart';
import '../../features/groups/presentation/groups_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/rounds/presentation/rounds_screen.dart';
import '../widgets/app_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/',
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