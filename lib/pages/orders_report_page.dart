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

  void _applyFilter() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      filteredOrders = allOrders.where((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String buyerName = data['buyer']?['name']?.toString().toLowerCase() ?? '';
        String buyerPhone = data['buyer']?['phone']?.toString().toLowerCase() ?? '';
        String sellerName = data['items'] != null && (data['items'] as List).isNotEmpty 
            ? (data['items'][0]['sellerName'] ?? '').toString().toLowerCase() : '';
        return buyerName.contains(query) || buyerPhone.contains(query) || sellerName.contains(query);
      }).toList();
    });
  }

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

  // --- دالة التصدير المطورة بشيتين ---
  Future<void> _exportToExcel() async {
    var excel = Excel.createExcel();
    
    // 1. شيت ملخص الطلبات
    Sheet ordersSheet = excel['ملخص الطلبات'];
    ordersSheet.appendRow([
      TextCellValue('التاريخ'),
      TextCellValue('رقم الطلب'),
      TextCellValue('المشتري'),
      TextCellValue('الهاتف'),
      TextCellValue('المورد (التاجر)'),
      TextCellValue('الإجمالي'),
      TextCellValue('طريقة الدفع'),
      TextCellValue('صافي الربح'),
      TextCellValue('الحالة'),
    ]);

    // 2. شيت تحليل الأصناف المباعة (كل صنف في سطر)
    Sheet itemsSheet = excel['تحليل المبيعات - أصناف'];
    itemsSheet.appendRow([
      TextCellValue('اسم المنتج'),
      TextCellValue('الكمية'),
      TextCellValue('الوحدة'),
      TextCellValue('السعر'),
      TextCellValue('إجمالي الصنف'),
      TextCellValue('المورد'),
      TextCellValue('رقم الطلب'),
      TextCellValue('التاريخ'),
    ]);

    for (var doc in filteredOrders) {
      var data = doc.data() as Map<String, dynamic>;
      var itemsList = data['items'] as List?;
      String pMethod = data['paymentMethod'] ?? '';
      String paymentText = (pMethod == 'cash_on_delivery' || pMethod == 'cod') ? 'كاش' : 'محفظة';
      String firstSeller = (itemsList != null && itemsList.isNotEmpty) ? itemsList[0]['sellerName'] ?? '—' : '—';

      // إضافة للطلبات
      ordersSheet.appendRow([
        TextCellValue(_formatDate(data['orderDate'])),
        TextCellValue(doc.id),
        TextCellValue(data['buyer']?['name'] ?? ''),
        TextCellValue(data['buyer']?['phone'] ?? ''),
        TextCellValue(firstSeller),
        TextCellValue(data['total']?.toString() ?? '0'),
        TextCellValue(paymentText),
        TextCellValue(data['netTotal']?.toString() ?? '0'),
        TextCellValue(_getStatusName(data['status'])),
      ]);

      // إضافة للأصناف
      if (itemsList != null) {
        for (var item in itemsList) {
          double price = (item['price'] as num?)?.toDouble() ?? 0.0;
          int qty = (item['quantity'] as num?)?.toInt() ?? 0;
          itemsSheet.appendRow([
            TextCellValue(item['name'] ?? '—'),
            TextCellValue(qty.toString()),
            TextCellValue(item['unit'] ?? '—'),
            TextCellValue(price.toString()),
            TextCellValue((price * qty).toString()),
            TextCellValue(item['sellerName'] ?? firstSeller),
            TextCellValue(doc.id),
            TextCellValue(_formatDate(data['orderDate'])),
          ]);
        }
      }
    }

    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

    if (kIsWeb) {
      excel.save(fileName: "Aksab_Report_${DateTime.now().day}_${DateTime.now().month}.xlsx");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إدارة وتقرير الطلبات", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2c3e50),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.file_download), onPressed: _exportToExcel, tooltip: "تصدير التقرير الشامل"),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: "بحث باسم العميل، المورد أو الهاتف...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (v) => _applyFilter(),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredOrders.isEmpty
                    ? const Center(child: Text("لا توجد نتائج"))
                    : _buildOrdersTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.grey[200]),
          columns: const [
            DataColumn(label: Text('التاريخ')),
            DataColumn(label: Text('المشتري')),
            DataColumn(label: Text('المورد')),
            DataColumn(label: Text('المبلغ')),
            DataColumn(label: Text('الحالة')),
            DataColumn(label: Text('الإجراءات')),
          ],
          rows: filteredOrders.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            var items = data['items'] as List?;
            return DataRow(cells: [
              DataCell(Text(_formatDate(data['orderDate']).substring(0, 10))),
              DataCell(Text(data['buyer']?['name'] ?? '—')),
              DataCell(Text(items != null && items.isNotEmpty ? items[0]['sellerName'] ?? '—' : '—')),
              DataCell(Text("${data['total']} EGP")),
              DataCell(Text(_getStatusName(data['status']))),
              DataCell(ElevatedButton(
                onPressed: () => _showOrderDetails(doc.id, data),
                child: const Text("التفاصيل"),
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  void _showOrderDetails(String orderId, Map<String, dynamic> data) {
    String pMethod = data['paymentMethod'] ?? '';
    String paymentText = (pMethod == 'cash_on_delivery' || pMethod == 'cod') ? 'كاش (عند الاستلام)' : 'محفظة / إلكتروني';
    var itemsList = data['items'] as List?;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("تفاصيل طلب: #$orderId", textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', fontSize: 16)),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader("👤 بيانات العميل"),
                _detailRow("الاسم:", data['buyer']?['name']),
                _detailRow("الهاتف:", data['buyer']?['phone']),
                _detailRow("العنوان:", data['buyer']?['address']),
                
                const Divider(),
                _sectionHeader("🏪 بيانات المورد"),
                _detailRow("اسم التاجر:", (itemsList != null && itemsList.isNotEmpty) ? itemsList[0]['sellerName'] : 'غير متوفر'),
                
                const Divider(),
                _sectionHeader("💰 الحسابات المالية"),
                _detailRow("إجمالي المبلغ:", "${data['total'] ?? 0} ج.م"),
                _detailRow("طريقة الدفع:", paymentText),
                _detailRow("كاش باك مستقطع:", "${data['cashbackAmount'] ?? 0} ج.م"),
                _detailRow("صافي ربح المنصة:", "${data['netTotal'] ?? 0} ج.م"),

                const Divider(),
                _sectionHeader("📦 الأصناف المطلوبة"),
                ...((itemsList ?? []).map((item) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.blueGrey[50],
                  child: ListTile(
                    leading: item['imageUrl'] != null ? Image.network(item['imageUrl'], width: 40) : const Icon(Icons.shopping_bag),
                    title: Text(item['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text("الكمية: ${item['quantity']} | الوحدة: ${item['unit'] ?? '—'}", style: const TextStyle(fontSize: 12)),
                    trailing: Text("${(item['price'] ?? 0) * (item['quantity'] ?? 1)} ج.م"),
                  ),
                ))),
                const SizedBox(height: 10),
                _detailRow("تاريخ الطلب:", _formatDate(data['orderDate'])),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إغلاق"))],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2c3e50))),
  );

  Widget _detailRow(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Text("${value ?? '—'}", style: const TextStyle(fontSize: 13)),
      ],
    ),
  );

  String _formatDate(dynamic date) {
    if (date is Timestamp) return date.toDate().toString().substring(0, 16);
    return "—";
  }
}

