import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html; 

class BuyersPage extends StatefulWidget {
  const BuyersPage({super.key});

  @override
  State<BuyersPage> createState() => _BuyersPageState();
}

class _BuyersPageState extends State<BuyersPage> {
  // الروابط الخاصة بالـ API لديك (نفس الموجودة في صفحة التسويق)
  final String SEND_API = 'https://o5d9ke4l82.execute-api.us-east-1.amazonaws.com/V1/m_nofiction';

  String _searchQuery = "";
  Map<String, double> _customerPurchases = {};
  List<QueryDocumentSnapshot> _allDocs = [];

  @override
  void initState() {
    super.initState();
    _calculateTotalPurchases();
  }

  // حساب إجمالي مشتريات كل عميل
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
      debugPrint("Error calculating purchases: $e");
    }
  }

  // تصدير البيانات (حل مشكلة التحذير مع الحفاظ على كل الحقول)
  void _exportToExcel() {
    if (_allDocs.isEmpty) return;
    String csvData = "\uFEFF"; 
    csvData += "الاسم,الهاتف,البريد,العنوان,المندوب,الكاش باك,المشتريات,الحالة\n";

    for (var doc in _allDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final totalSpent = _customerPurchases[doc.id] ?? 0.0;
      csvData += "${data['fullname'] ?? '—'},${data['phone'] ?? '—'},${data['email'] ?? '—'},${data['address'] ?? '—'},${data['repName'] ?? 'تسجيل مباشر'},${data['cashback'] ?? 0},${totalSpent.toStringAsFixed(2)},${data['status'] ?? 'نشط'}\n";
    }

    final bytes = utf8.encode(csvData);
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute("download", "buyers_report_${DateTime.now().day}.csv")
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
          IconButton(icon: const Icon(Icons.file_download), onPressed: _exportToExcel, tooltip: "تصدير"),
        ],
      ),
      body: Column(
        children: [_buildSearchBox(), Expanded(child: _buildBuyersList())],
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
          final name = (data['fullname'] ?? "").toString().toLowerCase();
          final phone = (data['phone'] ?? "").toString();
          return name.contains(_searchQuery.toLowerCase()) || phone.contains(_searchQuery);
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: filtered.length,
          itemBuilder: (context, index) => _buildCustomerCard(filtered[index].id, filtered[index].data() as Map<String, dynamic>),
        );
      },
    );
  }

  Widget _buildCustomerCard(String id, Map<String, dynamic> customer) {
    final totalSpent = _customerPurchases[id] ?? 0.0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        title: Text(customer['fullname'] ?? "اسم غير متاح", style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📞 ${customer['phone'] ?? '—'} | 💰 كاش: ${customer['cashback'] ?? 0}"),
            Text("👤 المندوب: ${customer['repName'] ?? 'تسجيل مباشر'}", style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showDetails(id, customer),
      ),
    );
  }

  // --- المنبثقة الشاملة بكل الحقول ---
  void _showDetails(String id, Map<String, dynamic> customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("تفاصيل العميل الكاملة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              const Divider(height: 30),
              _fullDetailItem("UID", id),
              _fullDetailItem("الاسم الكامل", customer['fullname']),
              _fullDetailItem("رقم الهاتف", customer['phone']),
              _fullDetailItem("البريد الإلكتروني", customer['email']),
              _fullDetailItem("العنوان الحالي", customer['address']),
              _fullDetailItem("الكاش باك", "${customer['cashback'] ?? 0} ج.م"),
              _fullDetailItem("إجمالي المشتريات", "${(_customerPurchases[id] ?? 0).toStringAsFixed(2)} ج.م"),
              _fullDetailItem("المندوب", customer['repName'] ?? "تسجيل مباشر"),
              _fullDetailItem("تاريخ التسجيل", _formatDate(customer['createdAt'])),
              _fullDetailItem("الحالة", customer['status'] ?? "نشط"),
              
              const SizedBox(height: 25),
              
              // زر إرسال الإشعار
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text("إرسال إشعار خاص للعميل", style: TextStyle(fontFamily: 'Cairo')),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.all(12)),
                  onPressed: () => _sendNotificationDialog(id, customer),
                ),
              ),
              const SizedBox(height: 10),
              
              // زر الحالة
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _toggleStatus(id, customer['status']),
                  child: Text(customer['status'] == 'inactive' ? "تنشيط الحساب" : "تعطيل الحساب", style: const TextStyle(fontFamily: 'Cairo')),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- دايلوج الإرسال (مطابق لـ Payload صفحة التسويق) ---
  void _sendNotificationDialog(String userId, Map<String, dynamic> customer) {
    final msgCtrl = TextEditingController();
    String selectedSound = 'default';
    bool isSending = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("إرسال إلى: ${customer['fullname']}", style: const TextStyle(fontSize: 15, fontFamily: 'Cairo')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: msgCtrl,
                maxLines: 3,
                decoration: const InputDecoration(hintText: "نص الرسالة...", border: OutlineInputBorder()),
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
                      // هنا التعديل: نرسل الـ UID كتوبيك، أو إذا كان لديك حقل ARN استخدمه
                      'topic': userId, 
                      'title': "تنبيه من أكسب 💰",
                      'message': msgCtrl.text,
                      'sound': selectedSound,
                      'data': {
                        'screen': 'Home',
                        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                        'image': "", // صورة فارغة
                      }
                    }),
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.statusCode == 200 ? "تم الإرسال بنجاح" : "فشل الإرسال: ${response.body}")));
                } catch (e) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("خطأ في الاتصال")));
                }
              },
              child: isSending ? const CircularProgressIndicator() : const Text("إرسال"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fullDetailItem(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text("$label:", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 13))),
          Expanded(child: Text("${value ?? '—'}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
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

