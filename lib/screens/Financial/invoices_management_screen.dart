import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
        var data = doc.data();
        // نستخدم المفاتيح المتوفرة في سجل التاجر
        tempNames[doc.id] = data['supermarketName'] ?? data['merchantName'] ?? 'تاجر غير مسمى';
      }
      if (mounted) setState(() => _sellerNames = tempNames);
    } catch (e) {
      debugPrint("خطأ في جلب أسماء التجار: $e");
    }
  }

  // دالة معالجة العملة المطورة لمنع الشاشة الرمادية
  String formatCurrency(dynamic amount) {
    try {
      double value = 0.0;
      if (amount is num) {
        value = amount.toDouble();
      } else if (amount is String) {
        value = double.tryParse(amount) ?? 0.0;
      }
      return NumberFormat.currency(locale: 'ar_EG', symbol: 'ج.م', decimalDigits: 2).format(value);
    } catch (e) {
      return "0.00 ج.م";
    }
  }

  String formatDate(dynamic dateValue) {
    try {
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
    } catch (e) {
      return "--";
    }
  }

  String getStatusText(String status) {
    switch (status) {
      case 'pending': return 'مستحقة';
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
        title: const Text("إدارة الفواتير", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFB30000),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilters(),
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
              hintText: "البحث عن تاجر...",
              prefixIcon: const Icon(Icons.search, color: Color(0xFFB30000)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 10),
          DropdownButton<String>(
            isExpanded: true,
            value: _selectedStatus,
            items: ['جميع الحالات', 'pending', 'paid', 'cancelled']
                .map((s) => DropdownMenuItem(value: s, child: Text(getStatusText(s), style: const TextStyle(fontFamily: 'Cairo'))))
                .toList(),
            onChanged: (val) => setState(() => _selectedStatus = val!),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('invoices').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) 
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) 
          return Center(child: Text("خطأ: ${snapshot.error}"));

        // معالجة البيانات داخل try-catch لمنع انهيار الشاشة
        try {
          var docs = snapshot.data?.docs ?? [];
          var filtered = docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            bool matchStatus = _selectedStatus == 'جميع الحالات' || (data['status'] ?? 'pending') == _selectedStatus;
            
            String sId = data['sellerId']?.toString() ?? data['ownerId']?.toString() ?? "";
            String sName = (_sellerNames[sId] ?? "").toLowerCase();
            bool matchSearch = sName.contains(_searchQuery.toLowerCase()) || sId.contains(_searchQuery.toLowerCase());
            
            return matchStatus && matchSearch;
          }).toList();

          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              var data = filtered[index].data() as Map<String, dynamic>;
              String status = data['status'] ?? 'pending';
              String sId = data['sellerId']?.toString() ?? data['ownerId']?.toString() ?? "unknown";
              String displayName = _sellerNames[sId] ?? 'تاجر: ${sId.length > 5 ? sId.substring(0, 5) : sId}';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: status == 'paid' ? Colors.green : Colors.orange,
                    child: const Icon(Icons.receipt, color: Colors.white, size: 18),
                  ),
                  title: Text(displayName, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: Text("${formatCurrency(data['finalAmount'])} | ${getStatusText(status)}", style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          _infoLine("تاريخ الفاتورة", formatDate(data['creationDate'])),
                          _infoLine("المعرف", filtered[index].id),
                          if (status == 'pending') ...[
                            const Divider(),
                            Row(
                              children: [
                                Expanded(child: _actionBtn("سداد نقدي", Colors.green, () => _markAsPaid(filtered[index].id))),
                                const SizedBox(width: 8),
                                Expanded(child: _actionBtn("رابط دفع", const Color(0xFFB30000), () => _openPayLink(filtered[index].id))),
                              ],
                            )
                          ]
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        } catch (e) {
          return Center(child: Text("حدث خطأ في عرض البيانات: $e"));
        }
      },
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Cairo')),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _actionBtn(String title, Color col, VoidCallback onTop) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: col, foregroundColor: Colors.white),
      onPressed: onTop,
      child: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
    );
  }

  void _openPayLink(String id) async {
    final url = "https://paymob-test-link.com/pay/$id"; // رابط تجريبي لبكرة
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _markAsPaid(String id) async {
    await _db.collection('invoices').doc(id).update({
      'status': 'paid',
      'paymentMethod': 'Manual_Cash',
      'paymentDate': DateTime.now().toIso8601String()
    });
  }
}

