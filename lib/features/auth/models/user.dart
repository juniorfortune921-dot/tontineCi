import '../../../core/utils/firestore_converters.dart';

enum PaymentMethod {
  wave('wave', 'Wave'),
  orange('orange', 'Orange Money'),
  mtn('mtn', 'MTN MoMo'),
  moov('moov', 'Moov Money');

  const PaymentMethod(this.value, this.label);

  final String value;
  final String label;

  static PaymentMethod? fromValue(String? value) {
    for (final method in values) {
      if (method.value == value) return method;
    }
    return null;
  }
}

class User {
  const User({
    required this.id,
    required this.phoneNumber,
    required this.displayName,
    required this.createdAt,
    this.paymentMethod,
    this.paymentNumber,
  });

  final String id;
  final String phoneNumber;
  final String displayName;
  final DateTime createdAt;
  final PaymentMethod? paymentMethod;
  final String? paymentNumber;

  factory User.fromMap(String id, Map<String, dynamic> data) => User(
        id: id,
        phoneNumber: data['phoneNumber'] as String,
        displayName: data['displayName'] as String,
        createdAt: dateTimeFromFirestore(data['createdAt']),
        paymentMethod: PaymentMethod.fromValue(data['paymentMethod'] as String?),
        paymentNumber: data['paymentNumber'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'phoneNumber': phoneNumber,
        'displayName': displayName,
        'createdAt': dateTimeToFirestore(createdAt),
        if (paymentMethod != null && paymentNumber != null) ...{
          'paymentMethod': paymentMethod!.value,
          'paymentNumber': paymentNumber,
        },
      };
}