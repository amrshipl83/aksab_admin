import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// استيراد الشاشة التي أنشأناها للتو (تأكد من صحة المسار حسب مشروعك)
import '../salary_detail_screen.dart'; 

class RepsView extends StatelessWidget {
  const RepsView({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // نجلب بيانات المناديب من كولكشن salesRep كما في الـ HTML
      stream: FirebaseFirestore.instance.collection('salesRep').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var docs = snapshot.data!.docs;
        
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "لا يوجد مناديب مبيعات حالياً", 
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var rep = docs[index].data() as Map<String, dynamic>;
            var repId = docs[index].id;
            
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 5),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF1A2C3D),
                  child: Icon(Icons.badge, color: Colors.white),
                ),
                // الاسم يعمل كرابط (Link) لفتح تفاصيل الراتب والأداء
                title: InkWell(
                  onTap: () => _navigateToSalary(context, repId, rep['fullname'] ?? ''),
                  child: Text(
                    rep['fullname'] ?? 'بدون اسم',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "كود المندوب: ${rep['repCode'] ?? 'في انتظار التفعيل'}",
                      style: const TextStyle(fontFamily: 'Cairo'),
                    ),
                    Text(
                      rep['email'] ?? '', 
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_left),
                // الضغط على أي مكان في الكارت يفتح أيضاً صفحة الرواتب
                onTap: () => _navigateToSalary(context, repId, rep['fullname'] ?? ''),
              ),
            );
          },
        );
      },
    );
  }

  // هذه الدالة هي البديل المباشر لـ <a href="salary.html?id=...&type=rep">
  void _navigateToSalary(BuildContext context, String id, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SalaryDetailScreen(
          employeeId: id,
          employeeType: 'rep', // تحديد النوع كـ مندوب مبيعات
        ),
      ),
    );
  }
}

