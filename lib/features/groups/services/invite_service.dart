import 'package:cloud_functions/cloud_functions.dart';

class InviteService {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  Future<String> createInviteCode({required String groupId}) async {
    final response = await _functions
        .httpsCallable('createInviteCode')
        .call<Map<String, dynamic>>({'groupId': groupId});
    final code = response.data['code'];
    if (code is! String || code.isEmpty) {
      throw StateError('Réponse invalide lors de la création du code.');
    }
    return code;
  }

  Future<String> joinGroupByCode({required String code}) async {
    final response = await _functions
        .httpsCallable('joinGroupByCode')
        .call<Map<String, dynamic>>({'code': code});
    final groupId = response.data['groupId'];
    if (groupId is! String || groupId.isEmpty) {
      throw StateError('Réponse invalide lors de l’adhésion à la section.');
    }
    return groupId;
  }

  Future<void> startTontine({required String groupId}) async {
    await _functions
        .httpsCallable('startTontine')
        .call<Map<String, dynamic>>({'groupId': groupId});
  }

  Future<Map<String, String>> getPayeeInfo({
    required String groupId,
    required String roundId,
  }) async {
    final response = await _functions
        .httpsCallable('getPayeeInfo')
        .call<Map<String, dynamic>>({
          'groupId': groupId,
          'roundId': roundId,
        });
    final data = response.data;
    final recipientName = data['recipientName'];
    final paymentMethod = data['paymentMethod'];
    final paymentNumber = data['paymentNumber'];
    if (recipientName is! String ||
        paymentMethod is! String ||
        paymentNumber is! String) {
      throw StateError('Réponse invalide lors du chargement du paiement.');
    }
    return {
      'recipientName': recipientName,
      'paymentMethod': paymentMethod,
      'paymentNumber': paymentNumber,
    };
  }
}