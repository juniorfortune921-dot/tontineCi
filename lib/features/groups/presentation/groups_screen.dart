import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/group.dart';
import 'create_group_screen.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  Future<void> _openCreateGroup(BuildContext context) => Navigator.of(context)
      .push<void>(
        MaterialPageRoute<void>(
          builder: (context) => const CreateGroupScreen(),
        ),
      );

  Future<void> _openGroupDetails(BuildContext context, Group group) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => GroupDetailsScreen(group: group),
        ),
      );

  String _frequencyLabel(GroupFrequency frequency) => switch (frequency) {
        GroupFrequency.daily => 'Quotidienne',
        GroupFrequency.weekly => 'Hebdomadaire',
        GroupFrequency.monthly => 'Mensuelle',
      };

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      body: uid == null
          ? const Center(child: Text('Connectez-vous pour voir vos groupes.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('groups')
                  .where('memberIds', arrayContains: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Impossible de charger vos groupes. Vérifiez votre connexion puis réessayez.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final groups = snapshot.data!.docs
                    .map((document) => Group.fromMap(document.id, document.data()))
                    .toList()
                  ..sort((first, second) =>
                      second.createdAt.compareTo(first.createdAt));

                if (groups.isEmpty) {
                  return const Center(
                    child: Text('Aucune section pour le moment.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: groups.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final isOwner = group.ownerId == uid;
                    return ListTile(
                      title: Text(group.name),
                      subtitle: Text(
                        '${group.amount} FCFA · ${_frequencyLabel(group.frequency)}\n'
                        '${group.memberIds.length} membres',
                      ),
                      isThreeLine: true,
                      trailing: isOwner
                          ? const Chip(label: Text('Propriétaire'))
                          : const Icon(Icons.chevron_right),
                      onTap: () => _openGroupDetails(context, group),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Créer une section',
        onPressed: () => _openCreateGroup(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class GroupDetailsScreen extends StatelessWidget {
  const GroupDetailsScreen({required this.group, super.key});

  final Group group;

  String get _frequencyLabel => switch (group.frequency) {
        GroupFrequency.daily => 'Quotidienne',
        GroupFrequency.weekly => 'Hebdomadaire',
        GroupFrequency.monthly => 'Mensuelle',
      };

  String get _distributionLabel => switch (group.distributionMode) {
        DistributionMode.tirage => 'Tirage au sort',
        DistributionMode.ordre => 'Ordre fixé',
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(group.name)),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _GroupDetailRow(label: 'Nom', value: group.name),
            _GroupDetailRow(
              label: 'Montant',
              value: '${group.amount} FCFA',
            ),
            _GroupDetailRow(label: 'Fréquence', value: _frequencyLabel),
            _GroupDetailRow(
              label: 'Mode de distribution',
              value: _distributionLabel,
            ),
            _GroupDetailRow(
              label: 'Membres',
              value: '${group.memberIds.length}',
            ),
          ],
        ),
      );
}

class _GroupDetailRow extends StatelessWidget {
  const _GroupDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      );
}