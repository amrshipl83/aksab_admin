import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlyFinanceDetails extends StatelessWidget {
  final String selectedPeriod;

  const MonthlyFinanceDetails({super.key, required this.selectedPeriod});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("تقرير أداء $selectedPeriod", style: const TextStyle(fontFamily: 'Cairo'))),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('platform_ledger')
            .where('period', isEqualTo: selectedPeriod)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          double sellersRevenue = 0;
          double deliveryRevenue = 0;
          double totalExpenses = 0;

          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            double amount = (data['totalAmount'] ?? 0).toDouble();
            
            if (data['entryType'] == 'revenue') {
              if (data['source'] == 'sellers') sellersRevenue += amount;
              if (data['source'] == 'delivery') deliveryRevenue += amount;
            } else if (data['entryType'] == 'expense') {
              totalExpenses += amount;
            }
          }

          double netProfit = (sellersRevenue + deliveryRevenue) - totalExpenses;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSummaryCard(netProfit),
              const SizedBox(height: 30),
              _buildRowItem("إيرادات الموردين", sellersRevenue, Colors.green),
              _buildRowItem("إيرادات التوصيل", deliveryRevenue, Colors.blue),
              _buildRowItem("إجمالي المصاريف", totalExpenses, Colors.red),
              const Divider(height: 40, thickness: 2),
              _buildRowItem("الصافي النهائي", netProfit, Colors.black, isBold: true),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(double net) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: net >= 0 ? Colors.green[800] : Colors.red[800],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          const Text("صافي الربح / الخسارة", style: TextStyle(color: Colors.white70, fontFamily: 'Cairo')),
          Text("${net.toStringAsFixed(2)} ج.م", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRowItem(String title, double value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text("${value.toStringAsFixed(2)} ج.م", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}

