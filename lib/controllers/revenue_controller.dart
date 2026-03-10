import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- الموديل المحدث ليتناسب مع الحقول التي راجعناها ---
class RevenueModel {
  final String id;
  final String type; 
  final double amount;
  final DateTime paidAt;
  final String payerName;
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
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    // تحديد اسم الجهة بناءً على المتاح في السجل
    String name = 'جهة غير معروفة';
    if (data['merchantName'] != null && data['merchantName'].toString().isNotEmpty) {
      name = data['merchantName'];
    } else if (data['driverId'] != null) {
      name = "مندوب: ${data['driverId']}";
    }

    return RevenueModel(
      id: doc.id,
      type: data['type'] ?? 'OTHER',
      amount: double.tryParse(data['amount']?.toString() ?? '0') ?? 0.0,
      paidAt: (data['paidAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paymobId: data['paymobTransactionId']?.toString() ?? '-',
      payerName: name,
    );
  }
}

// --- الكنترول المؤمن لإدارة جلب البيانات ---
class RevenueController extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<RevenueModel> _transactions = [];
  bool _isLoading = false;

  // الإحصائيات المالية
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
      // جلب البيانات بفلتر الحالة فقط (لتجنب مشاكل الـ Index على الموبايل حالياً)
      QuerySnapshot snapshot = await _db.collection('pendingInvoices')
          .where('status', isEqualTo: 'paid')
          .get();

      // تحويل البيانات وترتيبها يدوياً في الكود (أكثر أماناً)
      _transactions = snapshot.docs
          .map((doc) => RevenueModel.fromFirestore(doc))
          .toList();
          
      // ترتيب تنازلي (الأحدث فوق)
      _transactions.sort((a, b) => b.paidAt.compareTo(a.paidAt));

      // إعادة تصفير الحسابات قبل الجمع
      totalSubscriptions = 0;
      totalOperationalFees = 0;
      totalWalletTopups = 0;

      for (var tx in _transactions) {
        switch (tx.type) {
          case 'SUBSCRIPTION_RENEW':
            totalSubscriptions += tx.amount;
            break;
          case 'OPERATIONAL_FEES':
            totalOperationalFees += tx.amount;
            break;
          case 'WALLET_TOPUP':
            totalWalletTopups += tx.amount;
            break;
        }
      }
      
      totalOverall = totalSubscriptions + totalOperationalFees + totalWalletTopups;

    } catch (e) {
      debugPrint("❌ خطأ في جلب بيانات الإيرادات: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

