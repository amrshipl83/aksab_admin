import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PurchaseInvoiceScreen extends StatefulWidget {
  const PurchaseInvoiceScreen({super.key});

  @override
  State<PurchaseInvoiceScreen> createState() => _PurchaseInvoiceScreenState();
}

class _PurchaseInvoiceScreenState extends State<PurchaseInvoiceScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String superAdminId = "vdrX1zA28GWgVjX3ogEQ8zJOeYP2";

  // تحكم عام
  final TextEditingController _supplierController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  int? _nextInvoiceNumber;
  bool _isSaving = false;

  // قائمة المنتجات في الفاتورة
  List<Map<String, dynamic>> _invoiceItems = [];

  // بيانات من Firestore للملفات المنسدلة
  List<DocumentSnapshot> _mainCategories = [];
  Map<String, List<DocumentSnapshot>> _subCategoriesCache = {};
  Map<String, List<DocumentSnapshot>> _productsCache = {};

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _addNewItem(); // إضافة أول سطر منتج تلقائياً
  }

  Future<void> _fetchInitialData() async {
    // جلب رقم الفاتورة القادم
    var counterDoc = await _db.collection('settings').doc('counters').get();
    setState(() {
      _nextInvoiceNumber = (counterDoc.data()?['lastInvoiceNumber'] ?? 0) + 1;
    });

    // جلب الأقسام الرئيسية
    var cats = await _db.collection('mainCategory').get();
    setState(() {
      _mainCategories = cats.docs;
    });
  }

  void _addNewItem() {
    setState(() {
      _invoiceItems.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'mainId': null,
        'subId': null,
        'productId': null,
        'unit': null,
        'quantity': 1,
        'unitPrice': 0.0,
        'sellingPrice': 0.0,
        'total': 0.0,
        'availableSubCats': <DocumentSnapshot>[],
        'availableProducts': <DocumentSnapshot>[],
        'availableUnits': <String>[],
      });
    });
  }

  void _calculateRowTotal(int index) {
    setState(() {
      double q = double.tryParse(_invoiceItems[index]['quantity'].toString()) ?? 0;
      double p = double.tryParse(_invoiceItems[index]['unitPrice'].toString()) ?? 0;
      _invoiceItems[index]['total'] = q * p;
    });
  }

  double _getGrandTotal() {
    return _invoiceItems.fold(0, (sum, item) => sum + (item['total'] ?? 0));
  }

  Future<void> _saveInvoice() async {
    if (_supplierController.text.isEmpty || _invoiceItems.any((i) => i['productId'] == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى ملء كافة البيانات واختيار المنتجات")));
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. تحديث العداد
      await _db.collection('settings').doc('counters').set({
        'lastInvoiceNumber': _nextInvoiceNumber
      }, SetOptions(merge: true));

      // 2. تجهيز البيانات
      final invoiceData = {
        'invoiceNumber': _nextInvoiceNumber,
        'purchaseDate': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'supplierName': _supplierController.text.trim(),
        'totalAmount': _getGrandTotal(),
        'products': _invoiceItems.map((item) => {
          'productId': item['productId'],
          'productName': item['productName'],
          'unit': item['unit'],
          'quantity': item['quantity'],
          'unitPrice': item['unitPrice'],
          'sellingPrice': item['sellingPrice'],
          'total': item['total'],
        }).toList(),
        'timestamp': FieldValue.serverTimestamp(),
        'isProcessed': false,
        'vendorId': superAdminId,
      };

      await _db.collection('purchases').add(invoiceData);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حفظ الفاتورة بنجاح")));
      Navigator.pop(context); // العودة للخلف بعد الحفظ
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ أثناء الحفظ: $e")));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إدخال فاتورة شراء جديدة"), backgroundColor: const Color(0xFF1A2C3D)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 25),
            const Text("تفاصيل المنتجات", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            ..._invoiceItems.asMap().entries.map((entry) => _buildProductRow(entry.key)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _addNewItem,
              icon: const Icon(Icons.add),
              label: const Text("إضافة منتج آخر"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
            const Divider(height: 40),
            _buildFooterSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(child: _buildInfoField("رقم الفاتورة", _nextInvoiceNumber?.toString() ?? "جاري التحميل...", isReadOnly: true)),
          const SizedBox(width: 20),
          Expanded(child: _buildDatePicker()),
          const SizedBox(width: 20),
          Expanded(child: _buildTextField("اسم المورد", _supplierController)),
        ],
      ),
    );
  }

  Widget _buildProductRow(int index) {
    var item = _invoiceItems[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 15,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            // القسم الرئيسي
            _buildDropdown("القسم الرئيسي", _mainCategories, item['mainId'], (val) async {
              setState(() {
                item['mainId'] = val;
                item['subId'] = null;
                item['productId'] = null;
              });
              var subs = await _db.collection('subCategory').where('mainId', '==', val).get();
              setState(() => item['availableSubCats'] = subs.docs);
            }),

            // القسم الفرعي
            _buildDropdown("القسم الفرعي", item['availableSubCats'], item['subId'], (val) async {
              setState(() {
                item['subId'] = val;
                item['productId'] = null;
              });
              var prods = await _db.collection('products').where('subId', '==', val).get();
              setState(() => item['availableProducts'] = prods.docs);
            }),

            // المنتج
            _buildDropdown("المنتج", item['availableProducts'], item['productId'], (val) {
              var selectedProd = (item['availableProducts'] as List<DocumentSnapshot>).firstWhere((element) => element.id == val);
              setState(() {
                item['productId'] = val;
                item['productName'] = selectedProd['name'];
                List unitsData = selectedProd['units'] ?? [];
                item['availableUnits'] = unitsData.map((u) => u['unitName'].toString()).toList();
                item['unit'] = item['availableUnits'].isNotEmpty ? item['availableUnits'][0] : null;
              });
            }),

            // الوحدة
            SizedBox(
              width: 120,
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "الوحدة"),
                value: item['unit'],
                items: (item['availableUnits'] as List<String>).map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (val) => setState(() => item['unit'] = val),
              ),
            ),

            // الكمية وسعر الوحدة
            _buildNumberField("الكمية", (v) {
              item['quantity'] = double.tryParse(v) ?? 0;
              _calculateRowTotal(index);
            }),
            _buildNumberField("سعر الوحدة", (v) {
              item['unitPrice'] = double.tryParse(v) ?? 0;
              _calculateRowTotal(index);
            }),
            _buildNumberField("سعر البيع", (v) {
              item['sellingPrice'] = double.tryParse(v) ?? 0;
            }),

            // الإجمالي والإزالة
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text("الإجمالي: ${item['total'].toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _invoiceItems.removeAt(index))),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("الإجمالي الكلي للفاتورة: ${_getGrandTotal().toStringAsFixed(2)} ج.م", 
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        SizedBox(
          width: 200, height: 50,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveInvoice,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A2C3D)),
            child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("حفظ الفاتورة", style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        )
      ],
    );
  }

  // أدوات مساعدة لبناء الواجهة
  Widget _buildDropdown(String label, List<DocumentSnapshot> items, String? value, Function(String?) onChanged) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: label),
        value: value,
        items: items.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name']))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildNumberField(String label, Function(String) onChanged) {
    return SizedBox(
      width: 100,
      child: TextFormField(
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl) {
    return TextFormField(controller: ctrl, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()));
  }

  Widget _buildInfoField(String label, String value, {bool isReadOnly = false}) {
    return TextFormField(
      initialValue: value,
      readOnly: isReadOnly,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), filled: isReadOnly, fillColor: Colors.grey[200]),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (picked != null) setState(() => _selectedDate = picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(labelText: "تاريخ الشراء", border: OutlineInputBorder()),
        child: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
      ),
    );
  }
}

