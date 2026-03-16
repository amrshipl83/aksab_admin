import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart'; // مكتبة جداول احترافية للويب

class ReferralTrackingPage extends StatefulWidget {
  const ReferralTrackingPage({super.key});

  @override
  State<ReferralTrackingPage> createState() => _ReferralTrackingPageState();
}

class _ReferralTrackingPageState extends State<ReferralTrackingPage> {
  String searchCode = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة عهدة الإحالات - أسواق أكسب', style: TextStyle(fontFamily: 'Tajawal')),
        backgroundColor: Colors.orange[800],
      ),
      body: Column(
        children: [
          _buildSummaryCards(), // بطاقات ملخص سريع
          _buildSearchBar(),    // شريط البحث
          Expanded(child: _buildDriversTable()), // الجدول الرئيسي
        ],
      ),
    );
  }

  // 1. بطاقات الملخص (إجمالي عهدة المكافآت)
  Widget _buildSummaryCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('insuranceLogs').where('type', isEqualTo: 'referral_bonus_credit').snapshots(),
      builder: (context, snapshot) {
        double totalDistributed = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            totalDistributed += (doc['pointsAdded'] ?? 0);
          }
        }
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              _summaryCard("إجمالي نقاط الأمان الموزعة", totalDistributed.toString(), Colors.blue),
              _summaryCard("إجمالي العمليات اليوم", snapshot.hasData ? snapshot.data!.docs.length.toString() : "0", Colors.green),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(value, style: TextStyle(fontSize: 24, color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // 2. شريط البحث
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: TextField(
        decoration: const InputDecoration(
          labelText: 'ابحث بكود الداعي (مثلاً: AKS1041)',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
        onChanged: (value) => setState(() => searchCode = value),
      ),
    );
  }

  // 3. الجدول الرئيسي (ربط البيانات)
  Widget _buildDriversTable() {
    return StreamBuilder<QuerySnapshot>(
      // بنجيب المناديب اللي ليهم عداد إحالات أو تم دعوتهم
      stream: FirebaseFirestore.instance.collection('freeDrivers')
          .where('totalReferralsCount', isGreaterThan: 0)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var drivers = snapshot.data!.docs.where((doc) {
          if (searchCode.isEmpty) return true;
          return doc['referredBy'].toString().contains(searchCode);
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: DataTable2(
            columnSpacing: 12,
            horizontalMargin: 12,
            minWidth: 800,
            columns: const [
              DataColumn2(label: Text('المندوب المحال'), size: ColumnSize.L),
              DataColumn(label: Text('الداعي (كود)')),
              DataColumn(label: Text('الحملة')),
              DataColumn(label: Text('الأوردرات')),
              DataColumn(label: Text('الأهداف المحققة')),
              DataColumn(label: Text('حد الائتمان')),
            ],
            rows: drivers.map((driver) {
              return DataRow(cells: [
                DataCell(Text(driver['fullname'] ?? 'بدون اسم')),
                DataCell(Text(driver['referredBy'] ?? 'مباشر')),
                DataCell(Text(driver['appliedCampaignId'] ?? '-')),
                DataCell(Text(driver['totalReferralsCount'].toString())),
                DataCell(Text(driver['rewardMilestonesReached'].toString())),
                DataCell(Text("${driver['creditLimit'] ?? 0} ج.م")),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }
}

