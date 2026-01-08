import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
// لتجنب التحذير (Warning) يفضل استخدام 'package:web/web.dart' في المستقبل
// ولكن حالياً سنبقي على الحل المتوافق مع المتصفح للتحميل
import 'dart:html' as html; 

class BuyersPage extends StatefulWidget {
  const BuyersPage({super.key});

  @override
  State<BuyersPage> createState() => _BuyersPageState();
}

class _BuyersPageState extends State<BuyersPage> {
  String _searchQuery = "";
  Map<String, double> _customerPurchases = {};
  List<QueryDocumentSnapshot> _allDocs = [];

  @override
  void initState() {
    super.initState();
    _calculateTotalPurchases();
  }

  // حساب إجمالي المشتريات
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

  // تصدير البيانات لـ Excel (CSV)
  void _exportToExcel() {
    if (_allDocs.isEmpty) return;
    String csvData = "\uFEFF"; // BOM لدعم العربية
    csvData += "اسم العميل,الهاتف,البريد الإلكتروني,العنوان,الكاش باك,إجمالي المشتريات,الحالة\n";

    for (var doc in _allDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final id = doc.id;
      final name = data['fullname'] ?? "غير معروف";
      final phone = data['phone'] ?? "غير متاح";
      final email = data['email'] ?? "غير متاح";
      final address = (data['address'] ?? "غير متاح").toString().replaceAll(',', '-');
      final cashback = data['cashback'] ?? 0;
      final totalSpent = _customerPurchases[id] ?? 0.0;
      final status = data['status'] ?? "نشط";

      csvData += "$name,$phone,$email,$address,$cashback,${totalSpent.toStringAsFixed(2)},$status\n";
    }

    final bytes = utf8.encode(csvData);
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute("download", "customers_report_${DateTime.now().millisecondsSinceEpoch}.csv")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        title: const Text("إدارة العملاء", style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportToExcel,
            tooltip: "تصدير للتميز",
          ),
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
          hintText: "ابحث باسم العميل أو الهاتف...",
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
        if (snapshot.hasError) return const Center(child: Text("حدث خطأ في جلب البيانات"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        _allDocs = snapshot.data!.docs;
        final filteredDocs = _allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['fullname'] ?? "").toString().toLowerCase();
          final phone = (data['phone'] ?? "").toString();
          return name.contains(_searchQuery.toLowerCase()) || phone.contains(_searchQuery);
        }).toList();

        if (filteredDocs.isEmpty) return const Center(child: Text("لا يوجد نتائج للبحث"));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final customer = filteredDocs[index].data() as Map<String, dynamic>;
            final id = filteredDocs[index].id;
            return _buildCustomerCard(id, customer);
          },
        );
      },
    );
  }

  Widget _buildCustomerCard(String id, Map<String, dynamic> customer) {
    final totalSpent = _customerPurchases[id] ?? 0.0;
    final status = customer['status'] ?? 'active';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: Colors.blueGrey[100], child: Text(customer['fullname']?[0] ?? "U")),
                const SizedBox(width: 12),
                Expanded(child: Text(customer['fullname'] ?? "اسم غير متاح", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                _buildStatusBadge(status),
              ],
            ),
            const Divider(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _infoChip(Icons.phone, customer['phone'] ?? "—", Colors.blue),
                _infoChip(Icons.account_balance_wallet, "${customer['cashback'] ?? 0} ج.م", Colors.orange),
                _infoChip(Icons.shopping_cart, "${totalSpent.toStringAsFixed(0)} ج.م", Colors.green),
              ],
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showDetails(id, customer),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F2937), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text("التفاصيل وإرسال إشعار", style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 4), Text(text, style: const TextStyle(fontSize: 12))]);
  }

  // --- المنبثقة المطورة ---
  void _showDetails(String id, Map<String, dynamic> customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: Text("بيانات العميل التفصيلية", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            const Divider(height: 30),
            _detailItem("الرقم التعريفي (UID):", id),
            _detailItem("الاسم:", customer['fullname']),
            _detailItem("الهاتف:", customer['phone']),
            _detailItem("العنوان:", customer['address']),
            _detailItem("الكاش باك الحالي:", "${customer['cashback'] ?? 0} ج.م"),
            _detailItem("المندوب المسجل:", customer['repName'] ?? "تسجيل ذاتي"),
            _detailItem("تاريخ التسجيل:", _formatDate(customer['createdAt'])),
            const SizedBox(height: 20),
            
            // زر إرسال الإشعار (Notification via ARN)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.notifications_active),
                label: const Text("إرسال إشعار خاص (Push Notification)"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800], foregroundColor: Colors.white),
                onPressed: () => _sendNotificationDialog(customer),
              ),
            ),
            const SizedBox(height: 10),
            
            // زر تغيير الحالة
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: customer['status'] == 'inactive' ? Colors.green : Colors.red),
                onPressed: () => _toggleStatus(id, customer['status']),
                child: Text(customer['status'] == 'inactive' ? "تنشيط الحساب" : "تعطيل الحساب"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // دالة إرسال الإشعار (هنا تربطها بـ AWS SNS / ARN)
  void _sendNotificationDialog(Map<String, dynamic> customer) {
    final titleCtrl = TextEditingController(text: "أهلاً ${customer['fullname']}");
    final bodyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("إرسال إشعار عبر ARN"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "عنوان الإشعار")),
            TextField(controller: bodyCtrl, decoration: const InputDecoration(labelText: "نص الرسالة")),
            const SizedBox(height: 10),
            Text("Target ARN: ${customer['fcmToken'] != null ? 'متوفر' : 'غير متوفر'}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () async {
              // منطق الإرسال الخاص بك هنا
              // عادة يتم استدعاء Cloud Function ترسل لـ AWS SNS باستخدام الـ Token/ARN
              debugPrint("Sending to ARN: ${customer['fcmToken']}");
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("جاري معالجة إرسال الإشعار...")));
            },
            child: const Text("إرسال الآن"),
          ),
        ],
      ),
    );
  }

  Widget _detailItem(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 10),
          Expanded(child: Text("${value ?? 'غير متوفر'}", style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date is Timestamp) {
      DateTime dt = date.toDate();
      return "${dt.year}-${dt.month}-${dt.day}";
    }
    return "غير متوفر";
  }

  void _toggleStatus(String id, String? currentStatus) async {
    final newStatus = (currentStatus == 'inactive') ? 'active' : 'inactive';
    await FirebaseFirestore.instance.collection("users").doc(id).update({'status': newStatus});
    if (mounted) Navigator.pop(context);
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.green;
    if (status == 'inactive') color = Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Text(status == 'inactive' ? "معطل" : "نشط", style: const TextStyle(color: Colors.white, fontSize: 10)),
    );
  }
}

