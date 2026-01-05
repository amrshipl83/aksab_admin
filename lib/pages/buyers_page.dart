import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BuyersPage extends StatefulWidget {
  const BuyersPage({super.key});

  @override
  State<BuyersPage> createState() => _BuyersPageState();
}

class _BuyersPageState extends State<BuyersPage> {
  String _searchQuery = "";
  Map<String, double> _customerPurchases = {};

  @override
  void initState() {
    super.initState();
    _calculateTotalPurchases();
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        title: const Text("إدارة العملاء", style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildSearchAndStats(),
          Expanded(
            child: _buildBuyersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: "ابحث باسم العميل أو الهاتف...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("users").orderBy("createdAt", descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("حدث خطأ ما"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['fullname'] ?? "").toString().toLowerCase();
          final phone = (data['phone'] ?? "").toString();
          return name.contains(_searchQuery.toLowerCase()) || phone.contains(_searchQuery);
        }).toList();

        if (docs.isEmpty) return const Center(child: Text("لا يوجد عملاء مطابقين"));

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final customer = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;
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
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const Divider(),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(customer['phone'] ?? "لا يوجد هاتف"),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.shopping_cart, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                // تم استبدال NumberFormat بطريقة يدوية لضمان عمل الكود
                Text("إجمالي المشتريات: ${totalSpent.toStringAsFixed(2)} ج.م",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showDetails(id, customer, totalSpent),
                icon: const Icon(Icons.info_outline),
                label: const Text("التفاصيل والتحكم"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F2937),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            )
          ],
        ),
      ),
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
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  void _showDetails(String id, Map<String, dynamic> customer, double totalSpent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("بيانات العميل", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
            const SizedBox(height: 20),
            _detailRow(Icons.email, "البريد:", customer['email'] ?? "غير متاح"),
            _detailRow(Icons.location_on, "العنوان:", customer['address'] ?? "غير متاح"),
            _detailRow(Icons.calendar_today, "تاريخ الانضمام:", _formatDate(customer['createdAt'])),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: customer['status'] == 'inactive' ? Colors.green : Colors.red,
                    ),
                    onPressed: () => _toggleStatus(id, customer['status']),
                    child: Text(customer['status'] == 'inactive' ? "تنشيط الحساب" : "تعطيل الحساب", style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 5),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return "غير معروف";
    if (date is Timestamp) {
      DateTime dt = date.toDate();
      return "${dt.year}-${dt.month}-${dt.day}";
    }
    return date.toString();
  }

  void _toggleStatus(String id, String? currentStatus) async {
    final newStatus = (currentStatus == 'inactive') ? 'active' : 'inactive';
    await FirebaseFirestore.instance.collection("users").doc(id).update({'status': newStatus});
    if (mounted) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم تحديث حالة العميل إلى $newStatus")));
  }
}

