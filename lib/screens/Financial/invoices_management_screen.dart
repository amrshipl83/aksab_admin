import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class InvoicesManagementScreen extends StatefulWidget {
  const InvoicesManagementScreen({super.key});

  @override
  State<InvoicesManagementScreen> createState() => _InvoicesManagementScreenState();
}

class _InvoicesManagementScreenState extends State<InvoicesManagementScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _selectedStatus = 'جميع الحالات';
  String _searchQuery = '';
  Map<String, String> _sellerNames = {};

  @override
  void initState() {
    super.initState();
    _loadSellers();
  }

  // جلب أسماء التجار لربطها بالـ ID
  Future<void> _loadSellers() async {
    final snapshot = await _db.collection('sellers').get();
    Map<String, String> tempNames = {};
    for (var doc in snapshot.docs) {
      tempNames[doc.id] = doc.data()['supermarketName'] ?? 'تاجر غير معروف';
    }
    setState(() => _sellerNames = tempNames);
  }

  String formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'ar_EG', symbol: 'ج.م').format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text("إدارة الفواتير والتحصيل", style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: const Color(0xFFB30000),
      ),
      body: Column(
        children: [
          _buildFilters(),
          _buildCashRequests(), // قسم طلبات الكاش المعلقة
          Expanded(child: _buildInvoicesList()),
        ],
      ),
    );
  }

  // 1. قسم الفلاتر (البحث والحالة)
  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: "بحث باسم التاجر...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 10),
          DropdownButton<String>(
            value: _selectedStatus,
            items: ['جميع الحالات', 'pending', 'paid', 'cancelled']
                .map((s) => DropdownMenuItem(value: s, child: Text(s == 'pending' ? 'مستحقة' : s == 'paid' ? 'تم السداد' : s)))
                .toList(),
            onChanged: (val) => setState(() => _selectedStatus = val!),
          ),
        ],
      ),
    );
  }

  // 2. طلبات التحصيل النقدي (Cash Requests)
  Widget _buildCashRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('cash_collection_requests').where('status', isEqualTo: 'new').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
        return Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("⚠️ طلبات تحصيل نقدي جديدة:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
              ...snapshot.data!.docs.map((doc) {
                var data = doc.data() as Map<String, dynamic>;
                return ListTile(
                  title: Text(_sellerNames[data['sellerId']] ?? 'تاجر #${data['sellerId']}'),
                  subtitle: Text("المبلغ: ${formatCurrency(data['amount'].toDouble())}"),
                  trailing: ElevatedButton(
                    onPressed: () => _processCashRequest(doc.id, data['invoiceId']),
                    child: const Text("تم التحصيل"),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // 3. قائمة الفواتير
  Widget _buildInvoicesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('invoices').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        var invoices = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          bool matchStatus = _selectedStatus == 'جميع الحالات' || data['status'] == _selectedStatus;
          bool matchSearch = _sellerNames[data['sellerId']]?.contains(_searchQuery) ?? true;
          return matchStatus && matchSearch;
        }).toList();

        return ListView.builder(
          itemCount: invoices.length,
          itemBuilder: (context, index) {
            var data = invoices[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: data['status'] == 'paid' ? Colors.green : Colors.red,
                  child: const Icon(Icons.receipt, color: Colors.white),
                ),
                title: Text(_sellerNames[data['sellerId']] ?? 'تاجر غير معروف'),
                subtitle: Text("المبلغ: ${formatCurrency(data['finalAmount'].toDouble())}\nالحالة: ${data['status']}"),
                trailing: data['status'] == 'pending' 
                  ? ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () => _markAsPaid(invoices[index].id),
                      child: const Text("سداد نقدي", style: TextStyle(color: Colors.white)),
                    )
                  : const Icon(Icons.check_circle, color: Colors.green),
              ),
            );
          },
        );
      },
    );
  }

  // إجراء تسجيل السداد
  Future<void> _markAsPaid(String id) async {
    bool confirm = await _showConfirmDialog();
    if (confirm) {
      await _db.collection('invoices').doc(id).update({
        'status': 'paid',
        'paymentDate': DateTime.now().toIso8601String(),
        'paymentMethod': 'Manual_Cash_Admin'
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ تم تسجيل السداد بنجاح")));
    }
  }

  Future<void> _processCashRequest(String reqId, String invId) async {
    await _db.collection('cash_collection_requests').doc(reqId).update({'status': 'processed'});
    _markAsPaid(invId);
  }

  Future<bool> _showConfirmDialog() async {
    return await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد السداد"),
        content: const Text("هل تم استلام المبلغ نقداً من التاجر؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("تأكيد")),
        ],
      ),
    ) ?? false;
  }
}

