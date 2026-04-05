import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// تأكد من استيراد الثوابت والـ Providers الخاصة بمشروعك هنا
// import 'package:aksab_admin/constants/colors.dart'; 

class MerchantPayoutsScreen extends StatefulWidget {
  static const String routeName = '/merchant-payouts';

  @override
  _MerchantPayoutsScreenState createState() => _MerchantPayoutsScreenState();
}

class _MerchantPayoutsScreenState extends State<MerchantPayoutsScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7F9), // لون خلفية هادئ للويب
      appBar: AppBar(
        title: Text('مستحقات الديفيرى (تسوية الموردين)', 
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.blueGrey[900],
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          )
        ],
      ),
      body: _isProcessing 
          ? Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummarySection(),
                  SizedBox(height: 30),
                  _buildMainContent(),
                ],
              ),
            ),
    );
  }

  // --- 1. قسم الملخص العلوي ---
  Widget _buildSummarySection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('deliverySupermarkets').snapshots(),
      builder: (context, snapshot) {
        double totalDebt = 0;
        int activeMerchants = 0;
        if (snapshot.hasData) {
          activeMerchants = snapshot.data!.docs.where((d) => (d['awaiting_verification'] ?? 0) > 0).length;
          for (var doc in snapshot.data!.docs) {
            totalDebt += (doc['awaiting_verification'] ?? 0).toDouble();
          }
        }
        return Row(
          children: [
            _statCard("إجمالي الأمانات المستحقة", "${totalDebt.toStringAsFixed(2)} ج.م", Icons.monetization_on, Colors.orange),
            SizedBox(width: 20),
            _statCard("موردين بانتظار التسوية", "$activeMerchants مورد", Icons.storefront, Colors.blue),
          ],
        );
      },
    );
  }

  // --- 2. الجدول المركزي (عرض البيانات) ---
  Widget _buildMainContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
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
            stream: FirebaseFirestore.instance
                .collection('deliverySupermarkets')
                .where('awaiting_verification', '>', 0)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return LinearProgressIndicator();
              if (snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Center(child: Text("لا يوجد مستحقات حالياً - السيستم نظيف ✅")),
                );
              }

              return DataTable(
                headingRowHeight: 60,
                dataRowHeight: 70,
                headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                columns: [
                  DataColumn(label: Text('المعرف المرجعي')),
                  DataColumn(label: Text('المورد / السوبر ماركت')),
                  DataColumn(label: Text('المبلغ المجمع')),
                  DataColumn(label: Text('تاريخ آخر عملية')),
                  DataColumn(label: Text('الإجراء المالي')),
                ],
                rows: snapshot.data!.docs.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return DataRow(cells: [
                    DataCell(SelectableText(doc.id.substring(0, 8) + "...", style: TextStyle(color: Colors.grey))),
                    DataCell(Text(data['supermarketName'] ?? 'غير معروف', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(20)),
                      child: Text("${data['awaiting_verification']} ج.م", style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold)),
                    )),
                    DataCell(Text(_formatDate(data['updatedAt']))),
                    DataCell(ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], padding: EdgeInsets.symmetric(horizontal: 20)),
                      onPressed: () => _confirmPayment(doc.id, data['supermarketName'], data['awaiting_verification']),
                      child: Text("تأكيد استلام الأمانات"),
                    )),
                  ]);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- 3. منطق التأكيد والإرسال للمستمع ---
  void _confirmPayment(String mId, String mName, dynamic amount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.orange), SizedBox(width: 10), Text("تأكيد سداد")]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("هل استلمت الأمانات فعلياً من:"),
            Text("$mName", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
            SizedBox(height: 10),
            Text("المبلغ: $amount ج.م", style: TextStyle(fontSize: 16)),
            Divider(),
            Text("بمجرد التأكيد، سيتم تحديث محفظة المورد وإرسال إشعار فوري له.", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("تراجع")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isProcessing = true);
              await _sendToEC2(mId, mName, amount);
              setState(() => _isProcessing = false);
            },
            child: Text("نعم، تم السداد"),
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
        'status': 'pending', // المفتاح اللي بيشغل ملف payout_monitor.js
        'method': 'Cash_Payment',
        'adminId': 'Master_Admin', 
        'createdAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ تم إرسال أمر التسوية للمستمع.. لحظات وسيختفي المورد من القائمة")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ خطأ في الإرسال: $e"), backgroundColor: Colors.red));
    }
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
            SizedBox(width: 15),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: Colors.grey, fontSize: 14)),
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ])
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return "غير محدد";
    if (ts is Timestamp) {
      var d = ts.toDate();
      return "${d.day}/${d.month} ${d.hour}:${d.minute}";
    }
    return ts.toString();
  }
}

