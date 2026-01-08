import 'package:cloud_firestore/cloud_firestore.dart';

class SupermarketModel {
  final String id;
  final String name;
  final String address;
  final double? deliveryFee;
  final double? minimumOrderValue;
  final String? deliveryHours;
  final String? description;
  final String? deliveryContactPhone;
  final String? whatsappNumber;
  final bool isActive;
  final bool? deliveryActive;
  final String? status;
  final String? ownerId;
  final DateTime? requestDate;
  final DateTime? approvalDate;
  final DateTime? lastUpdated;
  final Map<String, dynamic>? location;

  SupermarketModel({
    required this.id,
    required this.name,
    required this.address,
    this.deliveryFee,
    this.minimumOrderValue,
    this.deliveryHours,
    this.description,
    this.deliveryContactPhone,
    this.whatsappNumber,
    this.isActive = true,
    this.deliveryActive,
    this.status,
    this.ownerId,
    this.requestDate,
    this.approvalDate,
    this.lastUpdated,
    this.location,
  });

  // لتحويل بيانات Firebase إلى كائن فلاتر (يدعم كلا المجموعتين)
  factory SupermarketModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return SupermarketModel(
      id: documentId,
      name: data['supermarketName'] ?? 'غير معروف',
      address: data['address'] ?? '',
      deliveryFee: (data['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      minimumOrderValue: (data['minimumOrderValue'] as num?)?.toDouble() ?? 0.0,
      deliveryHours: data['deliveryHours']?.toString(),
      description: data['descriptionForDelivery']?.toString(),
      deliveryContactPhone: data['deliveryContactPhone']?.toString(),
      whatsappNumber: data['whatsappNumber']?.toString(),
      isActive: data['isActive'] ?? true,
      deliveryActive: data['deliveryActive'],
      status: data['status']?.toString(),
      ownerId: data['ownerId']?.toString(),
      location: data['location'] is Map ? data['location'] as Map<String, dynamic> : null,
      
      // التعامل مع التواريخ المختلفة
      requestDate: (data['requestDate'] as Timestamp?)?.toDate(),
      approvalDate: (data['approvalDate'] as Timestamp?)?.toDate(),
      lastUpdated: (data['lastUpdated'] as Timestamp? ?? data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

