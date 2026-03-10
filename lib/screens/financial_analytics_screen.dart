import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'monthly_finance_details.dart';

class FinancialAnalyticsScreen extends StatelessWidget {
  const FinancialAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text("الأرشيف المالي - أكسب", 
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFFB21F2D),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('platform_ledger')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFB21F2D)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 80, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("لا توجد بيانات مالية مؤرشفة حالياً في أكسب",
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          // تجميع البيانات لاستخراج صافي الربح لكل شهر (Period)
          Map<String, double> periodProfits = {};
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final period = data['period'] as String;
            final amount = (data['totalAmount'] ?? 0).toDouble();
            final type = data['entryType'] as String;

            if (!periodProfits.containsKey(period)) periodProfits[period] = 0;
            
            if (type == 'revenue') {
              periodProfits[period] = periodProfits[period]! + amount;
            } else if (type == 'expense') {
              periodProfits[period] = periodProfits[period]! - amount;
            }
          }

          final periods = periodProfits.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: periods.length,
            itemBuilder: (context, index) {
              final periodName = periods[index];
              final profit = periodProfits[periodName]!;
              final isProfit = profit >= 0;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MonthlyFinanceDetails(selectedPeriod: periodName),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    child: Row(
                      children: [
                        // أيقونة الحالة (أخضر للربح، أحمر للخسارة)
                        CircleAvatar(
                          backgroundColor: isProfit ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                          child: Icon(
                            isProfit ? Icons.trending_up : Icons.trending_down,
                            color: isProfit ? Colors.green[700] : Colors.red[700],
                          ),
                        ),
                        const SizedBox(width: 15),
                        // اسم الفترة
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                periodName,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                              ),
                              const Text("إجمالي صافي أداء الشهر", 
                                style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        // عرض المبلغ (الصافي) بشكل بارز
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${isProfit ? '+' : ''}${profit.toStringAsFixed(2)} ج.م",
                              style: TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold, 
                                color: isProfit ? Colors.green[700] : Colors.red[700],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

