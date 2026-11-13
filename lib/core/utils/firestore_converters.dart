import 'package:cloud_firestore/cloud_firestore.dart';

DateTime dateTimeFromFirestore(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  throw FormatException('Date Firestore invalide : $value');
}

Timestamp dateTimeToFirestore(DateTime value) => Timestamp.fromDate(value);