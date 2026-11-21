import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/auth_config.dart';
import '../models/user.dart' show PaymentMethod;

enum _AuthStage { loading, phone, code, profile, account }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _paymentNumberController = TextEditingController();
  PaymentMethod? _paymentMethod;
  String? _paymentStatus;
  _AuthStage _stage = _AuthStage.phone;
  String? _verificationId;
  String? _errorMessage;
  String? _displayName;
  String? _phoneNumber;
  int? _resendingToken;
  int _resendSeconds = 0;
  bool _isBusy = false;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    if (FirebaseAuth.instance.currentUser != null) {
      _loadCurrentProfile();
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _paymentNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentProfile() async {
    setState(() => _stage = _AuthStage.loading);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      if (snapshot.exists) {
        setState(() {
          _displayName = snapshot.data()?['displayName'] as String?;
          _phoneNumber = snapshot.data()?['phoneNumber'] as String?;
          _paymentMethod = PaymentMethod.fromValue(
            snapshot.data()?['paymentMethod'] as String?,
          );
          _paymentNumberController.text =
              snapshot.data()?['paymentNumber'] as String? ?? '';
          _stage = _AuthStage.account;
        });
      } else {
        setState(() {
          _phoneNumber = user.phoneNumber;
          _stage = _AuthStage.profile;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Impossible de charger votre profil. Réessayez.';
        _stage = _AuthStage.profile;
      });
    }
  }

  String? _formattedPhoneNumber() {
    final input = _phoneController.text.trim();
    final digits = input.replaceAll(RegExp(r'\D'), '');
    final phone = input.startsWith('+')
        ? '+$digits'
        : digits.startsWith('225')
        ? '+$digits'
        : '+225$digits';
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) return null;
    return phone;
  }

  Future<void> _sendCode({bool resend = false}) async {
    final phone = _formattedPhoneNumber();
    if (phone == null) {
      setState(() => _errorMessage = 'Saisissez un numéro de téléphone valide.');
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
      _phoneNumber = phone;
    });
    try {
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: kAuthTestMode,
      );
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        forceResendingToken: resend ? _resendingToken : null,
        verificationCompleted: (credential) => _signIn(credential),
        verificationFailed: (error) {
          if (!mounted) return;
          setState(() {
            _isBusy = false;
            _errorMessage = _authErrorMessage(error.code);
          });
        },
        codeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendingToken = resendToken;
            _stage = _AuthStage.code;
            _isBusy = false;
            _errorMessage = null;
          });
          _startResendCountdown();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _errorMessage = _authErrorMessage(error.code);
      });
    }
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendSeconds--);
      if (_resendSeconds <= 0) timer.cancel();
    });
  }

  Future<void> _verifyCode() async {
    final verificationId = _verificationId;
    if (verificationId == null || _codeController.text.length != 6) return;
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: _codeController.text.trim(),
      );
      await _signIn(credential);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _errorMessage = _authErrorMessage(error.code);
      });
    }
  }

  Future<void> _signIn(PhoneAuthCredential credential) async {
    if (mounted) setState(() => _isBusy = true);
    try {
      final result = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = result.user;
      if (user == null) throw FirebaseAuthException(code: 'user-not-found');

      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      if (profile.exists) {
        context.go('/');
      } else {
        setState(() {
          _phoneNumber = user.phoneNumber ?? _phoneNumber;
          _stage = _AuthStage.profile;
          _isBusy = false;
          _errorMessage = null;
        });
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _errorMessage = _authErrorMessage(error.code);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _errorMessage = 'Connexion impossible. Vérifiez votre connexion internet.';
      });
    }
  }

  Future<void> _saveProfile() async {
    final displayName = _nameController.text.trim();
    if (displayName.isEmpty) {
      setState(() => _errorMessage = 'Saisissez votre nom affiché.');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      final phoneNumber = user.phoneNumber ?? _phoneNumber;
      if (phoneNumber == null) {
        throw StateError('Le numéro de téléphone est indisponible.');
      }
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'phoneNumber': phoneNumber,
        'displayName': displayName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      context.go('/');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _errorMessage = 'Impossible d’enregistrer votre profil. Réessayez.';
      });
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    setState(() {
      _stage = _AuthStage.phone;
      _displayName = null;
      _phoneNumber = null;
      _paymentMethod = null;
      _paymentNumberController.clear();
      _paymentStatus = null;
      _verificationId = null;
      _codeController.clear();
      _errorMessage = null;
    });
  }

  String _authErrorMessage(String code) => switch (code) {
    'invalid-phone-number' => 'Le numéro de téléphone est invalide.',
    'invalid-verification-code' => 'Le code saisi est incorrect.',
    'session-expired' => 'Le code a expiré. Demandez-en un nouveau.',
    'too-many-requests' || 'quota-exceeded' =>
      'Trop de tentatives. Réessayez plus tard.',
    'network-request-failed' =>
      'Connexion internet indisponible. Réessayez.',
    'operation-not-allowed' => 'La connexion par téléphone est désactivée.',
    _ => 'Une erreur est survenue. Veuillez réessayer.',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compte')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: switch (_stage) {
              _AuthStage.loading => const CircularProgressIndicator(),
              _AuthStage.phone => _buildPhoneStep(),
              _AuthStage.code => _buildCodeStep(),
              _AuthStage.profile => _buildProfileStep(),
              _AuthStage.account => _buildAccountStep(),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Connexion', style: TextStyle(fontSize: 24)),
      const SizedBox(height: 8),
      const Text('Entrez votre numéro pour recevoir un code par SMS.'),
      const SizedBox(height: 24),
      TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: 'Numéro de téléphone',
          prefixText: '+225 ',
          hintText: '07 00 00 00 00',
          border: OutlineInputBorder(),
        ),
      ),
      _buildError(),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _isBusy ? null : _sendCode,
        child: _isBusy
            ? const CircularProgressIndicator()
            : const Text('Envoyer le code'),
      ),
    ],
  );

  Widget _buildCodeStep() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Vérification', style: TextStyle(fontSize: 24)),
      const SizedBox(height: 8),
      Text('Saisissez le code envoyé au ${_phoneNumber ?? ''}.'),
      const SizedBox(height: 24),
      TextField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 6,
        onChanged: (_) => setState(() {}),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        decoration: const InputDecoration(
          labelText: 'Code à 6 chiffres',
          border: OutlineInputBorder(),
        ),
      ),
      _buildError(),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _isBusy || _codeController.text.length != 6
            ? null
            : _verifyCode,
        child: _isBusy
            ? const CircularProgressIndicator()
            : const Text('Valider le code'),
      ),
      TextButton(
        onPressed: _isBusy || _resendSeconds > 0
            ? null
            : () => _sendCode(resend: true),
        child: Text(
          _resendSeconds > 0
              ? 'Renvoyer le code dans ${_resendSeconds}s'
              : 'Renvoyer le code',
        ),
      ),
      TextButton(
        onPressed: _isBusy
            ? null
            : () => setState(() {
                _stage = _AuthStage.phone;
                _errorMessage = null;
              }),
        child: const Text('Changer de numéro'),
      ),
    ],
  );

  Widget _buildProfileStep() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Votre profil', style: TextStyle(fontSize: 24)),
      const SizedBox(height: 8),
      const Text('Comment souhaitez-vous apparaître dans le groupe ?'),
      const SizedBox(height: 24),
      TextField(
        controller: _nameController,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _isBusy ? null : _saveProfile(),
        decoration: const InputDecoration(
          labelText: 'Nom affiché',
          border: OutlineInputBorder(),
        ),
      ),
      _buildError(),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _isBusy ? null : _saveProfile,
        child: _isBusy
            ? const CircularProgressIndicator()
            : const Text('Continuer'),
      ),
    ],
  );

  Widget _buildAccountStep() => SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Compte', style: TextStyle(fontSize: 24)),
        const SizedBox(height: 24),
        Text(_displayName ?? 'Utilisateur'),
        if (_phoneNumber != null) ...[
          const SizedBox(height: 8),
          Text(_phoneNumber!),
        ],
        const SizedBox(height: 24),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Moyen de paiement', style: TextStyle(fontSize: 18)),
        ),
        const SizedBox(height: 8),
        if (_paymentMethod == null)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Ajoutez votre moyen de paiement pour recevoir les cotisations',
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'Ce numéro sera visible des membres qui doivent vous payer lors de votre tour.',
          textAlign: TextAlign.left,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<PaymentMethod>(
          value: _paymentMethod,
          decoration: const InputDecoration(
            labelText: 'Moyen de paiement',
            border: OutlineInputBorder(),
          ),
          items: PaymentMethod.values
              .map(
                (method) => DropdownMenuItem(
                  value: method,
                  child: Text(method.label),
                ),
              )
              .toList(),
          onChanged: _isBusy
              ? null
              : (method) => setState(() {
                  _paymentMethod = method;
                  _paymentStatus = null;
                }),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _paymentNumberController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          onChanged: (_) => setState(() => _paymentStatus = null),
          decoration: const InputDecoration(
            labelText: 'Numéro de paiement',
            border: OutlineInputBorder(),
          ),
        ),
        if (_paymentStatus != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _paymentStatus!,
              style: TextStyle(color: Colors.green.shade700),
            ),
          ),
        ],
        if (_errorMessage != null) _buildError(),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _isBusy ? null : _savePaymentMethod,
          child: _isBusy
              ? const CircularProgressIndicator()
              : const Text('Enregistrer'),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _signOut,
          icon: const Icon(Icons.logout),
          label: const Text('Se déconnecter'),
        ),
      ],
    ),
  );

  Future<void> _savePaymentMethod() async {
    final paymentMethod = _paymentMethod;
    final paymentNumber = _paymentNumberController.text;
    if (paymentMethod == null) {
      setState(() {
        _errorMessage = 'Sélectionnez un moyen de paiement.';
        _paymentStatus = null;
      });
      return;
    }
    if (!RegExp(r'^\d{10}$').hasMatch(paymentNumber)) {
      setState(() {
        _errorMessage = 'Le numéro de paiement doit contenir exactement 10 chiffres.';
        _paymentStatus = null;
      });
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isBusy = true;
      _errorMessage = null;
      _paymentStatus = null;
    });
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'paymentMethod': paymentMethod.value,
        'paymentNumber': paymentNumber,
      });
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _paymentStatus = 'Enregistré';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _errorMessage = 'Impossible d’enregistrer votre moyen de paiement. Réessayez.';
      });
    }
  }

  Widget _buildError() {
    final message = _errorMessage;
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(message, style: TextStyle(color: Colors.red.shade700)),
    );
  }
}