import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  static const _destinations = [
    (label: 'Accueil', path: '/', icon: Icons.home_outlined),
    (label: 'Groupes', path: '/groups', icon: Icons.groups_outlined),
    (label: 'Tours', path: '/rounds', icon: Icons.autorenew),
    (
      label: 'Cotisations',
      path: '/contributions',
      icon: Icons.payments_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = _destinations.indexWhere(
      (destination) => destination.path == location,
    );
    final index = selectedIndex < 0 ? 0 : selectedIndex;

    return Scaffold(
      appBar: AppBar(
        title: Text(_destinations[index].label),
        actions: [
          IconButton(
            tooltip: 'Compte',
            onPressed: () => context.go('/auth'),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (destinationIndex) {
          context.go(_destinations[destinationIndex].path);
        },
        destinations: [
          for (final destination in _destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}