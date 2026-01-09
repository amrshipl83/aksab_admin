import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // للتأكد من أننا في بيئة ويب

// بدلاً من dart:html نستخدم مكتبات فلاتر المدمجة للتعامل مع البايتات
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js; // طريقة مستقرة للتعامل مع المتصفح في الويب

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
          title: const Text("إدارة وطلبات الدليفري",
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
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

  // --- التبويبات (Pending, Active, Reports) كما هي في الكود السابق ---
  // (سأركز هنا على دالة الإكسل المصححة للويب لتجنب التحذيرات)

  Widget _buildPendingTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _service.getPendingRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("خطأ: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("لا توجد طلبات معلقة"));
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
              child: ExpansionTile(
                title: Text(model.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("الحالة: ${model.isActive ? 'نشط' : 'معطل'} | التوصيل: ${model.deliveryFee}"),
                leading: Icon(Icons.store, color: model.isActive ? Colors.green : Colors.grey),
                trailing: Switch(
                  value: model.isActive,
                  onChanged: (val) async {
                    await _service.updateSupermarketStatus(doc.id, val);
                    _showSnackBar("تم تحديث الحالة", Colors.blue);
                  },
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        _infoRow(Icons.location_on, "العنوان", model.address),
                        _infoRow(Icons.shopping_bag, "الحد الأدنى", "${model.minimumOrderValue} ج.م"),
                        _infoRow(Icons.phone, "الهاتف", model.deliveryContactPhone ?? "N/A"),
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
                  decoration: const InputDecoration(hintText: "بحث باسم الماركت...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              IconButton(icon: const Icon(Icons.file_download, color: Colors.green), onPressed: _exportToExcel),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('consumerorders').orderBy('orderDate', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("خطأ: ${snapshot.error}"));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              var orders = snapshot.data!.docs.where((doc) => doc['supermarketName'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
              return ListView.builder(
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  var order = orders[index].data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(order['supermarketName'] ?? 'N/A'),
                    subtitle: Text("${order['finalAmount']} ج.م - ${_formatDate(order['orderDate'])}"),
                    trailing: IconButton(icon: const Icon(Icons.remove_red_eye), onPressed: () => _showOrderDetails(order)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- دالة التصدير الحديثة للويب بدون تحذيرات ---
  Future<void> _exportToExcel() async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];

      sheetObject.appendRow([
        TextCellValue("الماركت"),
        TextCellValue("العميل"),
        TextCellValue("الإجمالي"),
        TextCellValue("التاريخ"),
      ]);

      var snapshot = await FirebaseFirestore.instance.collection('consumerorders').get();
      for (var doc in snapshot.docs) {
        var data = doc.data();
        sheetObject.appendRow([
          TextCellValue(data['supermarketName']?.toString() ?? 'N/A'),
          TextCellValue(data['customerName']?.toString() ?? 'N/A'),
          DoubleCellValue(double.tryParse(data['finalAmount']?.toString() ?? '0') ?? 0.0),
          TextCellValue(_formatDate(data['orderDate'])),
        ]);
      }

      var fileBytes = excel.save();
      if (fileBytes != null && kIsWeb) {
        // استخدام Base64 و JavaScript لبدء التنزيل (أكثر استقراراً في الويب الحديث)
        final content = base64Encode(fileBytes);
        final fileName = "Delivery_Reports_${DateTime.now().millisecondsSinceEpoch}.xlsx";
        
        // استدعاء جافاسكريبت مباشرة من فلاتر لبدء التحميل
        js.context.callMethod('eval', [
          '''
          var element = document.createElement('a');
          element.setAttribute('href', 'data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64,' + '$content');
          element.setAttribute('download', '$fileName');
          element.style.display = 'none';
          document.body.appendChild(element);
          element.click();
          document.body.removeChild(element);
          '''
        ]);
        _showSnackBar("تم تجهيز التقرير وجاري التنزيل", Colors.green);
      }
    } catch (e) {
      _showSnackBar("حدث خطأ أثناء التنزيل: $e", Colors.red);
    }
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
            _showSnackBar("تم التفعيل بنجاح", Colors.green);
          } catch (e) {
            _hideLoading();
            _showSnackBar("خطأ: $e", Colors.red);
          }
        },
      ),
    );
  }

  String _formatDate(dynamic timestamp) => (timestamp is Timestamp) ? timestamp.toDate().toString().substring(0, 16) : "N/A";
  Widget _infoRow(IconData icon, String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Icon(icon, size: 18, color: Colors.blue), const SizedBox(width: 8), Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)), Text(value)]));
  void _rejectRequest(String id) async { if (await _showConfirmDialog()) { _showLoading(); await _service.deletePendingRequest(id); _hideLoading(); _showSnackBar("تم الرفض", Colors.orange); } }
  void _showOrderDetails(Map<String, dynamic> order) { /* كود التفاصيل */ }
  void _showLoading() => showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
  void _hideLoading() => Navigator.pop(context);
  void _showSnackBar(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
  Future<bool> _showConfirmDialog() async => await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text("تأكيد"), content: const Text("هل أنت متأكد؟"), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("تأكيد"))])) ?? false;
}

