import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddProductsDialog extends StatefulWidget {
  final String supermarketId;
  final String supermarketName;
  final Function(List<Map<String, dynamic>>) onConfirm;

  const AddProductsDialog({
    super.key,
    required this.supermarketId,
    required this.supermarketName,
    required this.onConfirm,
  });

  @override
  State<AddProductsDialog> createState() => _AddProductsDialogState();
}

class _AddProductsDialogState extends State<AddProductsDialog> {
  String? selectedMainCat, selectedSubCat, selectedProduct;
  String? productName;
  
  // التحكم في إضافة الوحدات (مثل الـ HTML)
  final TextEditingController _unitNameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _piecesController = TextEditingController();
  
  List<Map<String, dynamic>> currentProductUnits = []; // الوحدات للمنتج الحالي
  List<Map<String, dynamic>> finalProductsToUpload = []; // القائمة النهائية للموافقة

  void _addUnitToProduct() {
    if (_unitNameController.text.isEmpty || _priceController.text.isEmpty) return;
    setState(() {
      currentProductUnits.add({
        'unitName': _unitNameController.text,
        'price': double.parse(_priceController.text),
        'pieces': int.tryParse(_piecesController.text) ?? 1,
      });
      _unitNameController.clear();
      _priceController.clear();
      _piecesController.clear();
    });
  }

  void _saveProductToList() {
    if (selectedProduct == null || currentProductUnits.isEmpty) return;
    setState(() {
      finalProductsToUpload.add({
        'productId': selectedProduct,
        'productName': productName ?? "منتج",
        'units': List.from(currentProductUnits),
      });
      currentProductUnits.clear();
      selectedProduct = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("تسعير منتجات ${widget.supermarketName}"),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildFirebaseDropdown("القسم الرئيسي", "mainCategory", (val, name) {
                setState(() { selectedMainCat = val; selectedSubCat = null; });
              }),
              if (selectedMainCat != null)
                _buildFirebaseDropdown("القسم الفرعي", "subCategory", (val, name) {
                  setState(() { selectedSubCat = val; selectedProduct = null; });
                }, filterField: "mainId", filterValue: selectedMainCat),
              if (selectedSubCat != null)
                _buildFirebaseDropdown("المنتج", "products", (val, name) {
                  setState(() { selectedProduct = val; productName = name; });
                }, filterField: "subId", filterValue: selectedSubCat),

              if (selectedProduct != null) ...[
                const Divider(height: 30, color: Colors.blue),
                const Text("إضافة وحدات المنتج (قطعة، كرتونة...)", style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _unitNameController, decoration: const InputDecoration(labelText: "اسم الوحدة"))),
                    const SizedBox(width: 5),
                    Expanded(child: TextField(controller: _priceController, decoration: const InputDecoration(labelText: "السعر"), keyboardType: TextInputType.number)),
                    const SizedBox(width: 5),
                    Expanded(child: TextField(controller: _piecesController, decoration: const InputDecoration(labelText: "القطع"), keyboardType: TextInputType.number)),
                    IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: _addUnitToProduct),
                  ],
                ),
                // عرض الوحدات المضافة للمنتج الحالي
                ...currentProductUnits.map((u) => Chip(label: Text("${u['unitName']}: ${u['price']} ج.م"), onDeleted: () => setState(() => currentProductUnits.remove(u)))),
                ElevatedButton(onPressed: _saveProductToList, child: const Text("حفظ المنتج في القائمة")),
              ],
              
              const Divider(height: 40, thickness: 2),
              const Text("المنتجات الجاهزة للرفع", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ...finalProductsToUpload.map((p) => ListTile(
                title: Text(p['productName']),
                subtitle: Text("عدد الوحدات: ${p['units'].length}"),
                trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => setState(() => finalProductsToUpload.remove(p))),
              )),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
        ElevatedButton(
          onPressed: finalProductsToUpload.isEmpty ? null : () => widget.onConfirm(finalProductsToUpload),
          child: const Text("تفعيل السوبر ماركت بالمنتجات"),
        ),
      ],
    );
  }

  // ودجت مطور لجلب الاسم والمعرف معاً
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

