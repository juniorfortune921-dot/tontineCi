import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';

import '../models/round.dart';

class RoundsScreen extends StatelessWidget {
  const RoundsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Connectez-vous pour voir les tours.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .where('memberIds', arrayContains: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Impossible de charger vos sections. Réessayez.'),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final groups = snapshot.data?.docs ?? [];
        if (groups.isEmpty) {
          return const Center(child: Text('Aucun tour pour le moment'));
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: groups.length,
          separatorBuilder: (context, index) => const Divider(height: 32),
          itemBuilder: (context, index) {
            final group = groups[index];
            return _GroupRounds(
              groupId: group.id,
              groupName: group.data()['name'] as String? ?? 'Section',
              uid: uid,
            );
          },
        );
      },
    );
  }
}

class _GroupRounds extends StatelessWidget {
  const _GroupRounds({
    required this.groupId,
    required this.groupName,
    required this.uid,
  });

  final String groupId;
  final String groupName;
  final String uid;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(groupName, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('groups')
                .doc(groupId)
                .collection('rounds')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Impossible de charger les tours de cette section.'),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final rounds = snapshot.data!.docs
                  .map((document) => Round.fromMap(document.id, document.data()))
                  .toList()
                ..sort((first, second) => first.number.compareTo(second.number));

              if (rounds.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Aucun tour pour le moment'),
                );
              }

              return Column(
                children: [
                  for (final round in rounds)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Text('${round.number}')),
                      title: Text('Tour ${round.number}'),
                      subtitle: Text(
                        '${round.recipientId == uid ? 'Vous' : round.recipientName ?? 'Membre'}\n'
                        'Prévu le ${_formatDate(round.scheduledAt)}',
                      ),
                      isThreeLine: true,
                      trailing: Text(_statusLabel(round.status)),
                    ),
                ],
              );
            },
          ),
        ],
      );

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year.toString().padLeft(4, '0')}';

  String _statusLabel(RoundStatus status) => switch (status) {
        RoundStatus.scheduled => 'À venir',
        RoundStatus.drawn => 'Tiré au sort',
        RoundStatus.completed => 'Terminé',
      };
}