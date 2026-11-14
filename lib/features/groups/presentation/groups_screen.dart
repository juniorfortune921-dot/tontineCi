import 'package:flutter/material.dart';

import 'create_group_screen.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  Future<void> _openCreateGroup(BuildContext context) => Navigator.of(context)
      .push<void>(
        MaterialPageRoute<void>(
          builder: (context) => const CreateGroupScreen(),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: const Center(child: Text('Aucune section pour le moment.')),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Créer une section',
          onPressed: () => _openCreateGroup(context),
          child: const Icon(Icons.add),
        ),
      );
}