import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html; // للتحميل في المتصفح

class BuyersPage extends StatefulWidget {
  const BuyersPage({super.key});

  @override
  State<BuyersPage> createState() => _BuyersPageState();
}

class _BuyersPageState extends State<BuyersPage> {
  // نفس الـ API المستخدم في صفحة الإشعارات الترويجية
  final String SEND_API = 'https://o5d9ke4l82.execute-api.us-east-1.amazonaws.com/V1/m_nofiction';

  String _searchQuery = "";
  Map<String, double> _customerPurchases = {};
  List<QueryDocumentSnapshot> _allDocs = [];

  @override
  void initState() {
    super.initState();
    _calculateTotalPurchases();
  }

  // حساب إجمالي المشتريات من الـ Orders
  Future<void> _calculateTotalPurchases() async {
    try {
      final ordersSnapshot = await FirebaseFirestore.instance.collection("orders").get();
      Map<String, double> purchasesMap = {};
      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        final buyerData = data['buyer'] as Map<String, dynamic>?;
        final customerId = buyerData != null ? buyerData['id'] : null;
        final total = (data['total'] as num?)?.toDouble() ?? 0.0;
        if (customerId != null) {
          purchasesMap[customerId] = (purchasesMap[customerId] ?? 0) + total;
        }
      }
      if (mounted) setState(() => _customerPurchases = purchasesMap);
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  // تصدير البيانات (حل مشكلة التحذير باستخدام Blob)
  void _exportToExcel() {
    if (_allDocs.isEmpty) return;
    String csvData = "\uFEFF"; // BOM للعربية
    csvData += "اسم العميل,الهاتف,الكاش باك,المندوب,إجمالي المشتريات,الحالة\n";

    for (var doc in _allDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final totalSpent = _customerPurchases[doc.id] ?? 0.0;
      csvData += "${data['fullname'] ?? '—'},${data['phone'] ?? '—'},${data['cashback'] ?? 0},${data['repName'] ?? 'تسجيل مباشر'},${totalSpent.toStringAsFixed(2)},${data['status'] ?? 'نشط'}\n";
    }

    final bytes = utf8.encode(csvData);
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute("download", "customers_${DateTime.now().millisecondsSinceEpoch}.csv")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        title: const Text("إدارة العملاء", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.file_download), onPressed: _exportToExcel),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBox(),
          Expanded(child: _buildBuyersList()),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: "ابحث بالاسم أو الهاتف...",
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
          filled: true,
          fillColor: Colors.grey[100],
        ),
      ),
    );
  }

  Widget _buildBuyersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("users").orderBy("createdAt", descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        _allDocs = snapshot.data!.docs;
        final filtered = _allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['fullname'] ?? "").toString().contains(_searchQuery) || (data['phone'] ?? "").toString().contains(_searchQuery);
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final id = filtered[index].id;
            final data = filtered[index].data() as Map<String, dynamic>;
            return _buildCustomerCard(id, data);
          },
        );
      },
    );
  }

  Widget _buildCustomerCard(String id, Map<String, dynamic> customer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        title: Text(customer['fullname'] ?? "اسم غير متاح", style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📞 ${customer['phone'] ?? '—'}"),
            Text("💰 كاش باك: ${customer['cashback'] ?? 0} ج.م", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            Text("👤 المندوب: ${customer['repName'] ?? 'تسجيل مباشر'}", style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _showDetails(id, customer),
      ),
    );
  }

  void _showDetails(String id, Map<String, dynamic> customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("تفاصيل العميل", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            const Divider(),
            _detailRow("UID:", id),
            _detailRow("العنوان:", customer['address']),
            _detailRow("تاريخ التسجيل:", _formatDate(customer['createdAt'])),
            const SizedBox(height: 20),
            
            // زر إرسال إشعار (بنفس صيغة صفحة الـ Promo)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text("إرسال إشعار لهذا العميل", style: TextStyle(fontFamily: 'Cairo')),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                onPressed: () => _sendNotificationDialog(id, customer['fullname'] ?? ""),
              ),
            ),
            const SizedBox(height: 10),
            
            // زر تبديل الحالة
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _toggleStatus(id, customer['status']),
                child: Text(customer['status'] == 'inactive' ? "تنشيط الحساب" : "تعطيل الحساب", style: const TextStyle(fontFamily: 'Cairo')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // دايلوج الإرسال المبسط (بنفس الـ API والـ Sound)
  void _sendNotificationDialog(String userId, String userName) {
    final msgCtrl = TextEditingController();
    String selectedSound = 'default';
    bool isSending = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("إشعار إلى $userName", style: const TextStyle(fontSize: 16, fontFamily: 'Cairo')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: msgCtrl,
                maxLines: 3,
                decoration: const InputDecoration(hintText: "اكتب نص الرسالة هنا...", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: selectedSound,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'default', child: Text("نغمة افتراضية")),
                  DropdownMenuItem(value: 'wallet_add', child: Text("نغمة شحن محفظة")),
                  DropdownMenuItem(value: 'promo_msg', child: Text("نغمة عرض ترويجي")),
                ],
                onChanged: (val) => setDialogState(() => selectedSound = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: isSending ? null : () async {
                if (msgCtrl.text.isEmpty) return;
                setDialogState(() => isSending = true);
                
                try {
                  final response = await http.post(
                    Uri.parse(SEND_API),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode({
                      'topic': userId, // نرسل لـ UID الخاص بالعميل كـ Topic
                      'title': "تنبيه من الإدارة 📢",
                      'message': msgCtrl.text,
                      'sound': selectedSound,
                      'data': {
                        'screen': 'Home',
                        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                      }
                    }),
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.statusCode == 200 ? "تم الإرسال" : "فشل الإرسال")));
                } catch (e) {
                  Navigator.pop(ctx);
                }
              },
              child: isSending ? const CircularProgressIndicator() : const Text("إرسال"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [Text(label, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 10), Expanded(child: Text("${value ?? '—'}"))]),
    );
  }

  String _formatDate(dynamic date) {
    if (date is Timestamp) {
      DateTime dt = date.toDate();
      return "${dt.year}-${dt.month}-${dt.day}";
    }
    return "—";
  }

  void _toggleStatus(String id, String? currentStatus) async {
    final newStatus = (currentStatus == 'inactive') ? 'active' : 'inactive';
    await FirebaseFirestore.instance.collection("users").doc(id).update({'status': newStatus});
    if (mounted) Navigator.pop(context);
  }
}

