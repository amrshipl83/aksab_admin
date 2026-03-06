import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'monthly_finance_details.dart'; // الصفحة التي ستعرض التفاصيل

class FinancialAnalyticsScreen extends StatelessWidget {
  const FinancialAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("الأرشيف المالي", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFFB21F2D), // لون الهوية الخاصة بك
      ),
      body: StreamBuilder<QuerySnapshot>(
        // نجلب المستندات مرتبة حسب التاريخ الأحدث أولاً
        stream: FirebaseFirestore.instance
            .collection('platform_ledger')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("لا توجد بيانات مالية مسجلة حالياً", 
                style: TextStyle(fontFamily: 'Cairo', fontSize: 16)),
            );
          }

          // استخراج الشهور الفريدة (Unique Periods) لمنع التكرار في القائمة
          final periods = snapshot.data!.docs
              .map((doc) => (doc.data() as Map<String, dynamic>)['period'] as String)
              .toSet()
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: periods.length,
            itemBuilder: (context, index) {
              return Card(
                elevation: 4,
                margin: const EdgeInsets.bottom(15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFB21F2D),
                    child: Icon(Icons.analytics_outlined, color: Colors.white),
                  ),
                  title: Text(
                    periods[index],
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                  ),
                  subtitle: const Text("عرض ملخص الأرباح والخسائر", 
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
                  onTap: () {
                    // الانتقال لصفحة التفاصيل وتمرير الفترة المختارة
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MonthlyFinanceDetails(selectedPeriod: periods[index]),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

