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

  Future<void> _loadSellers() async {
    try {
      final snapshot = await _db.collection('sellers').get();
      Map<String, String> tempNames = {};
      for (var doc in snapshot.docs) {
        // نستخدم نفس المفاتيح المتفق عليها لضمان الاتساق
        tempNames[doc.id] = doc.data()['supermarketName'] ?? doc.data()['merchantName'] ?? 'تاجر غير معروف';
      }
      if (mounted) setState(() => _sellerNames = tempNames);
    } catch (e) {
      debugPrint("خطأ في جلب أسماء التجار: $e");
    }
  }

  // ✅ إصلاح: معالجة المبالغ سواء كانت String أو Number
  String formatCurrency(dynamic amount) {
    double value = 0.0;
    if (amount is num) {
      value = amount.toDouble();
    } else if (amount is String) {
      value = double.tryParse(amount) ?? 0.0;
    }
    return NumberFormat.currency(locale: 'ar_EG', symbol: 'ج.م', decimalDigits: 2).format(value);
  }

  String formatDate(dynamic dateValue) {
    if (dateValue == null) return '--';
    DateTime dt;
    if (dateValue is Timestamp) {
      dt = dateValue.toDate();
    } else if (dateValue is String) {
      dt = DateTime.tryParse(dateValue) ?? DateTime.now();
    } else {
      return '--';
    }
    return DateFormat('yyyy/MM/dd', 'ar_EG').format(dt);
  }

  String getStatusText(String status) {
    switch (status) {
      case 'pending': return 'مستحقة للدفع';
      case 'paid': return 'تم السداد';
      case 'cancelled': return 'ملغاة';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text("قائمة الفواتير - الإدارة",
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFB30000),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilters(),
          _buildCashRequestsSection(),
          Expanded(child: _buildInvoicesList()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: "البحث باسم أو معرف التاجر...",
              prefixIcon: const Icon(Icons.search, color: Color(0xFFB30000)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text("تصفية: ", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedStatus,
                  items: ['جميع الحالات', 'pending', 'paid', 'cancelled']
                      .map((s) => DropdownMenuItem(value: s, child: Text(getStatusText(s))))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedStatus = val!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCashRequestsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('cash_collection_requests').where('status', isEqualTo: 'new').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3CD),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFEEBA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.local_shipping_outlined, color: Color(0xFF856404)),
                  SizedBox(width: 8),
                  Text("طلبات تحصيل نقدي معلّقة",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF856404))),
                ],
              ),
              const Divider(),
              ...snapshot.data!.docs.map((doc) {
                var data = doc.data() as Map<String, dynamic>;
                String sId = data['sellerId']?.toString() ?? 'unknown';
                String sellerName = _sellerNames[sId] ?? 'تاجر #${sId.length > 5 ? sId.substring(0, 5) : sId}';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text("$sellerName طلب تحصيل ${formatCurrency(data['amount'])}",
                          style: const TextStyle(fontSize: 12))),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC3545),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8)),
                        onPressed: () => _handleCashRequest(doc.id, data['invoiceId']),
                        child: const Text("تم التعامل", style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInvoicesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('invoices').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text("خطأ: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: Text("لا توجد بيانات"));

        var invoices = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          bool matchStatus = _selectedStatus == 'جميع الحالات' || data['status'] == _selectedStatus;
          
          String sId = data['sellerId']?.toString() ?? "";
          String sellerName = _sellerNames[sId]?.toLowerCase() ?? "";
          bool matchSearch = sellerName.contains(_searchQuery.toLowerCase()) || sId.contains(_searchQuery);
          
          return matchStatus && matchSearch;
        }).toList();

        return ListView.builder(
          itemCount: invoices.length,
          itemBuilder: (context, index) {
            var data = invoices[index].data() as Map<String, dynamic>;
            String status = data['status'] ?? 'pending';
            String sId = data['sellerId']?.toString() ?? "unknown";
            String displayName = _sellerNames[sId] ?? 'تاجر #${sId.length > 5 ? sId.substring(0, 5) : sId}';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: status == 'paid' ? Colors.green : (status == 'cancelled' ? Colors.grey : Colors.orange),
                  child: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
                ),
                title: Text(displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text("المبلغ: ${formatCurrency(data['finalAmount'])} | ${getStatusText(status)}",
                    style: const TextStyle(fontSize: 12)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        _buildInfoRow("معرف الفاتورة:", invoices[index].id),
                        _buildInfoRow("تاريخ الإصدار:", formatDate(data['creationDate'])),
                        if (status == 'pending') ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.payments),
                              label: const Text("تسجيل سداد نقدي"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              onPressed: () => _markInvoiceAsPaid(invoices[index].id),
                            ),
                          ),
                        ]
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  // --- دوال التأكيد والتحديث (تظل كما هي مع إضافة معالجة الأخطاء) ---
  Future<void> _handleCashRequest(String requestId, String invoiceId) async {
    bool? confirm = await _showConfirmDialog("تنبيه", "هل تم تحصيل المبلغ أو تحديد موعد؟");
    if (confirm == true) {
      try {
        await _db.collection('cash_collection_requests').doc(requestId).update({'status': 'processed'});
        await _markInvoiceAsPaid(invoiceId);
      } catch (e) {
        debugPrint("خطأ: $e");
      }
    }
  }

  Future<void> _markInvoiceAsPaid(String invoiceId) async {
    bool? confirm = await _showConfirmDialog("تأكيد السداد", "هل أنت متأكد من تسجيل سداد نقدي كامل للفاتورة؟");
    if (confirm == true) {
      try {
        await _db.collection('invoices').doc(invoiceId).update({
          'status': 'paid',
          'paymentDate': DateTime.now().toIso8601String(),
          'paymentMethod': 'Manual_Cash_Admin'
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ تم تسجيل السداد بنجاح")));
      } catch (e) {
        debugPrint("خطأ في التحديث: $e");
      }
    }
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("تأكيد")),
        ],
      ),
    );
  }
}

