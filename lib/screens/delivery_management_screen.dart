import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/delivery_service.dart';
import '../widgets/request_card.dart';
import '../widgets/add_products_dialog.dart';
import '../models/supermarket_model.dart';

class DeliveryManagementScreen extends StatefulWidget {
  const DeliveryManagementScreen({super.key});

  @override
  State<DeliveryManagementScreen> createState() => _DeliveryManagementScreenState();
}

class _DeliveryManagementScreenState extends State<DeliveryManagementScreen> {
  final DeliveryService _service = DeliveryService();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("إدارة وطلبات الدليفري"),
          centerTitle: true,
          bottom: const TabBar(
            isScrollable: false,
            tabs: [
              Tab(text: "طلبات معلقة"),
              Tab(text: "سوبر ماركتات"),
              Tab(text: "تقارير الطلبات"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPendingTab(),   // التبويب الأول: المعلقين
            _buildActiveTab(),    // التبويب الثاني: المفعلين
            _buildReportsTab(),   // التبويب الثالث: التقارير
          ],
        ),
      ),
    );
  }

  // 1. تبويب الطلبات المعلقة
  Widget _buildPendingTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _service.getPendingRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("لا توجد طلبات تفعيل دليفري معلقة حالياً"));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 10),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var model = SupermarketModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
            return RequestCard(
              request: model,
              onApprove: () => _openApprovalDialog(model),
              onReject: () => _rejectRequest(model.id),
            );
          },
        );
      },
    );
  }

  // 2. تبويب السوبر ماركتات المفعلة
  Widget _buildActiveTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _service.getActiveSupermarkets(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("لا توجد سوبر ماركتات مفعلة حالياً"));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            bool isActive = data['isActive'] ?? true;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text(data['supermarketName'] ?? 'غير معروف', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("الحالة الحالية: ${isActive ? 'نشط' : 'معطل'}"),
                trailing: Switch(
                  value: isActive,
                  onChanged: (val) async {
                    await _service.updateSupermarketStatus(doc.id, val);
                    _showSnackBar("تم تحديث حالة السوبر ماركت", Colors.blue);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 3. تبويب تقارير الطلبات (بجدول بيانات)
  Widget _buildReportsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('consumerorders')
          .orderBy('orderDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("لا توجد تقارير طلبات حالياً"));
        }

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text("الماركت")),
                DataColumn(label: Text("الإجمالي")),
                DataColumn(label: Text("التاريخ")),
                DataColumn(label: Text("التفاصيل")),
              ],
              rows: snapshot.data!.docs.map((doc) {
                var order = doc.data() as Map<String, dynamic>;
                return DataRow(cells: [
                  DataCell(Text(order['supermarketName'] ?? 'N/A')),
                  DataCell(Text("${order['finalAmount']} ج.م")),
                  DataCell(Text(order['orderDate'] != null 
                    ? (order['orderDate'] as Timestamp).toDate().toString().substring(0, 16) 
                    : 'N/A')),
                  DataCell(IconButton(
                    icon: const Icon(Icons.remove_red_eye, color: Colors.blue),
                    onPressed: () => _showOrderDetails(order),
                  )),
                ]);
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // --- دوال التحكم والمناطق المنبثقة ---

  void _openApprovalDialog(SupermarketModel request) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddProductsDialog(
        supermarketId: request.id,
        supermarketName: request.name,
        onConfirm: (selectedProducts) async {
          Navigator.pop(context);
          _showLoading();
          try {
            await _service.approveRequest(
              request.id, request.name, request.address, request.deliveryFee, selectedProducts
            );
            _hideLoading();
            _showSnackBar("تمت الموافقة وتفعيل السوبر ماركت", Colors.green);
          } catch (e) {
            _hideLoading();
            _showSnackBar("خطأ: $e", Colors.red);
          }
        },
      ),
    );
  }

  void _rejectRequest(String requestId) async {
    bool confirm = await _showConfirmDialog();
    if (confirm) {
      _showLoading();
      await _service.deletePendingRequest(requestId);
      _hideLoading();
      _showSnackBar("تم رفض الطلب", Colors.orange);
    }
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تفاصيل الطلب"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("العميل: ${order['customerName'] ?? 'غير معروف'}"),
            Text("العنوان: ${order['customerAddress'] ?? 'غير متوفر'}"),
            const Divider(),
            const Text("المنتجات:", style: TextStyle(fontWeight: FontWeight.bold)),
            ...? (order['items'] as List?)?.map((item) => Text("- ${item['name']} x ${item['quantity']}")),
            const Divider(),
            Text("الإجمالي النهائي: ${order['finalAmount']} ج.م", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("إغلاق"))],
      ),
    );
  }

  // --- دوال المساعدة العامة ---

  void _showLoading() => showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
  void _hideLoading() => Navigator.pop(context);
  void _showSnackBar(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));

  Future<bool> _showConfirmDialog() async {
    return await showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("تأكيد"),
      content: const Text("هل أنت متأكد من رفض هذا الطلب؟"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("تأكيد الرفض")),
      ],
    )) ?? false;
  }
}

