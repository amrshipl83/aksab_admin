import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MerchantPayoutsScreen extends StatefulWidget {
  static const String routeName = '/merchant-payouts';
  const MerchantPayoutsScreen({super.key}); // إضافة الـ Key لضمان الاستقرار

  @override
  _MerchantPayoutsScreenState createState() => _MerchantPayoutsScreenState();
}

class _MerchantPayoutsScreenState extends State<MerchantPayoutsScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: const Text('مستحقات الديفيرى (تسوية الموردين)', 
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.blueGrey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          )
        ],
      ),
      body: _isProcessing 
          ? const Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummarySection(),
                  const SizedBox(height: 30),
                  _buildMainContent(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummarySection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('deliverySupermarkets').snapshots(),
      builder: (context, snapshot) {
        double totalDebt = 0;
        int activeMerchants = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              double val = (data['awaiting_verification'] ?? 0).toDouble();
              if (val > 0) {
                totalDebt += val;
                activeMerchants++;
              }
            } catch (e) { continue; }
          }
        }
        return Row(
          children: [
            _statCard("إجمالي الأمانات المستحقة", "${totalDebt.toStringAsFixed(2)} ج.م", Icons.monetization_on, Colors.orange),
            const SizedBox(width: 20),
            _statCard("موردين بانتظار التسوية", "$activeMerchants مورد", Icons.storefront, Colors.blue),
          ],
        );
      },
    );
  }

  Widget _buildMainContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text("قائمة التسويات الجاهزة للسداد", 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
          ),
          StreamBuilder<QuerySnapshot>(
            // تعديل: شلنا الـ .where عشان نمنع الشاشة الرصاصي
            stream: FirebaseFirestore.instance.collection('deliverySupermarkets').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("خطأ: ${snapshot.error}"));
              if (!snapshot.hasData) return const LinearProgressIndicator();

              // فلترة يدوية آمنة للويب
              final allDocs = snapshot.data!.docs;
              final filteredDocs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final val = data['awaiting_verification'] ?? 0;
                return (val is num && val > 0);
              }).toList();

              if (filteredDocs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(child: Text("لا يوجد مستحقات حالياً - السيستم نظيف ✅")),
                );
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal, // مهم جداً للويب عشان الجدول ميكسرش
                child: DataTable(
                  headingRowHeight: 60,
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                  columns: const [
                    DataColumn(label: Text('المعرف')),
                    DataColumn(label: Text('السوبر ماركت')),
                    DataColumn(label: Text('المبلغ')),
                    DataColumn(label: Text('التاريخ')),
                    DataColumn(label: Text('الإجراء')),
                  ],
                  rows: filteredDocs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DataRow(cells: [
                      DataCell(Text(doc.id.substring(0, 5), style: const TextStyle(color: Colors.grey))),
                      DataCell(Text(data['supermarketName'] ?? 'غير معروف', style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(20)),
                        child: Text("${data['awaiting_verification']} ج.م", style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold)),
                      )),
                      DataCell(Text(_formatDate(data['updatedAt']))),
                      DataCell(ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600]),
                        onPressed: () => _confirmPayment(doc.id, data['supermarketName'] ?? 'مورد', data['awaiting_verification']),
                        child: const Text("تأكيد السداد", style: TextStyle(color: Colors.white)),
                      )),
                    ]);
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _confirmPayment(String mId, String mName, dynamic amount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.orange), SizedBox(width: 10), Text("تأكيد سداد")]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("هل استلمت الأمانات فعلياً من:"),
            Text(mName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
            const SizedBox(height: 10),
            Text("المبلغ: $amount ج.م", style: const TextStyle(fontSize: 16)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("تراجع")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isProcessing = true);
              await _sendToEC2(mId, mName, amount);
              setState(() => _isProcessing = false);
            },
            child: const Text("نعم، تم"),
          )
        ],
      ),
    );
  }

  Future<void> _sendToEC2(String id, String name, dynamic amt) async {
    try {
      await FirebaseFirestore.instance.collection('payoutRequests').add({
        'merchantId': id,
        'merchantName': name,
        'amount': (amt as num).toDouble(),
        'status': 'pending',
        'method': 'Cash_Payment',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ تم إرسال أمر التسوية..")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ خطأ: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
            const SizedBox(width: 15),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ])
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return "-";
    if (ts is Timestamp) {
      var d = ts.toDate();
      return "${d.day}/${d.month}";
    }
    return ts.toString();
  }
}
