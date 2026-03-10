import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/revenue_controller.dart';
import 'package:intl/intl.dart';

class RevenueScreen extends StatefulWidget {
  @override
  _RevenueScreenState createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  @override
  void initState() {
    super.initState();
    // جلب البيانات فور فتح الشاشة
    Future.delayed(Duration.zero, () {
      Provider.of<RevenueController>(context, listen: false).fetchRevenueData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final revenueProvider = Provider.of<RevenueController>(context);
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("تقارير الإيرادات المالية", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => revenueProvider.fetchRevenueData(),
          )
        ],
      ),
      body: revenueProvider.isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- الجزء العلوي: كروت الإحصائيات ---
                  _buildSummaryCards(revenueProvider, isMobile),
                  
                  SizedBox(height: 30),
                  
                  // --- الجزء السفلي: جدول العمليات ---
                  Text("آخر العمليات الناجحة", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[900])),
                  SizedBox(height: 15),
                  _buildTransactionTable(revenueProvider),
                ],
              ),
            ),
    );
  }

  // ويدجت بناء الكروت العلوية
  Widget _buildSummaryCards(RevenueController provider, bool isMobile) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: isMobile ? 1 : 3,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      childAspectRatio: isMobile ? 2.5 : 2,
      children: [
        _statCard("إجمالي الاشتراكات", "${provider.totalSubscriptions} ج.م", Icons.storefront, Colors.blue),
        _statCard("رسوم المناديب", "${provider.totalDriverFees} ج.م", Icons.delivery_dining, Colors.orange),
        _statCard("صافي الإيرادات", "${provider.totalOverall} ج.م", Icons.account_balance_wallet, Colors.green),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 40),
          SizedBox(height: 10),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ويدجت بناء جدول البيانات
  Widget _buildTransactionTable(RevenueController provider) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
        columns: [
          DataColumn(label: Text('الجهة')),
          DataColumn(label: Text('النوع')),
          DataColumn(label: Text('المبلغ')),
          DataColumn(label: Text('التاريخ')),
        ],
        rows: provider.transactions.map((tx) {
          return DataRow(cells: [
            DataCell(Text(tx.payerName, style: TextStyle(fontWeight: FontWeight.w500))),
            DataCell(_buildTypeBadge(tx.type)),
            DataCell(Text("${tx.amount} ج.م", style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold))),
            DataCell(Text(DateFormat('yyyy-MM-dd HH:mm').format(tx.paidAt))),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    bool isSub = type == 'SUBSCRIPTION_RENEW';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isSub ? Colors.blue[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isSub ? "تجديد باقة" : "شحن محفظة",
        style: TextStyle(color: isSub ? Colors.blue[800] : Colors.orange[800], fontSize: 12),
      ),
    );
  }
}

