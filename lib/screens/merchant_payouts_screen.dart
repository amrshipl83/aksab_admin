import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MerchantPayoutsScreen extends StatefulWidget {
  static const String routeName = '/merchant-payouts';
  const MerchantPayoutsScreen({super.key});

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
        
        if (snapshot.hasData && snapshot.data != null) {
          for (var doc in snapshot.data!.docs) {
            try {
              final data = doc.data() as Map<String, dynamic>?;
              if (data == null) continue;
              
              // تأمين قراءة الرقم بمرونة (int أو double)
              num val = data['awaiting_verification'] ?? 0;
              if (val > 0) {
                totalDebt += val.toDouble();
                activeMerchants++;
              }
            } catch (e) {
              debugPrint("Error parsing summary doc: $e");
            }
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
            stream: FirebaseFirestore.instance.collection('deliverySupermarkets').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("حدث خطأ في البيانات"));
              if (!snapshot.hasData) return const LinearProgressIndicator();

              // فلترة يدوية مؤمنة ضد الـ Null والـ Types
              final filteredDocs = snapshot.data!.docs.where((doc) {
                try {
                  final data = doc.data() as Map<String, dynamic>?;
                  if (data == null) return false;
                  final val = data['awaiting_verification'];
                  return (val is num && val > 0);
                } catch (e) {
                  return false;
                }
              }).toList();

              if (filteredDocs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(child: Text("لا يوجد مستحقات حالياً ✅")),
                );
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('المعرف')),
                    DataColumn(label: Text('السوبر ماركت')),
                    DataColumn(label: Text('المبلغ')),
                    DataColumn(label: Text('التاريخ')),
                    DataColumn(label: Text('الإجراء')),
                  ],
                  rows: filteredDocs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final amount = data['awaiting_verification'] ?? 0;
                    
                    return DataRow(cells: [
                      DataCell(Text(doc.id.length > 5 ? doc.id.substring(0, 5) : doc.id)),
                      DataCell(Text(data['supermarketName']?.toString() ?? 'غير معروف')),
                      DataCell(Text("$amount ج.م", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                      DataCell(Text(_formatDate(data['updatedAt']))),
                      DataCell(ElevatedButton(
                        onPressed: () => _confirmPayment(doc.id, data['supermarketName']?.toString() ?? 'مورد', amount),
                        child: const Text("تأكيد السداد"),
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

  // --- دوال المساعدة المؤمّنة ---
  
  void _confirmPayment(String mId, String mName, dynamic amount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد سداد"),
        content: Text("هل استلمت $amount ج.م من $mName؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("تراجع")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isProcessing = true);
              await _sendToEC2(mId, mName, amount);
              setState(() => _isProcessing = false);
            },
            child: const Text("تم السداد"),
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
        'createdAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ تم الإرسال")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ خطأ: $e")));
    }
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(12), 
          border: Border.all(color: color.withOpacity(0.2))
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ])
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts is Timestamp) {
      return "${ts.toDate().day}/${ts.toDate().month}";
    }
    return "-";
  }
}
