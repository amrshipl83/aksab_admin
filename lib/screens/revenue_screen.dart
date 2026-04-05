import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ إضافة فايربيز للمستحقات
import '../controllers/revenue_controller.dart';
import 'package:intl/intl.dart';
import 'merchant_payouts_screen.dart'; // ✅ لاستخدام شاشة التفاصيل لو حبيت

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  _RevenueScreenState createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      Provider.of<RevenueController>(context, listen: false).fetchRevenueData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final revenueProvider = Provider.of<RevenueController>(context);
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("حركة الدفع والتسويات",
            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        centerTitle: true,
        backgroundColor: const Color(0xFFB21F2D), // طقمنا اللون مع الإدارة
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => revenueProvider.fetchRevenueData(),
          )
        ],
      ),
      body: revenueProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- قسم الكروت (تم إضافة كارت مستحقات الديفيرى) ---
                  _buildEnhancedSummaryCards(revenueProvider, isMobile),

                  const SizedBox(height: 30),

                  // --- جدول مستحقات الديفيرى (الجديد) ---
                  const Text("مستحقات بانتظار التسوية (أمانات)",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFB21F2D))),
                  const SizedBox(height: 10),
                  _buildPayoutQueueTable(isMobile),

                  const SizedBox(height: 40),

                  // --- جدول العمليات القديم ---
                  const Text("سجل الدفع الإلكتروني (Paid)",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
                  const SizedBox(height: 15),
                  _buildTransactionTable(revenueProvider, isMobile),
                ],
              ),
            ),
    );
  }

  // ويدجت الكروت المحدث (5 كروت بدل 4)
  Widget _buildEnhancedSummaryCards(RevenueController provider, bool isMobile) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('deliverySupermarkets').snapshots(),
      builder: (context, snapshot) {
        double totalAwaiting = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            totalAwaiting += (doc['awaiting_verification'] ?? 0).toDouble();
          }
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isMobile ? 2 : 5, // 5 كروت في الصف للويب
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isMobile ? 1.1 : 1.3,
          children: [
            _statCard("اشتراكات", provider.totalSubscriptions, Icons.storefront, Colors.blue),
            _statCard("رسوم مناديب", provider.totalOperationalFees, Icons.delivery_dining, Colors.orange),
            _statCard("شحن محافظ", provider.totalWalletTopups, Icons.wallet, Colors.purple),
            // الكارت الجديد والمطلوب باللون الأحمر
            _statCard("مستحقات ديفيرى", totalAwaiting, Icons.account_balance_wallet, const Color(0xFFB21F2D)),
            _statCard("الإجمالي العام", provider.totalOverall + totalAwaiting, Icons.assessment, Colors.green),
          ],
        );
      },
    );
  }

  Widget _statCard(String title, double value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 11, fontFamily: 'Cairo')),
          FittedBox(
            child: Text("${value.toStringAsFixed(0)} ج.م",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  // جدول مراقبة المستحقات الجديد بداخل نفس الصفحة
  Widget _buildPayoutQueueTable(bool isMobile) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('deliverySupermarkets')
          .where('awaiting_verification', isGreaterThan: 0)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Card(child: Padding(padding: EdgeInsets.all(20), child: Text("لا توجد مبالغ معلقة للسداد ✅")));
        }

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.red.withOpacity(0.1))),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('المورد')),
                DataColumn(label: Text('المبلغ')),
                DataColumn(label: Text('الحالة')),
                DataColumn(label: Text('الإجراء')),
              ],
              rows: snapshot.data!.docs.map((doc) {
                var data = doc.data() as Map<String, dynamic>;
                return DataRow(cells: [
                  DataCell(Text(data['supermarketName'] ?? '..', style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text("${data['awaiting_verification']} ج.م", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                  DataCell(_buildTypeBadge("PENDING_PAYOUT")),
                  DataCell(ElevatedButton(
                    onPressed: () => _showConfirmPayout(context, doc.id, data['supermarketName'], data['awaiting_verification']),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 10)),
                    child: const Text("سداد", style: TextStyle(fontSize: 12)),
                  )),
                ]);
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // نافذة التأكيد السريع
  void _showConfirmPayout(BuildContext context, String id, String name, dynamic amt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد استلام أمانات"),
        content: Text("هل تم سداد $amt ج.م لـ $name؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance.collection('payoutRequests').add({
                'merchantId': id,
                'merchantName': name,
                'amount': (amt as num).toDouble(),
                'status': 'pending',
                'createdAt': FieldValue.serverTimestamp(),
              });
            },
            child: const Text("تأكيد"),
          ),
        ],
      ),
    );
  }

  // الدالة الأصلية لجدول العمليات (بدون تغيير)
  Widget _buildTransactionTable(RevenueController provider, bool isMobile) {
    if (provider.transactions.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text("لا توجد عمليات مدفوعة حالياً")));
    }
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[200]!)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
          columns: const [
            DataColumn(label: Text('الجهة')),
            DataColumn(label: Text('النوع')),
            DataColumn(label: Text('المبلغ')),
            DataColumn(label: Text('التاريخ')),
          ],
          rows: provider.transactions.map((tx) {
            return DataRow(cells: [
              DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(tx.payerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(tx.phone, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ])),
              DataCell(_buildTypeBadge(tx.type)),
              DataCell(Text("${tx.amount} ج.م", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
              DataCell(Text(DateFormat('MM-dd HH:mm').format(tx.paidAt))),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    Color color;
    String label;
    switch (type) {
      case 'SUBSCRIPTION_RENEW': color = Colors.blue; label = "باقة"; break;
      case 'OPERATIONAL_FEES': color = Colors.orange; label = "رسوم"; break;
      case 'WALLET_TOPUP': color = Colors.purple; label = "شحن"; break;
      case 'PENDING_PAYOUT': color = Colors.red; label = "مستحق"; break;
      default: color = Colors.grey; label = "أخرى";
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

