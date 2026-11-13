import '../../../core/utils/firestore_converters.dart';

class User {
  const User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;

  factory User.fromMap(String id, Map<String, dynamic> data) => User(
        id: id,
        email: data['email'] as String,
        displayName: data['displayName'] as String,
        createdAt: dateTimeFromFirestore(data['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        'createdAt': dateTimeToFirestore(createdAt),
      };
}