import '../../../core/utils/firestore_converters.dart';

class Member {
  const Member({
    required this.id,
    required this.userId,
    required this.groupId,
    required this.joinedAt,
  });

  final String id;
  final String userId;
  final String groupId;
  final DateTime joinedAt;

  factory Member.fromMap(String id, Map<String, dynamic> data) => Member(
        id: id,
        userId: data['userId'] as String,
        groupId: data['groupId'] as String,
        joinedAt: dateTimeFromFirestore(data['joinedAt']),
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'groupId': groupId,
        'joinedAt': dateTimeToFirestore(joinedAt),
      };
}