import '../../../core/utils/firestore_converters.dart';

enum GroupFrequency {
  weekly('weekly'),
  monthly('monthly');

  const GroupFrequency(this.value);
  final String value;

  static GroupFrequency fromValue(String value) => GroupFrequency.values
      .firstWhere((frequency) => frequency.value == value);
}

enum DistributionMode {
  tirage('tirage'),
  ordre('ordre');

  const DistributionMode(this.value);
  final String value;

  static DistributionMode fromValue(String value) => DistributionMode.values
      .firstWhere((mode) => mode.value == value);
}

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.amount,
    required this.currency,
    required this.frequency,
    required this.distributionMode,
    required this.ownerId,
    required this.createdAt,
  });

  final String id;
  final String name;
  final int amount;
  final String currency;
  final GroupFrequency frequency;
  final DistributionMode distributionMode;
  final String ownerId;
  final DateTime createdAt;

  factory Group.fromMap(String id, Map<String, dynamic> data) => Group(
        id: id,
        name: data['name'] as String,
        amount: data['amount'] as int,
        currency: data['currency'] as String,
        frequency: GroupFrequency.fromValue(data['frequency'] as String),
        distributionMode: DistributionMode.fromValue(
          data['distributionMode'] as String,
        ),
        ownerId: data['ownerId'] as String,
        createdAt: dateTimeFromFirestore(data['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'amount': amount,
        'currency': currency,
        'frequency': frequency.value,
        'distributionMode': distributionMode.value,
        'ownerId': ownerId,
        'createdAt': dateTimeToFirestore(createdAt),
      };
}