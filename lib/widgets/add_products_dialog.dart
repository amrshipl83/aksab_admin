import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/supermarket_model.dart'; // تأكد من استيراد الموديل

class AddProductsDialog extends StatefulWidget {
  final SupermarketModel request; // نمرر الموديل كاملًا بدلاً من الاسم والـ ID فقط
  final Function(List<Map<String, dynamic>>, Map<String, dynamic>) onConfirm; // أضفنا متغير للبيانات المعدلة

  const AddProductsDialog({
    super.key,
    required this.request,
    required this.onConfirm,
  });

  @override
  State<AddProductsDialog> createState() => _AddProductsDialogState();
}

class _AddProductsDialogState extends State<AddProductsDialog> {
  // كونتورلرات لتعديل البيانات الأساسية
  late TextEditingController _feeController;
  late TextEditingController _minOrderController;
  late TextEditingController _hoursController;
  late TextEditingController _phoneController;
  late TextEditingController _whatsappController;

  // متغيرات إضافة المنتجات (النظام الحالي)
  String? selectedMainCat, selectedSubCat, selectedProduct, productName;
  String? selectedUnit;
  List<dynamic> availableUnits = [];
  final TextEditingController _priceController = TextEditingController();
  List<Map<String, dynamic>> currentProductUnits = [];
  List<Map<String, dynamic>> finalProductsToUpload = [];

  @override
  void initState() {
    super.initState();
    // تعبئة البيانات الموجودة فعلياً من الطلب
    _feeController = TextEditingController(text: widget.request.deliveryFee?.toString());
    _minOrderController = TextEditingController(text: widget.request.minimumOrderValue?.toString());
    _hoursController = TextEditingController(text: widget.request.deliveryHours);
    _phoneController = TextEditingController(text: widget.request.deliveryContactPhone);
    _whatsappController = TextEditingController(text: widget.request.whatsappNumber);
  }

  @override
  void dispose() {
    _feeController.dispose();
    _minOrderController.dispose();
    _hoursController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _onProductChanged(String id, String name) async {
    setState(() {
      selectedProduct = id;
      productName = name;
      availableUnits = [];
      selectedUnit = null;
    });
    var productDoc = await FirebaseFirestore.instance.collection('products').doc(id).get();
    if (productDoc.exists && productDoc.data()!['units'] != null) {
      setState(() {
        availableUnits = productDoc.data()!['units'];
      });
    }
  }

  void _addUnitToProduct() {
    if (selectedUnit == null || _priceController.text.isEmpty) return;
    setState(() {
      currentProductUnits.add({
        'unitName': selectedUnit,
        'price': double.parse(_priceController.text),
        'pieces': 1,
      });
      _priceController.clear();
      selectedUnit = null;
    });
  }

  void _saveProductToList() {
    if (selectedProduct == null || currentProductUnits.isEmpty) return;
    setState(() {
      finalProductsToUpload.add({
        'productId': selectedProduct,
        'productName': productName,
        'units': List.from(currentProductUnits),
      });
      currentProductUnits.clear();
      selectedProduct = null;
      availableUnits = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("مراجعة وتفعيل: ${widget.request.name}", 
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // --- الجزء الأول: مراجعة البيانات اللوجستية ---
              _buildSectionTitle("⚙️ مراجعة البيانات اللوجستية"),
              Row(
                children: [
                  Expanded(child: _buildTextField("رسوم التوصيل", _feeController, prefix: "ج.م")),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField("الحد الأدنى للطلب", _minOrderController, prefix: "ج.م")),
                ],
              ),
              const SizedBox(height: 10),
              _buildTextField("مواعيد العمل", _hoursController, hint: "مثال: من 9 صباحاً إلى 12 مساءً"),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildTextField("رقم الهاتف", _phoneController, icon: Icons.phone)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField("رقم الواتساب", _whatsappController, icon: Icons.chat)),
                ],
              ),
              const Divider(height: 40, thickness: 2, color: Colors.blueGrey),

              // --- الجزء الثاني: إضافة المنتجات (النظام الحالي) ---
              _buildSectionTitle("📦 إضافة المنتجات والأسعار"),
              _buildFirebaseDropdown("القسم الرئيسي", "mainCategory", (val, name) {
                setState(() { selectedMainCat = val; selectedSubCat = null; });
              }),
              if (selectedMainCat != null)
                _buildFirebaseDropdown("القسم الفرعي", "subCategory", (val, name) {
                  setState(() { selectedSubCat = val; selectedProduct = null; });
                }, filterField: "mainId", filterValue: selectedMainCat),
              if (selectedSubCat != null)
                _buildFirebaseDropdown("المنتج", "products", (val, name) {
                  _onProductChanged(val, name);
                }, filterField: "subId", filterValue: selectedSubCat),

              if (selectedProduct != null) ...[
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedUnit,
                        decoration: const InputDecoration(labelText: "اختر الوحدة المسجلة"),
                        items: availableUnits.map((u) => DropdownMenuItem<String>(
                          value: u['unitName'].toString(),
                          child: Text(u['unitName'].toString()),
                        )).toList(),
                        onChanged: (val) => setState(() => selectedUnit = val),
                      ),
                      TextField(
                        controller: _priceController,
                        decoration: const InputDecoration(labelText: "السعر لهذا الماركت"),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _addUnitToProduct, 
                        icon: const Icon(Icons.add),
                        label: const Text("إضافة الوحدة"),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: currentProductUnits.map((u) => Chip(
                    label: Text("${u['unitName']}: ${u['price']} ج.م"),
                    onDeleted: () => setState(() => currentProductUnits.remove(u)),
                  )).toList(),
                ),
                ElevatedButton(
                  onPressed: currentProductUnits.isEmpty ? null : _saveProductToList,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text("حفظ المنتج في القائمة"),
                ),
              ],
              
              const Divider(height: 30),
              ...finalProductsToUpload.map((p) => Card(
                color: Colors.grey[100],
                child: ListTile(
                  title: Text(p['productName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("عدد الوحدات المسعرة: ${p['units'].length}"),
                  trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => finalProductsToUpload.remove(p))),
                ),
              )),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
        ElevatedButton(
          onPressed: finalProductsToUpload.isEmpty ? null : () {
            // تجميع البيانات اللوجستية بعد التعديل
            Map<String, dynamic> updatedData = {
              'deliveryFee': double.tryParse(_feeController.text) ?? 0.0,
              'minimumOrderValue': double.tryParse(_minOrderController.text) ?? 0.0,
              'deliveryHours': _hoursController.text,
              'deliveryContactPhone': _phoneController.text,
              'whatsappNumber': _whatsappController.text,
            };
            widget.onConfirm(finalProductsToUpload, updatedData);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 20)),
          child: const Text("موافقة نهائية وتفعيل الحساب ✅"),
        ),
      ],
    );
  }

  // دالة مساعدة لبناء حقول النص
  Widget _buildTextField(String label, TextEditingController controller, {String? prefix, IconData? icon, String? hint}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix != null ? "$prefix " : null,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: prefix != null ? TextInputType.number : TextInputType.text,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2c3e50))),
      ),
    );
  }

  Widget _buildFirebaseDropdown(String label, String collection, Function(String, String) onChanged, {String? filterField, String? filterValue}) {
    Query query = FirebaseFirestore.instance.collection(collection);
    if (filterField != null) query = query.where(filterField, isEqualTo: filterValue);
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        var docs = snapshot.data!.docs;
        return DropdownButtonFormField<String>(
          decoration: InputDecoration(labelText: label),
          items: docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name'] ?? ''))).toList(),
          onChanged: (val) {
            var doc = docs.firstWhere((d) => d.id == val);
            onChanged(val!, doc['name']);
          },
        );
      },
    );
  }
}

