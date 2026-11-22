import '../../../core/utils/firestore_converters.dart';

class Member {
  const Member({
    required this.id,
    required this.userId,
    required this.groupId,
    required this.joinedAt,
    this.displayName,
  });

  final String id;
  final String userId;
  final String groupId;
  final DateTime joinedAt;
  final String? displayName;

  factory Member.fromMap(String id, Map<String, dynamic> data) => Member(
        id: id,
        userId: data['userId'] as String,
        groupId: data['groupId'] as String,
        joinedAt: dateTimeFromFirestore(data['joinedAt']),
        displayName: data['displayName'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'groupId': groupId,
        'joinedAt': dateTimeToFirestore(joinedAt),
        if (displayName != null) 'displayName': displayName,
      };
}