import 'package:cloud_firestore/cloud_firestore.dart';

class RevenueModel {
  final String id;
  final String type; // SUBSCRIPTION_RENEW or OPERATIONAL_FEES
  final double amount;
  final DateTime paidAt;
  final String payerName; // اسم المحل أو المندوب
  final String paymobId;

  RevenueModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.paidAt,
    required this.payerName,
    required this.paymobId,
  });

  factory RevenueModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return RevenueModel(
      id: doc.id,
      type: data['type'] ?? 'UNKNOWN',
      amount: (data['amount'] ?? 0).toDouble(),
      paidAt: (data['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      // بنحاول نجيب الاسم من كذا حقل محتمل حسب نوع الفاتورة
      payerName: data['supermarketName'] ?? data['merchantName'] ?? data['driverId'] ?? 'عميل غير معروف',
      paymobId: data['paymobTransactionId'] ?? '-',
    );
  }
}

