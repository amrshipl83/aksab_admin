import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/revenue_model.dart';

class RevenueController extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<RevenueModel> _transactions = [];
  bool _isLoading = false;

  // الإجماليات
  double totalSubscriptions = 0;
  double totalDriverFees = 0;
  double totalOverall = 0;

  List<RevenueModel> get transactions => _transactions;
  bool get isLoading => _isLoading;

  // دالة جلب البيانات من السيرفر
  Future<void> fetchRevenueData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // بنجيب بس الفواتير اللي حالتها paid
      QuerySnapshot snapshot = await _db.collection('pendingInvoices')
          .where('status', isEqualTo: 'paid')

          .orderBy('paidAt', descending: true)
          .get();

      _transactions = snapshot.docs.map((doc) => RevenueModel.fromFirestore(doc)).toList();

      // إعادة تصفير الحسابات قبل الجمع الجديد
      totalSubscriptions = 0;
      totalDriverFees = 0;

      for (var tx in _transactions) {
        if (tx.type == 'SUBSCRIPTION_RENEW') {
          totalSubscriptions += tx.amount;
        } else if (tx.type == 'OPERATIONAL_FEES') {
          totalDriverFees += tx.amount;
        }
      }
      
      totalOverall = totalSubscriptions + totalDriverFees;

    } catch (e) {
      print("❌ خطأ في جلب تقارير الإيرادات: $e");
    }

    _isLoading = false;
    notifyListeners();
  }
}

