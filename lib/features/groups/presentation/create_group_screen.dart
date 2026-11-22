import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/group.dart';
import '../models/member.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  GroupFrequency _frequency = GroupFrequency.weekly;
  DistributionMode _distributionMode = DistributionMode.tirage;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _errorMessage = 'Vous devez être connecté pour continuer.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final now = DateTime.now();
    final groupReference = FirebaseFirestore.instance.collection('groups').doc();
    final group = Group(
      id: groupReference.id,
      name: _nameController.text.trim(),
      amount: int.parse(_amountController.text.trim()),
      currency: 'XOF',
      frequency: _frequency,
      distributionMode: _distributionMode,
      ownerId: user.uid,
      memberIds: [user.uid],
      createdAt: now,
    );
    try {
      final userProfile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final profileName = userProfile.data()?['displayName'];
      final normalizedName = profileName is String ? profileName.trim() : '';
      final displayName = normalizedName.isEmpty
          ? 'Membre'
          : normalizedName.length > 40
              ? normalizedName.substring(0, 40)
              : normalizedName;
      final member = Member(
        id: user.uid,
        userId: user.uid,
        groupId: groupReference.id,
        joinedAt: now,
        displayName: displayName,
      );
      final batch = FirebaseFirestore.instance.batch();
      batch.set(groupReference, group.toMap());
      batch.set(
        groupReference.collection('members').doc(user.uid),
        member.toMap(),
      );
      await batch.commit();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Section créée avec succès.')),
      );
    } on FirebaseException {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Impossible de créer la section. Réessayez.';
      });
    }
  }

  String _frequencyLabel(GroupFrequency frequency) => switch (frequency) {
        GroupFrequency.daily => 'Quotidienne',
        GroupFrequency.weekly => 'Hebdomadaire',
        GroupFrequency.monthly => 'Mensuelle',
      };

  String _distributionLabel(DistributionMode mode) => switch (mode) {
        DistributionMode.tirage => 'Tirage au sort',
        DistributionMode.ordre => 'Ordre fixé',
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Créer une section')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la section',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Le nom de la section est obligatoire.'
                      : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Montant de la cotisation',
                    suffixText: 'FCFA',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    final amount = int.tryParse(value?.trim() ?? '');
                    return amount == null || amount <= 0
                        ? 'Saisissez un montant entier supérieur à 0.'
                        : null;
                  },
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<GroupFrequency>(
                  value: _frequency,
                  decoration: const InputDecoration(
                    labelText: 'Fréquence',
                    border: OutlineInputBorder(),
                  ),
                  items: GroupFrequency.values
                      .map(
                        (frequency) => DropdownMenuItem(
                          value: frequency,
                          child: Text(_frequencyLabel(frequency)),
                        ),
                      )
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (frequency) {
                          if (frequency != null) {
                            setState(() => _frequency = frequency);
                          }
                        },
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<DistributionMode>(
                  value: _distributionMode,
                  decoration: const InputDecoration(
                    labelText: 'Distribution des tours',
                    border: OutlineInputBorder(),
                  ),
                  items: DistributionMode.values
                      .map(
                        (mode) => DropdownMenuItem(
                          value: mode,
                          child: Text(_distributionLabel(mode)),
                        ),
                      )
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (mode) {
                          if (mode != null) {
                            setState(() => _distributionMode = mode);
                          }
                        },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _createGroup,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: const Text('Créer la section'),
                ),
              ],
            ),
          ),
        ),
      );
}