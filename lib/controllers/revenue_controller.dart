import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RevenueModel {
  final String id;
  final String type;
  final double amount;
  final DateTime paidAt;
  final String payerName;
  final String phone; // أضفنا التليفون هنا
  final String paymobId;

  RevenueModel({
    required this.id, required this.type, required this.amount,
    required this.paidAt, required this.payerName, required this.phone, required this.paymobId,
  });
}

class RevenueController extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<RevenueModel> _transactions = [];
  bool _isLoading = false;

  double totalSubscriptions = 0;
  double totalOperationalFees = 0;
  double totalWalletTopups = 0;
  double totalOverall = 0;

  List<RevenueModel> get transactions => _transactions;
  bool get isLoading => _isLoading;

  Future<void> fetchRevenueData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. جلب العمليات المدفوعة
      QuerySnapshot invoiceSnapshot = await _db.collection('pendingInvoices')
          .where('status', isEqualTo: 'paid').get();

      // 2. جلب "كاش" لبيانات المناديب والسوبر ماركت لتسريع الربط
      final driversMap = await _getCollectionMap('freeDrivers', 'fullname', 'phone');
      final storesMap = await _getCollectionMap('deliverySupermarkets', 'supermarketName', 'ownerPhone');

      List<RevenueModel> tempTransactions = [];
      totalSubscriptions = 0;
      totalOperationalFees = 0;
      totalWalletTopups = 0;

      for (var doc in invoiceSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        String type = data['type'] ?? 'OTHER';
        double amt = double.tryParse(data['amount']?.toString() ?? '0') ?? 0.0;
        
        // --- منطق تحديد الاسم والتليفون الذكي ---
        String finalName = 'غير معروف';
        String finalPhone = '-';

        if (type == 'OPERATIONAL_FEES' || data['driverId'] != null) {
          final dId = data['driverId'];
          finalName = driversMap[dId]?['name'] ?? 'مندوب غير مسجل';
          finalPhone = driversMap[dId]?['phone'] ?? '-';
        } else if (type == 'SUBSCRIPTION_RENEW' || data['storeId'] != null) {
          final sId = data['storeId'];
          finalName = storesMap[sId]?['name'] ?? data['merchantName'] ?? 'سوبر ماركت';
          finalPhone = storesMap[sId]?['phone'] ?? data['phone'] ?? '-';
        } else {
          finalName = data['merchantName'] ?? data['supermarketName'] ?? 'جهة أخرى';
          finalPhone = data['phone'] ?? '-';
        }

        tempTransactions.add(RevenueModel(
          id: doc.id,
          type: type,
          amount: amt,
          paidAt: (data['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          payerName: finalName,
          phone: finalPhone,
          paymobId: data['paymobTransactionId']?.toString() ?? '-',
        ));

        // حساب الإجماليات
        if (type == 'SUBSCRIPTION_RENEW') totalSubscriptions += amt;
        else if (type == 'OPERATIONAL_FEES') totalOperationalFees += amt;
        else if (type == 'WALLET_TOPUP') totalWalletTopups += amt;
      }

      tempTransactions.sort((a, b) => b.paidAt.compareTo(a.paidAt));
      _transactions = tempTransactions;
      totalOverall = totalSubscriptions + totalOperationalFees + totalWalletTopups;

    } catch (e) {
      debugPrint("❌ خطأ في الربط: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // دالة مساعدة لجلب البيانات كـ Map لتقليل الضغط على السيرفر
  Future<Map<String, Map<String, String>>> _getCollectionMap(String collection, String nameField, String phoneField) async {
    QuerySnapshot s = await _db.collection(collection).get();
    return { for (var d in s.docs) d.id : { 
      'name': (d.data() as Map)[nameField]?.toString() ?? 'بدون اسم',
      'phone': (d.data() as Map)[phoneField]?.toString() ?? '-'
    }};
  }
}

