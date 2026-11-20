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
}