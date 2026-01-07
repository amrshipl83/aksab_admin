import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FinancialSummaryScreen extends StatefulWidget {
  const FinancialSummaryScreen({super.key});

  @override
  State<FinancialSummaryScreen> createState() => _FinancialSummaryScreenState();
}

class _FinancialSummaryScreenState extends State<FinancialSummaryScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // تنسيق العملة المصرية
  String formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'ar_EG', symbol: 'ج.م', decimalDigits: 2).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text("ملخص أرصدة المنصة التراكمي", style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: const Color(0xFFB21F2D),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchFinancialData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFB21F2D)));
          }
          if (snapshot.hasError) {
            return Center(child: Text("حدث خطأ في تحميل البيانات: ${snapshot.error}"));
          }

          final data = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "📊 نظرة عامة على العمولات والديون",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 20),
                
                // شبكة الكروت المالية
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 1,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 2.5,
                  children: [
                    _buildFinanceCard(
                      "عمولات محققة مستحقة",
                      data['realized'],
                      Icons.check_circle_outline,
                      Colors.green,
                    ),
                    _buildFinanceCard(
                      "عمولات قيد التجميع",
                      data['unrealized'],
                      Icons.hourglass_empty,
                      Colors.orange,
                    ),
                    _buildFinanceCard(
                      "دين كاش باك (من التجار)",
                      data['cbDebt'],
                      Icons.trending_down,
                      Colors.red,
                    ),
                    _buildFinanceCard(
                      "كاش باك مستحق (للتجار)",
                      data['cbCredit'],
                      Icons.account_balance_wallet,
                      Colors.blue,
                    ),
                    _buildFinanceCard(
                      "إيرادات الرسوم الشهرية",
                      data['monthlyFees'],
                      Icons.calendar_today,
                      Colors.teal,
                    ),
                    _buildFinanceCard(
                      "فواتير قيد الانتظار",
                      data['pendingInvoices'].toDouble(),
                      Icons.receipt_long,
                      Colors.blueGrey,
                      isCurrency: false,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // دالة جلب البيانات من Firestore (نفس منطق الـ JavaScript)
  Future<Map<String, dynamic>> _fetchFinancialData() async {
    double totalRealized = 0;
    double totalUnrealized = 0;
    double totalCbDebt = 0;
    double totalCbCredit = 0;
    double totalMonthlyFees = 0;

    // 1. تجميع بيانات التجار
    final sellersSnapshot = await _db.collection('sellers').get();
    for (var doc in sellersSnapshot.docs) {
      final d = doc.data();
      totalRealized += (d['realizedCommission'] ?? 0).toDouble();
      totalUnrealized += (d['unrealizedCommission'] ?? 0).toDouble();
      totalCbDebt += (d['cashbackAccruedDebt'] ?? 0).toDouble();
      totalCbCredit += (d['cashbackPlatformCredit'] ?? 0).toDouble();
      totalMonthlyFees += (d['monthlyFee'] ?? 0).toDouble();
    }

    // 2. حساب الفواتير المعلقة
    final invoicesSnapshot = await _db
        .collection('invoices')
        .where('status', isEqualTo: 'pending')
        .get();

    return {
      'realized': totalRealized,
      'unrealized': totalUnrealized,
      'cbDebt': totalCbDebt,
      'cbCredit': totalCbCredit,
      'monthlyFees': totalMonthlyFees,
      'pendingInvoices': invoicesSnapshot.size,
    };
  }

  // بناء كرت مالي احترافي
  Widget _buildFinanceCard(String title, double value, IconData icon, Color color, {bool isCurrency = true}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(right: BorderSide(color: color, width: 6)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Cairo')),
                const SizedBox(height: 5),
                Text(
                  isCurrency ? formatCurrency(value) : value.toInt().toString(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

