import '../../../core/utils/firestore_converters.dart';

enum ContributionStatus {
  enAttente('en_attente'),
  declare('declare'),
  confirme('confirme');

  const ContributionStatus(this.value);
  final String value;

  static ContributionStatus fromValue(String value) =>
      ContributionStatus.values.firstWhere((status) => status.value == value);
}

class Contribution {
  const Contribution({
    required this.id,
    required this.groupId,
    required this.roundId,
    required this.memberId,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String roundId;
  final String memberId;
  final int amount;
  final ContributionStatus status;
  final DateTime createdAt;

  factory Contribution.fromMap(String id, Map<String, dynamic> data) =>
      Contribution(
        id: id,
        groupId: data['groupId'] as String,
        roundId: data['roundId'] as String,
        memberId: data['memberId'] as String,
        amount: data['amount'] as int,
        status: ContributionStatus.fromValue(data['status'] as String),
        createdAt: dateTimeFromFirestore(data['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'groupId': groupId,
        'roundId': roundId,
        'memberId': memberId,
        'amount': amount,
        'status': status.value,
        'createdAt': dateTimeToFirestore(createdAt),
      };
}