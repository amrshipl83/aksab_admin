import 'package:cloud_firestore/cloud_firestore.dart';

class SupermarketModel {
  final String id;
  final String name;
  final String address;
  final double? deliveryFee;
  final bool isActive;
  final DateTime? requestDate;

  SupermarketModel({
    required this.id,
    required this.name,
    required this.address,
    this.deliveryFee,
    this.isActive = true,
    this.requestDate,
  });

  // لتحويل بيانات Firebase إلى كائن فلاتر (مطابق للـ HTML)
  factory SupermarketModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return SupermarketModel(
      id: documentId,
      name: data['supermarketName'] ?? 'غير معروف',
      address: data['address'] ?? '',
      deliveryFee: (data['deliveryFee'] as num?)?.toDouble(),
      isActive: data['isActive'] ?? true,
      requestDate: (data['requestDate'] as Timestamp?)?.toDate(),
    );
  }
}

