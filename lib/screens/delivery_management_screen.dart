import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("إدارة وطلبات الدليفري", style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
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
            _buildPendingTab(),
            _buildActiveTab(),
            _buildReportsTab(),
          ],
        ),
      ),
    );
  }

  // 1. تبويب الطلبات المعلقة (المراجعة قبل التفعيل)
  Widget _buildPendingTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _service.getPendingRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("خطأ: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("لا توجد طلبات معلقة حالياً"));

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

  // 2. تبويب السوبر ماركتات المفعلة (عرض التفاصيل الكاملة)
  Widget _buildActiveTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _service.getActiveSupermarkets(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("خطأ: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("لا توجد ماركتات مفعلة"));

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var model = SupermarketModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              elevation: 2,
              child: ExpansionTile(
                title: Text(model.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("الحالة: ${model.isActive ? 'نشط' : 'معطل'} | التوصيل: ${model.deliveryFee} ج.م"),
                leading: Icon(Icons.store, color: model.isActive ? Colors.green : Colors.grey),
                trailing: Switch(
                  value: model.isActive,
                  onChanged: (val) async {
                    await _service.updateSupermarketStatus(doc.id, val);
                    _showSnackBar("تم تحديث الحالة بنجاح", Colors.blue);
                  },
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        _infoRow(Icons.location_on, "العنوان", model.address),
                        _infoRow(Icons.shopping_bag, "الحد الأدنى", "${model.minimumOrderValue} ج.م"),
                        _infoRow(Icons.access_time, "المواعيد", model.deliveryHours ?? "غير محدد"),
                        _infoRow(Icons.phone, "الهاتف", model.deliveryContactPhone ?? "N/A"),
                        _infoRow(Icons.chat, "واتساب", model.whatsappNumber ?? "N/A"),
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

  // 3. تبويب تقارير الطلبات مع البحث وتصدير الإكسل
  Widget _buildReportsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: "بحث باسم الماركت...",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.file_download, color: Colors.green, size: 30),
                onPressed: _exportToExcel,
                tooltip: "تصدير إلى إكسل",
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('consumerorders').orderBy('orderDate', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("خطأ: ${snapshot.error}"));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              
              var orders = snapshot.data!.docs.where((doc) {
                var name = doc['supermarketName']?.toString().toLowerCase() ?? "";
                return name.contains(_searchQuery.toLowerCase());
              }).toList();

              if (orders.isEmpty) return const Center(child: Text("لا توجد نتائج"));

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
                    rows: orders.map((doc) {
                      var order = doc.data() as Map<String, dynamic>;
                      return DataRow(cells: [
                        DataCell(Text(order['supermarketName'] ?? 'N/A')),
                        DataCell(Text("${order['finalAmount'] ?? 0} ج.م")),
                        DataCell(Text(_formatDate(order['orderDate']))),
                        DataCell(IconButton(icon: const Icon(Icons.remove_red_eye, color: Colors.blue), onPressed: () => _showOrderDetails(order))),
                      ]);
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- وظائف المساعدة ---

  void _openApprovalDialog(SupermarketModel request) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddProductsDialog(
        request: request,
        onConfirm: (products, extraData) async {
          Navigator.pop(context);
          _showLoading();
          try {
            await _service.approveRequest(
              requestId: request.id,
              supermarketName: request.name,
              address: request.address,
              ownerId: request.ownerId ?? request.id,
              products: products,
              extraData: extraData,
            );
            _hideLoading();
            _showSnackBar("تم تفعيل الماركت بنجاح", Colors.green);
          } catch (e) {
            _hideLoading();
            _showSnackBar("خطأ: $e", Colors.red);
          }
        },
      ),
    );
  }

  Future<void> _exportToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];
    sheetObject.appendRow(["الماركت", "العميل", "العنوان", "الإجمالي", "رسوم التوصيل", "التاريخ"]);

    var snapshot = await FirebaseFirestore.instance.collection('consumerorders').get();
    for (var doc in snapshot.docs) {
      var data = doc.data();
      sheetObject.appendRow([
        data['supermarketName'],
        data['customerName'],
        data['customerAddress'],
        data['finalAmount'],
        data['deliveryFee'],
        _formatDate(data['orderDate']),
      ]);
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/Delivery_Reports.xlsx');
    await file.writeAsBytes(excel.save()!);
    Share.shareXFiles([XFile(file.path)], text: 'تقرير مبيعات الدليفري');
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate().toString().substring(0, 16);
    }
    return "N/A";
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [Icon(icon, size: 18, color: Colors.blue), const SizedBox(width: 8), Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)), Text(value)]),
    );
  }

  void _rejectRequest(String id) async {
    bool confirm = await _showConfirmDialog();
    if (confirm) {
      _showLoading();
      await _service.deletePendingRequest(id);
      _hideLoading();
      _showSnackBar("تم الرفض", Colors.orange);
    }
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تفاصيل طلب الدليفري"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("العميل: ${order['customerName']}"),
            Text("الهاتف: ${order['customerPhone'] ?? 'غير متوفر'}"),
            const Divider(),
            const Text("المنتجات:", style: TextStyle(fontWeight: FontWeight.bold)),
            ... (order['items'] as List).map((i) => Text("- ${i['name']} (${i['quantity']})")),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("إغلاق"))],
      ),
    );
  }

  void _showLoading() => showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
  void _hideLoading() => Navigator.pop(context);
  void _showSnackBar(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  Future<bool> _showConfirmDialog() async => await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text("تأكيد"), content: const Text("هل أنت متأكد؟"), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("تأكيد"))])) ?? false;
}

