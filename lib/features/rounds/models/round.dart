import '../../../core/utils/firestore_converters.dart';

enum RoundStatus {
  scheduled('scheduled'),
  drawn('drawn'),
  completed('completed');

  const RoundStatus(this.value);
  final String value;

  static RoundStatus fromValue(String value) =>
      RoundStatus.values.firstWhere((status) => status.value == value);
}

class Round {
  const Round({
    required this.id,
    required this.groupId,
    required this.number,
    required this.recipientId,
    required this.scheduledAt,
    required this.status,
    this.recipientName,
  });

  final String id;
  final String groupId;
  final int number;
  final String recipientId;
  final String? recipientName;
  final DateTime scheduledAt;
  final RoundStatus status;

  factory Round.fromMap(String id, Map<String, dynamic> data) => Round(
        id: id,
        groupId: data['groupId'] as String,
        number: data['number'] as int,
        recipientId: data['recipientId'] as String,
        recipientName: data['recipientName'] as String? ?? 'Membre',
        scheduledAt: dateTimeFromFirestore(data['scheduledAt']),
        status: RoundStatus.fromValue(data['status'] as String),
      );

  Map<String, dynamic> toMap() => {
        'groupId': groupId,
        'number': number,
        'recipientId': recipientId,
        if (recipientName != null) 'recipientName': recipientName,
        'scheduledAt': dateTimeToFirestore(scheduledAt),
        'status': status.value,
      };
}