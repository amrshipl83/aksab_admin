import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_table_2/data_table_2.dart'; // مكتبة جداول احترافية للويب

// ✅ تم تعديل الاسم ليتطابق مع الاستدعاء في صفحة الـ Tab
class FleetReferralMasterPage extends StatefulWidget {
  const FleetReferralMasterPage({super.key});

  @override
  State<FleetReferralMasterPage> createState() => _FleetReferralMasterPageState();
}

class _FleetReferralMasterPageState extends State<FleetReferralMasterPage> {
  String searchCode = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة عهدة الإحالات - أسواق أكسب',
            style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange[800],
        centerTitle: true,
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
      stream: FirebaseFirestore.instance
          .collection('insuranceLogs')
          .where('type', isEqualTo: 'referral_bonus_credit')
          .snapshots(),
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
              _summaryCard("إجمالي نقاط الأمان الموزعة", totalDistributed.toStringAsFixed(0), Colors.blue),
              const SizedBox(width: 12),
              _summaryCard("عمليات العهدة اليوم", 
                  snapshot.hasData ? snapshot.data!.docs.length.toString() : "0", 
                  Colors.green),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              const SizedBox(height: 10),
              Text(value, style: TextStyle(fontSize: 22, color: color, fontWeight: FontWeight.bold)),
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
        decoration: InputDecoration(
          labelText: 'ابحث بكود الداعي (مثلاً: AKS1041)',
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onChanged: (value) => setState(() => searchCode = value),
      ),
    );
  }

  // 3. الجدول الرئيسي (ربط البيانات)
  Widget _buildDriversTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('freeDrivers')
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
            headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
            columns: const [
              DataColumn2(label: Text('المندوب المحال', style: TextStyle(fontFamily: 'Cairo')), size: ColumnSize.L),
              DataColumn(label: Text('الداعي (كود)', style: TextStyle(fontFamily: 'Cairo'))),
              DataColumn(label: Text('الحملة', style: TextStyle(fontFamily: 'Cairo'))),
              DataColumn(label: Text('الأوردرات', style: TextStyle(fontFamily: 'Cairo'))),
              DataColumn(label: Text('الأهداف', style: TextStyle(fontFamily: 'Cairo'))),
              DataColumn(label: Text('حد الائتمان', style: TextStyle(fontFamily: 'Cairo'))),
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

