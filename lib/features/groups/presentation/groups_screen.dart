import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/group.dart';
import '../services/invite_service.dart';
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

  Future<void> _openJoinGroup(BuildContext context) async {
    final joined = await showDialog<bool>(
      context: context,
      builder: (context) => const _JoinGroupDialog(),
    );
    if (joined != true || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vous avez rejoint la section.')),
    );
  }

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
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            onPressed: () => _openJoinGroup(context),
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Rejoindre une section'),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            heroTag: 'createGroup',
            tooltip: 'Créer une section',
            onPressed: () => _openCreateGroup(context),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class GroupDetailsScreen extends StatefulWidget {
  const GroupDetailsScreen({required this.group, super.key});

  final Group group;

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  final _inviteService = InviteService();
  bool _isCreatingInvite = false;
  bool _isStartingTontine = false;

  String get _frequencyLabel => switch (widget.group.frequency) {
        GroupFrequency.daily => 'Quotidienne',
        GroupFrequency.weekly => 'Hebdomadaire',
        GroupFrequency.monthly => 'Mensuelle',
      };

  String get _distributionLabel => switch (widget.group.distributionMode) {
        DistributionMode.tirage => 'Tirage au sort',
        DistributionMode.ordre => 'Ordre fixé',
      };

  Future<void> _createInvite() async {
    setState(() => _isCreatingInvite = true);
    try {
      final code = await _inviteService.createInviteCode(
        groupId: widget.group.id,
      );
      if (!mounted) return;
      setState(() => _isCreatingInvite = false);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Code d’invitation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Partagez ce code pour inviter un membre.'),
              const SizedBox(height: 16),
              Center(
                child: SelectableText(
                  code,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Générer un nouveau code désactive l’ancien.'),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Code copié.')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copier'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      _showInviteError(error.message);
    } catch (_) {
      _showInviteError(null);
    }
  }

  void _showInviteError(String? message) {
    if (!mounted) return;
    setState(() => _isCreatingInvite = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message == null || message.isEmpty
              ? 'Impossible de créer un code d’invitation. Réessayez.'
              : message,
        ),
      ),
    );
  }

  Future<void> _confirmStartTontine() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lancer la tontine ?'),
        content: const Text(
          'L’ordre des tours sera déterminé côté serveur selon le mode de '
          'distribution de la section. Cette action est définitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Lancer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isStartingTontine = true);
    try {
      await _inviteService.startTontine(groupId: widget.group.id);
      if (!mounted) return;
      setState(() => _isStartingTontine = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tontine lancée')),
      );
    } on FirebaseFunctionsException catch (error) {
      _showStartTontineError(error.message);
    } catch (_) {
      _showStartTontineError(null);
    }
  }

  void _showStartTontineError(String? message) {
    if (!mounted) return;
    setState(() => _isStartingTontine = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message == null || message.isEmpty
              ? 'Impossible de lancer la tontine. Réessayez.'
              : message,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = FirebaseAuth.instance.currentUser?.uid == widget.group.ownerId;
    return Scaffold(
      appBar: AppBar(title: Text(widget.group.name)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _GroupDetailRow(label: 'Nom', value: widget.group.name),
          _GroupDetailRow(
            label: 'Montant',
            value: '${widget.group.amount} FCFA',
          ),
          _GroupDetailRow(label: 'Fréquence', value: _frequencyLabel),
          _GroupDetailRow(
            label: 'Mode de distribution',
            value: _distributionLabel,
          ),
          _GroupDetailRow(
            label: 'Membres',
            value: '${widget.group.memberIds.length}',
          ),
          if (isOwner) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _isCreatingInvite ? null : _createInvite,
              icon: _isCreatingInvite
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1),
              label: const Text('Inviter'),
            ),
          ],
          if (isOwner && widget.group.memberIds.length >= 2)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('groups')
                  .doc(widget.group.id)
                  .collection('rounds')
                  .limit(1)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Impossible de vérifier l’état des tours.'),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.data?.docs.isNotEmpty ?? false) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilledButton.icon(
                    onPressed: _isStartingTontine ? null : _confirmStartTontine,
                    icon: _isStartingTontine
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: const Text('Lancer la tontine'),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _JoinGroupDialog extends StatefulWidget {
  const _JoinGroupDialog();

  @override
  State<_JoinGroupDialog> createState() => _JoinGroupDialogState();
}

class _JoinGroupDialogState extends State<_JoinGroupDialog> {
  final _codeController = TextEditingController();
  final _inviteService = InviteService();
  bool _isJoining = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinGroup() async {
    final code = _codeController.text.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (code.length != 8) {
      setState(() => _errorMessage = 'Saisissez un code de 8 caractères.');
      return;
    }

    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });
    try {
      await _inviteService.joinGroupByCode(code: code);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseFunctionsException catch (error) {
      _setJoinError(error.message);
    } catch (_) {
      _setJoinError(null);
    }
  }

  void _setJoinError(String? message) {
    if (!mounted) return;
    setState(() {
      _isJoining = false;
        _errorMessage = message == null || message.isEmpty
          ? 'Impossible de rejoindre la section. Réessayez.'
          : message;
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Rejoindre une section'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _codeController,
              autofocus: true,
              readOnly: _isJoining,
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')),
                TextInputFormatter.withFunction((oldValue, newValue) {
                  final code = newValue.text
                      .replaceAll(RegExp(r'\s+'), '')
                      .toUpperCase();
                  final normalized = code.length > 8 ? code.substring(0, 8) : code;
                  return TextEditingValue(
                    text: normalized,
                    selection: TextSelection.collapsed(offset: normalized.length),
                  );
                }),
              ],
              decoration: const InputDecoration(
                labelText: 'Code d’invitation',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isJoining ? null : () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: _isJoining ? null : _joinGroup,
            child: _isJoining
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Rejoindre'),
          ),
        ],
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