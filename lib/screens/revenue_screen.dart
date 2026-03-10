import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/revenue_controller.dart';
import 'package:intl/intl.dart';

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key}); // إضافة الـ key بشكل صحيح

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
        title: const Text("حركة الدفع الإلكتروني", 
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        centerTitle: true,
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
                  // --- كروت الإحصائيات (محدثة لتشمل شحن المحافظ) ---
                  _buildSummaryCards(revenueProvider, isMobile),

                  const SizedBox(height: 30),

                  // --- جدول العمليات ---
                  const Text("سجل العمليات الناجحة (Paid)",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
                  const SizedBox(height: 15),
                  _buildTransactionTable(revenueProvider, isMobile),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards(RevenueController provider, bool isMobile) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? 2 : 4, // 2 في الصف للموبايل، 4 للشاشات الكبيرة
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: isMobile ? 1.2 : 1.5,
      children: [
        _statCard("اشتراكات", provider.totalSubscriptions, Icons.storefront, Colors.blue),
        _statCard("رسوم مناديب", provider.totalOperationalFees, Icons.delivery_dining, Colors.orange),
        _statCard("شحن محافظ", provider.totalWalletTopups, Icons.wallet, Colors.purple),
        _statCard("الإجمالي العام", provider.totalOverall, Icons.account_balance_wallet, Colors.green),
      ],
    );
  }

  Widget _statCard(String title, double value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontFamily: 'Cairo')),
          FittedBox(
            child: Text("${value.toStringAsFixed(0)} ج.م", 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTable(RevenueController provider, bool isMobile) {
    if (provider.transactions.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Text("لا توجد عمليات مدفوعة حالياً"),
      ));
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal, // للسماح بالتمرير في الموبايل
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
              DataCell(
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(tx.payerName, 
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2D3436))),
      const SizedBox(height: 2),
      Text(tx.phone, 
        style: TextStyle(color: Colors.grey[600], fontSize: 11, fontFamily: 'monospace')),
    ],
  ),
),

              DataCell(_buildTypeBadge(tx.type)),
              DataCell(Text("${tx.amount} ج.م", 
                style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold))),
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
      case 'SUBSCRIPTION_RENEW':
        color = Colors.blue;
        label = "باقة";
        break;
      case 'OPERATIONAL_FEES':
        color = Colors.orange;
        label = "رسوم";
        break;
      case 'WALLET_TOPUP':
        color = Colors.purple;
        label = "شحن";
        break;
      default:
        color = Colors.grey;
        label = "أخرى";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

