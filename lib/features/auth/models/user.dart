import '../../../core/utils/firestore_converters.dart';

class User {
  const User({
    required this.id,
    required this.phoneNumber,
    required this.displayName,
    required this.createdAt,
  });

  final String id;
  final String phoneNumber;
  final String displayName;
  final DateTime createdAt;

  factory User.fromMap(String id, Map<String, dynamic> data) => User(
        id: id,
        phoneNumber: data['phoneNumber'] as String,
        displayName: data['displayName'] as String,
        createdAt: dateTimeFromFirestore(data['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'phoneNumber': phoneNumber,
        'displayName': displayName,
        'createdAt': dateTimeToFirestore(createdAt),
      };
}