import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class OrdersReportPage extends StatefulWidget {
  const OrdersReportPage({super.key});

  @override
  State<OrdersReportPage> createState() => _OrdersReportPageState();
}

class _OrdersReportPageState extends State<OrdersReportPage> {
  final TextEditingController _searchController = TextEditingController();
  List<QueryDocumentSnapshot> allOrders = [];
  List<QueryDocumentSnapshot> filteredOrders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  // جلب الطلبات من Firestore بترتيب التاريخ
  void _fetchOrders() {
    FirebaseFirestore.instance
        .collection('orders')
        .orderBy('orderDate', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          allOrders = snapshot.docs;
          _applyFilter();
          isLoading = false;
        });
      }
    });
  }

  // منطق الفلترة (مثل الويب تماماً)
  void _applyFilter() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      filteredOrders = allOrders.where((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String buyerName = data['buyer']?['name']?.toString().toLowerCase() ?? '';
        String buyerPhone = data['buyer']?['phone']?.toString().toLowerCase() ?? '';
        return buyerName.contains(query) || buyerPhone.contains(query);
      }).toList();
    });
  }

  // تحويل الحالة إلى نص عربي
  String _getStatusName(String? status) {
    switch (status) {
      case 'new-order': return 'طلب جديد';
      case 'processing': return 'قيد التجهيز';
      case 'shipped': return 'تم الشحن';
      case 'delivered': return 'تم التسليم';
      case 'cancelled': return 'ملغى';
      default: return status ?? 'غير محدد';
    }
  }

  // تصدير الطلبات إلى إكسل
  Future<void> _exportToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Orders'];

    sheetObject.appendRow([
      TextCellValue('التاريخ'),
      TextCellValue('المشتري'),
      TextCellValue('الهاتف'),
      TextCellValue('الإجمالي'),
      TextCellValue('الحالة'),
      TextCellValue('المنتجات'),
    ]);

    for (var doc in filteredOrders) {
      var data = doc.data() as Map<String, dynamic>;
      var items = (data['items'] as List?)?.map((i) => "${i['name']} (${i['quantity']})").join(' - ') ?? '';
      
      sheetObject.appendRow([
        TextCellValue(data['orderDate'] != null ? (data['orderDate'] as Timestamp).toDate().toString() : ''),
        TextCellValue(data['buyer']?['name'] ?? ''),
        TextCellValue(data['buyer']?['phone'] ?? ''),
        TextCellValue(data['total']?.toString() ?? '0'),
        TextCellValue(_getStatusName(data['status'])),
        TextCellValue(items),
      ]);
    }

    if (kIsWeb) {
      excel.save(fileName: "Orders_Report.xlsx");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("تقرير الطلبات"),
        backgroundColor: const Color(0xFF2c3e50),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.file_download), onPressed: _exportToExcel),
        ],
      ),
      body: Column(
        children: [
          // منطقة البحث (تجاوب كامل)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      hintText: "بحث باسم العميل أو الهاتف...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (v) => _applyFilter(),
                  ),
                ),
              ],
            ),
          ),

          // عرض النتائج (تجاوب: جدول للويب وCards للموبايل أو جدول قابل للتمرير)
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredOrders.isEmpty
                    ? const Center(child: Text("لا توجد طلبات حالياً"))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal, // لتوافق الجداول العريضة
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(Colors.grey[200]),
                            columns: const [
                              DataColumn(label: Text('التاريخ')),
                              DataColumn(label: Text('المشتري')),
                              DataColumn(label: Text('المبلغ')),
                              DataColumn(label: Text('الحالة')),
                              DataColumn(label: Text('الإجراءات')),
                            ],
                            rows: filteredOrders.map((doc) {
                              var data = doc.data() as Map<String, dynamic>;
                              return DataRow(cells: [
                                DataCell(Text(data['orderDate'] != null 
                                    ? (data['orderDate'] as Timestamp).toDate().toString().substring(0, 16) 
                                    : '-')),
                                DataCell(Text(data['buyer']?['name'] ?? 'غير معروف')),
                                DataCell(Text("${data['total']} EGP")),
                                DataCell(Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(_getStatusName(data['status'])),
                                )),
                                DataCell(ElevatedButton(
                                  onPressed: () => _showOrderDetails(doc.id, data),
                                  child: const Text("التفاصيل"),
                                )),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // نافذة عرض التفاصيل (Modal)
  void _showOrderDetails(String orderId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("تفاصيل الطلب #$orderId", textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
        content: SizedBox(
          width: 600, // أقصى عرض للكمبيوتر
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow("العميل:", data['buyer']?['name']),
                _detailRow("الهاتف:", data['buyer']?['phone']),
                _detailRow("العنوان:", data['buyer']?['address']),
                const Divider(),
                const Text("المنتجات:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...((data['items'] as List? ?? []).map((item) => ListTile(
                      leading: Image.network(item['imageUrl'] ?? '', width: 40, errorBuilder: (c, e, s) => const Icon(Icons.image)),
                      title: Text(item['name'] ?? ''),
                      subtitle: Text("الكمية: ${item['quantity']} | السعر: ${item['price']}"),
                    ))),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إغلاق")),
        ],
      ),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text("$label ${value ?? 'غير محدد'}", textAlign: TextAlign.right),
    );
  }
}

