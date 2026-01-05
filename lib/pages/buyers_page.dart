import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:html' as html; // مكتبة التعامل مع المتصفح للتحميل

class BuyersPage extends StatefulWidget {
  const BuyersPage({super.key});

  @override
  State<BuyersPage> createState() => _BuyersPageState();
}

class _BuyersPageState extends State<BuyersPage> {
  String _searchQuery = "";
  Map<String, double> _customerPurchases = {};
  List<QueryDocumentSnapshot> _allDocs = []; // لتخزين البيانات من أجل التصدير

  @override
  void initState() {
    super.initState();
    _calculateTotalPurchases();
  }

  // حساب إجمالي مشتريات كل عميل من مجموعة orders
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

      if (mounted) {
        setState(() {
          _customerPurchases = purchasesMap;
        });
      }
    } catch (e) {
      debugPrint("Error calculating purchases: $e");
    }
  }

  // دالة تصدير البيانات إلى ملف CSV متوافق مع Excel
  void _exportToExcel() {
    if (_allDocs.isEmpty) return;

    // إضافة BOM لضمان ظهور اللغة العربية بشكل صحيح في Excel
    String csvData = "\uFEFF";
    csvData += "اسم العميل,الهاتف,البريد الإلكتروني,العنوان,إجمالي المشتريات,الحالة\n";

    for (var doc in _allDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final id = doc.id;
      final name = data['fullname'] ?? "غير معروف";
      final phone = data['phone'] ?? "غير متاح";
      final email = data['email'] ?? "غير متاح";
      final address = (data['address'] ?? "غير متاح").toString().replaceAll(',', '-'); // تنظيف الفواصل
      final totalSpent = _customerPurchases[id] ?? 0.0;
      final status = data['status'] ?? "نشط";

      csvData += "$name,$phone,$email,$address,${totalSpent.toStringAsFixed(2)},$status\n";
    }

    final bytes = Uri.encodeComponent(csvData);
    html.AnchorElement(href: "data:text/csv;charset=utf-8,$bytes")
      ..setAttribute("download", "customers_report_${DateTime.now().day}_${DateTime.now().month}.csv")
      ..click();
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

        _allDocs = snapshot.data!.docs; // حفظ البيانات لغرض التصدير

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
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(customer['fullname'] ?? "اسم غير متاح", 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Tajawal')),
                ),
                _buildStatusBadge(status),
              ],
            ),
            const Divider(height: 25),
            _infoRow(Icons.phone, customer['phone'] ?? "لا يوجد هاتف", Colors.blue),
            const SizedBox(height: 8),
            _infoRow(Icons.shopping_bag, "مشتريات: ${totalSpent.toStringAsFixed(2)} ج.م", Colors.green),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _showDetails(id, customer),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: const BorderSide(color: Color(0xFF1F2937)),
                ),
                child: const Text("عرض كامل البيانات", style: TextStyle(color: Color(0xFF1F2937))),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.green;
    String text = "نشط";
    if (status == 'inactive') { color = Colors.grey; text = "معطل"; }
    else if (status == 'vip') { color = Colors.orange; text = "VIP"; }
    else if (status == 'new') { color = Colors.blue; text = "جديد"; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  void _showDetails(String id, Map<String, dynamic> customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: Text("تفاصيل العميل", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            const SizedBox(height: 20),
            _detailItem("الاسم:", customer['fullname']),
            _detailItem("البريد:", customer['email']),
            _detailItem("الهاتف:", customer['phone']),
            _detailItem("العنوان:", customer['address']),
            _detailItem("تاريخ التسجيل:", _formatDate(customer['createdAt'])),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: customer['status'] == 'inactive' ? Colors.green : Colors.red,
                ),
                onPressed: () => _toggleStatus(id, customer['status']),
                child: Text(customer['status'] == 'inactive' ? "تنشيط الحساب" : "تعطيل الحساب", 
                  style: const TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _detailItem(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 15),
          children: [
            TextSpan(text: "$label ", style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: "${value ?? 'غير متاح'}"),
          ],
        ),
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
}

