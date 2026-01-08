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
        return buyerName.contains(query) || buyerPhone.contains(query);
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

  // دالة مساعدة لترجمة حالة الكاش باك
  String _translateCashbackStatus(String? status) {
    switch (status) {
      case 'confirmed': return 'مؤكد ✅';
      case 'pending': return 'قيد الانتظار ⏳';
      case 'cancelled': return 'ملغى ❌';
      default: return status ?? '—';
    }
  }

  Future<void> _exportToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Orders'];

    sheetObject.appendRow([
      TextCellValue('التاريخ'),
      TextCellValue('المشتري'),
      TextCellValue('الهاتف'),
      TextCellValue('الإجمالي'),
      TextCellValue('صافي الربح'),
      TextCellValue('الحالة'),
      TextCellValue('المنتجات'),
    ]);

    for (var doc in filteredOrders) {
      var data = doc.data() as Map<String, dynamic>;
      var items = (data['items'] as List?)?.map((i) => "${i['name']} (${i['quantity']})").join(' - ') ?? '';

      sheetObject.appendRow([
        TextCellValue(_formatDate(data['orderDate'])),
        TextCellValue(data['buyer']?['name'] ?? ''),
        TextCellValue(data['buyer']?['phone'] ?? ''),
        TextCellValue(data['total']?.toString() ?? '0'),
        TextCellValue(data['netTotal']?.toString() ?? '0'),
        TextCellValue(_getStatusName(data['status'])),
        TextCellValue(items),
      ]);
    }

    if (kIsWeb) {
      excel.save(fileName: "Orders_Detailed_Report.xlsx");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("تقرير الطلبات التفصيلي", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        backgroundColor: const Color(0xFF2c3e50),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.file_download), onPressed: _exportToExcel),
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
                hintText: "بحث باسم العميل أو الهاتف...",
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
                    ? const Center(child: Text("لا توجد طلبات حالياً"))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
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
                                DataCell(Text(_formatDate(data['orderDate']).substring(0, 10))),
                                DataCell(Text(data['buyer']?['name'] ?? 'غير معروف')),
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
                      ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(String orderId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("تفاصيل الطلب المالية واللوجستية\n#$orderId", 
          textAlign: TextAlign.center, 
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("👤 بيانات المشتري"),
                _detailRow("الاسم:", data['buyer']?['name']),
                _detailRow("الهاتف:", data['buyer']?['phone']),
                _detailRow("العنوان:", data['buyer']?['address']),
                
                const Divider(),
                _buildSectionHeader("💰 البيانات المالية"),
                _detailRow("إجمالي الطلب:", "${data['total'] ?? 0} ج.م"),
                _detailRow("طريقة الدفع:", data['paymentMethod'] == 'cod' ? 'كاش' : 'محفظة'),
                _detailRow("نسبة العموله (Snapshot):", "${data['commissionRateSnapshot'] ?? data['commissionRate'] ?? 0}%"),
                _detailRow("الكاش باك المستحق:", "${data['cashbackAmount'] ?? 0} ج.م"),
                _detailRow("حالة الكاش باك:", _translateCashbackStatus(data['cashbackStatus'])),
                _detailRow("المبلغ المستحق للمورد:", "${data['finalAmountToSeller'] ?? 0} ج.م"),
                _detailRow("صافي ربح المنصة (Net Total):", "${data['netTotal'] ?? 0} ج.م"),

                const Divider(),
                _buildSectionHeader("📅 التتبع الزمني"),
                _detailRow("تاريخ الطلب:", _formatDate(data['orderDate'])),
                _detailRow("تاريخ الشحن:", _formatDate(data['shippedDate'])),
                _detailRow("تاريخ التسليم:", _formatDate(data['deliveryDate'])),
                _detailRow("حالة الطلب:", _getStatusName(data['status'])),

                const Divider(),
                _buildSectionHeader("📦 المنتجات"),
                ...((data['items'] as List? ?? []).map((item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: item['imageUrl'] != null 
                    ? Image.network(item['imageUrl'], width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.image))
                    : const Icon(Icons.image),
                  title: Text(item['name'] ?? '', style: const TextStyle(fontSize: 13)),
                  subtitle: Text("الكمية: ${item['quantity']} | السعر: ${item['price']} ج.م", style: const TextStyle(fontSize: 11)),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 14)),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          Text("${value ?? '—'}", style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date is Timestamp) {
      return date.toDate().toString().substring(0, 16);
    }
    return "—";
  }
}

