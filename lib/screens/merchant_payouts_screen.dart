
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
        title: const Text('تسويات أمانات وأرباح اكسب',
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
                  _buildMerchantContent(), // جدول الموردين
                  const SizedBox(height: 30),
                  _buildDriverWithdrawContent(), // جدول المناديب الجديد
                ],
              ),
            ),
    );
  }

  // --- قسم الإحصائيات العلوي ---
  Widget _buildSummarySection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('deliverySupermarkets').snapshots(),
      builder: (context, snapshot) {
        double totalDebt = 0;
        int activeMerchants = 0;

        if (snapshot.hasData && snapshot.data != null) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>?;
            num val = data?['awaiting_verification'] ?? 0;
            if (val > 0) {
              totalDebt += val.toDouble();
              activeMerchants++;
            }
          }
        }

        return Row(
          children: [
            _statCard("إجمالي أمانات الموردين", "${totalDebt.toStringAsFixed(0)} ج.م", Icons.account_balance_wallet, Colors.red),
            const SizedBox(width: 20),
            _statCard("موردين بانتظار التسوية", "$activeMerchants مورد", Icons.storefront, Colors.blueGrey),
          ],
        );
      },
    );
  }

  // --- 1️⃣ جدول الموردين (Merchants) ---
  Widget _buildMerchantContent() {
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
            child: Text("أمانات الموردين الجاهزة للتحصيل",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[800], fontFamily: 'Cairo')),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('deliverySupermarkets')
                .where('awaiting_verification', '>', 0)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text("خطأ في البيانات"));
              if (!snapshot.hasData) return const LinearProgressIndicator();

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("لا توجد مديونيات حالياً ✅")));

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('المورد')),
                    DataColumn(label: Text('المبلغ')),
                    DataColumn(label: Text('الإجراء')),
                  ],
                  rows: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final amount = data['awaiting_verification'] ?? 0;
                    return DataRow(cells: [
                      DataCell(Text(data['supermarketName'] ?? '..')),
                      DataCell(Text("$amount ج.م", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                      DataCell(ElevatedButton(
                        onPressed: () => _confirmMerchantPayout(doc.id, data['supermarketName'] ?? 'مورد', amount),
                        child: const Text("تأكيد استلام"),
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

  // --- 2️⃣ جدول المناديب (Drivers) ---
  Widget _buildDriverWithdrawContent() {
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
            child: Text("طلبات سحب أرباح المناديب",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[800], fontFamily: 'Cairo')),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('withdrawRequests')
                .where('status', '==', 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("لا توجد طلبات سحب معلقة ✅")));

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('المندوب')),
                    DataColumn(label: Text('المبلغ')),
                    DataColumn(label: Text('الإجراء')),
                  ],
                  rows: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DataRow(cells: [
                      DataCell(Text(data['driverName'] ?? 'مندوب اكسب')),
                      DataCell(Text("${data['amount']} ج.م", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                      DataCell(ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
                        onPressed: () => _confirmDriverWithdraw(doc.id, data['driverName'] ?? 'المندوب', data['amount']),
                        child: const Text("موافقة وصرف", style: TextStyle(color: Colors.white)),
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

  // --- وظائف التأكيد والإرسال ---

  void _confirmMerchantPayout(String id, String name, dynamic amt) {
    String method = 'نقدي';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("سداد مورد"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("تأكيد استلام مبلغ $amt ج.م من $name؟"),
              DropdownButtonFormField<String>(
                value: method,
                items: ['نقدي', 'فودافون كاش', 'تحويل بنكي'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => method = v!),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("تراجع")),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await FirebaseFirestore.instance.collection('payoutRequests').add({
                  'merchantId': id,
                  'merchantName': name,
                  'amount': (amt as num).toDouble(),
                  'method': method,
                  'status': 'pending',
                  'createdAt': FieldValue.serverTimestamp(),
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ جاري معالجة سداد المورد")));
              },
              child: const Text("تم الاستلام"),
            )
          ],
        ),
      ),
    );
  }

  void _confirmDriverWithdraw(String docId, String name, dynamic amt) {
    String method = 'فودافون كاش';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("صرف أرباح مندوب"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("هل قمت بتحويل $amt ج.م لـ $name؟"),
              DropdownButtonFormField<String>(
                value: method,
                items: ['فودافون كاش', 'نقدي', 'محفظة بنكية'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => method = v!),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("تراجع")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
              onPressed: () async {
                Navigator.pop(context);
                // المندوب بتبعت الحالة 'approved' عشان محرك الـ EC2 يخصم الرصيد
                await FirebaseFirestore.instance.collection('withdrawRequests').doc(docId).update({
                  'status': 'approved',
                  'paymentMethod': method,
                  'approvedAt': FieldValue.serverTimestamp(),
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ تم الموافقة وجاري الخصم من المحفظة")));
              },
              child: const Text("تم الصرف", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2))),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Cairo')),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ])
          ],
        ),
      ),
    );
  }
}

