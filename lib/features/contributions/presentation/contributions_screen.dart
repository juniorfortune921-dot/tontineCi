import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../rounds/models/round.dart';
import '../../groups/services/invite_service.dart';
import '../models/contribution.dart';

class ContributionsScreen extends StatelessWidget {
  const ContributionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(
        child: Text('Connectez-vous pour voir vos cotisations.'),
      );
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
          return const Center(child: Text('Aucun tour en cours'));
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: groups.length,
          separatorBuilder: (context, index) => const Divider(height: 32),
          itemBuilder: (context, index) {
            final group = groups[index];
            return _GroupContributions(
              groupId: group.id,
              groupName: group.data()['name'] as String? ?? 'Section',
              amount: (group.data()['amount'] as num).toInt(),
              uid: uid,
            );
          },
        );
      },
    );
  }
}

class _GroupContributions extends StatefulWidget {
  const _GroupContributions({
    required this.groupId,
    required this.groupName,
    required this.amount,
    required this.uid,
  });

  final String groupId;
  final String groupName;
  final int amount;
  final String uid;

  @override
  State<_GroupContributions> createState() => _GroupContributionsState();
}

class _GroupContributionsState extends State<_GroupContributions> {
  final _inviteService = InviteService();
  final Set<String> _writingContributionIds = {};
  bool _isDeclaring = false;
  bool _isLoadingPayeeInfo = false;
  String? _submittedRoundId;
  String? _writeError;
  String? _payeeError;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.groupName, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('groups')
                .doc(widget.groupId)
                .collection('rounds')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'Impossible de charger les tours de cette section. Réessayez.',
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final rounds = (snapshot.data?.docs ?? [])
                  .map((document) => Round.fromMap(document.id, document.data()))
                  .where((round) => round.status != RoundStatus.completed)
                  .toList()
                ..sort((first, second) => first.number.compareTo(second.number));

              if (rounds.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Aucun tour en cours'),
                );
              }

              return _buildCurrentRound(rounds.first);
            },
          ),
        ],
      );

  Widget _buildCurrentRound(Round round) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Tour ${round.number}'),
            subtitle: Text(
              '${round.recipientId == widget.uid ? 'Vous' : round.recipientName ?? 'Membre'}\n'
              'Prévu le ${_formatDate(round.scheduledAt)}\n'
              'À verser : ${widget.amount} FCFA',
            ),
            isThreeLine: true,
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('groups')
                .doc(widget.groupId)
                .collection('contributions')
                .where('roundId', isEqualTo: round.id)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'Impossible de charger les cotisations de ce tour. Réessayez.',
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final contributions = (snapshot.data?.docs ?? [])
                  .map((document) {
                    final data = document.data();
                    data['createdAt'] ??= DateTime.now();
                    return Contribution.fromMap(document.id, data);
                  })
                  .toList()
                ..sort((first, second) =>
                    first.createdAt.compareTo(second.createdAt));

              if (round.recipientId == widget.uid) {
                return _buildReceivedContributions(contributions);
              }

              final ownContribution = contributions
                  .where((contribution) => contribution.memberId == widget.uid)
                  .firstOrNull;
              if (ownContribution != null) {
                return Text(
                  switch (ownContribution.status) {
                    ContributionStatus.enAttente => 'Cotisation en attente',
                    ContributionStatus.declare => 'Déclaration envoyée',
                    ContributionStatus.confirme => 'Cotisation confirmée',
                  },
                );
              }
              if (_submittedRoundId == round.id) {
                return const Text('Déclaration envoyée');
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton(
                    onPressed: _isDeclaring ? null : () => _declare(round),
                    child: _isDeclaring
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("J'ai payé"),
                  ),
                  if (_writeError != null)
                    Text(
                      _writeError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                ],
              );
            },
          ),
          if (round.recipientId != widget.uid) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isLoadingPayeeInfo ? null : () => _showPayeeInfo(round),
              icon: _isLoadingPayeeInfo
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Voir où payer'),
            ),
            if (_payeeError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _payeeError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ],
      );

  Future<void> _showPayeeInfo(Round round) async {
    setState(() {
      _isLoadingPayeeInfo = true;
      _payeeError = null;
    });
    try {
      final payeeInfo = await _inviteService.getPayeeInfo(
        groupId: widget.groupId,
        roundId: round.id,
      );
      if (!mounted) return;
      setState(() => _isLoadingPayeeInfo = false);

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Où payer ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                payeeInfo['recipientName']!,
                style: Theme.of(dialogContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(_paymentMethodLabel(payeeInfo['paymentMethod']!)),
              const SizedBox(height: 12),
              SelectableText(
                payeeInfo['paymentNumber']!,
                style: Theme.of(dialogContext).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text('Montant : ${widget.amount} FCFA'),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: payeeInfo['paymentNumber']!),
                );
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Numéro copié')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copier le numéro'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      _setPayeeError(error.message);
    } catch (_) {
      _setPayeeError(null);
    }
  }

  void _setPayeeError(String? message) {
    if (!mounted) return;
    setState(() {
      _isLoadingPayeeInfo = false;
      _payeeError = message == null || message.isEmpty
          ? 'Impossible de charger les informations de paiement. Réessayez.'
          : message;
    });
  }

  String _paymentMethodLabel(String method) => switch (method) {
        'wave' => 'Wave',
        'orange' => 'Orange Money',
        'mtn' => 'MTN MoMo',
        'moov' => 'Moov Money',
        _ => 'Moyen de paiement inconnu',
      };

  Widget _buildReceivedContributions(List<Contribution> contributions) {
    if (contributions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Aucune cotisation déclarée pour ce tour.'),
      );
    }

    return Column(
      children: [
        for (final contribution in contributions)
          _ContributionRow(
            groupId: widget.groupId,
            contribution: contribution,
            canConfirm: contribution.status == ContributionStatus.declare &&
                contribution.memberId != widget.uid,
            isWriting: _writingContributionIds.contains(contribution.id),
            onConfirm: () => _confirm(contribution),
          ),
        if (_writeError != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _writeError!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }

  Future<void> _declare(Round round) async {
    setState(() {
      _isDeclaring = true;
      _writeError = null;
    });

    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('contributions')
          .doc()
          .set({
        'groupId': widget.groupId,
        'roundId': round.id,
        'memberId': widget.uid,
        'amount': widget.amount,
        'status': ContributionStatus.declare.value,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() => _submittedRoundId = round.id);
    } on FirebaseException {
      if (!mounted) return;
      setState(() => _writeError = 'Impossible de déclarer le paiement. Réessayez.');
    } finally {
      if (mounted) setState(() => _isDeclaring = false);
    }
  }

  Future<void> _confirm(Contribution contribution) async {
    setState(() {
      _writingContributionIds.add(contribution.id);
      _writeError = null;
    });

    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('contributions')
          .doc(contribution.id)
          .update({'status': ContributionStatus.confirme.value});
    } on FirebaseException {
      if (!mounted) return;
      setState(() => _writeError = 'Impossible de confirmer la réception. Réessayez.');
    } finally {
      if (mounted) {
        setState(() => _writingContributionIds.remove(contribution.id));
      }
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year.toString().padLeft(4, '0')}';
}

class _ContributionRow extends StatelessWidget {
  const _ContributionRow({
    required this.groupId,
    required this.contribution,
    required this.canConfirm,
    required this.isWriting,
    required this.onConfirm,
  });

  final String groupId;
  final Contribution contribution;
  final bool canConfirm;
  final bool isWriting;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .doc(contribution.memberId)
            .snapshots(),
        builder: (context, snapshot) {
          final memberData = snapshot.data?.data();
          final name = memberData?['displayName'] as String? ??
              memberData?['name'] as String? ??
              'Membre';

          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(name),
            subtitle: Text('${contribution.amount} FCFA'),
            trailing: contribution.status == ContributionStatus.confirme
                ? const Text('Confirmée')
                : canConfirm
                    ? TextButton(
                        onPressed: isWriting ? null : onConfirm,
                        child: isWriting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Confirmer la réception'),
                      )
                    : Text(_statusLabel(contribution.status)),
          );
        },
      );

  String _statusLabel(ContributionStatus status) => switch (status) {
        ContributionStatus.enAttente => 'En attente',
        ContributionStatus.declare => 'Déclarée',
        ContributionStatus.confirme => 'Confirmée',
      };
}