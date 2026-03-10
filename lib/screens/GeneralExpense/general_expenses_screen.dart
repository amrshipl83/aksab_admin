import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_expense_screen.dart'; // الملف اللي لسه عاملينه

class GeneralExpensesScreen extends StatefulWidget {
  const GeneralExpensesScreen({super.key});

  @override
  State<GeneralExpensesScreen> createState() => _GeneralExpensesScreenState();
}

class _GeneralExpensesScreenState extends State<GeneralExpensesScreen> {
  String _selectedPeriod = ''; // لتصفية المصروفات حسب الشهر لو حبيت

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text("المصروفات العامة - General Expenses", 
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFB21F2D),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. كارت ملخص إجمالي المصاريف
          _buildTotalExpensesHeader(),

          // 2. قائمة المصروفات المسجلة
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text("آخر العمليات المسجلة", 
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('platform_ledger')
                  .where('entryType', isEqualTo: 'expense')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("لا توجد مصروفات مسجلة حالياً", style: TextStyle(fontFamily: 'Cairo')),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    return _buildExpenseCard(data);
                  },
                );
              },
            ),
          ),
        ],
      ),
      // 3. زرار إضافة مصروف جديد
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) =>  AddExpenseScreen()),
          );
        },
        label: const Text("إضافة مصروف", style: TextStyle(fontFamily: 'Cairo')),
        icon: const Icon(Icons.add_shopping_cart),
        backgroundColor: const Color(0xFFB21F2D),
      ),
    );
  }

  // ويلجت لعرض إجمالي المصاريف (Dynamic من الداتا)
  Widget _buildTotalExpensesHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('platform_ledger')
          .where('entryType', isEqualTo: 'expense')
          .snapshots(),
      builder: (context, snapshot) {
        double total = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            total += (doc['totalAmount'] ?? 0).toDouble();
          }
        }
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Column(
            children: [
              const Text("إجمالي ميزانية المصروفات العامة", 
                style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
              const SizedBox(height: 10),
              Text("${total.toStringAsFixed(2)} ج.م", 
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFB21F2D))),
            ],
          ),
        );
      },
    );
  }

  // تصميم الكارت الصغير لكل مصروف في القائمة
  Widget _buildExpenseCard(Map<String, dynamic> data) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.receipt_long, color: Color(0xFFB21F2D)),
        ),
        title: Text(data['details'] ?? 'مصروف غير مسمى', 
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("التصنيف: ${data['source']}", style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
            Text("الفترة: ${data['period']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("-${data['totalAmount']} ج.م", 
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
            // أيقونة تدل على وجود مرفق (صورة)
            if (data['attachmentUrl'] != null)
              const Icon(Icons.attach_file, size: 16, color: Colors.green),
          ],
        ),
        onTap: () {
          // هنا ممكن نفتح صفحة التفاصيل لعرض صورة المستند
          if (data['attachmentUrl'] != null) {
            _showAttachmentDialog(data['attachmentUrl']);
          }
        },
      ),
    );
  }

  // ديالوج بسيط لعرض صورة المستند لما يضغط على المصروف
  void _showAttachmentDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("مستند المصروف", style: TextStyle(fontFamily: 'Cairo')),
            const SizedBox(height: 10),
            Image.network(url, loadingBuilder: (context, child, loading) {
              return loading == null ? child : const CircularProgressIndicator();
            }),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("إغلاق"))],
      ),
    );
  }
}

