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
  String? selectedMainCat;
  String? selectedSubCat;
  String? selectedProduct;
  final TextEditingController _priceController = TextEditingController();
  List<Map<String, dynamic>> selectedProductsList = [];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("إضافة منتجات لـ ${widget.supermarketName}"),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDropdown("القسم الرئيسي", "mainCategory", (val) {
                setState(() { selectedMainCat = val; selectedSubCat = null; selectedProduct = null; });
              }),
              if (selectedMainCat != null)
                _buildDropdown("القسم الفرعي", "subCategory", (val) {
                  setState(() { selectedSubCat = val; selectedProduct = null; });
                }, filterField: "mainId", filterValue: selectedMainCat),
              if (selectedSubCat != null)
                _buildDropdown("المنتج", "products", (val) {
                  setState(() { selectedProduct = val; });
                }, filterField: "subId", filterValue: selectedSubCat),
              if (selectedProduct != null) ...[
                TextField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: "السعر (EGP)"),
                  keyboardType: TextInputType.number,
                ),
                ElevatedButton(onPressed: _addProductToList, child: const Text("إضافة للقائمة")),
              ],
              const Divider(),
              ...selectedProductsList.map((p) => ListTile(
                    title: Text(p['productName']),
                    subtitle: Text("${p['units'][0]['price']} ج.م"),
                    trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => setState(() => selectedProductsList.remove(p))),
                  )),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
        ElevatedButton(
          onPressed: selectedProductsList.isEmpty ? null : () => widget.onConfirm(selectedProductsList),
          child: const Text("موافقة وتفعيل"),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String collection, Function(String?) onChanged, {String? filterField, String? filterValue}) {
    Query query = FirebaseFirestore.instance.collection(collection);
    if (filterField != null) query = query.where(filterField, isEqualTo: filterValue);
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        return DropdownButtonFormField<String>(
          decoration: InputDecoration(labelText: label),
          items: snapshot.data!.docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name'] ?? 'بدون اسم'))).toList(),
          onChanged: onChanged,
        );
      },
    );
  }

  void _addProductToList() {
    if (_priceController.text.isEmpty || selectedProduct == null) return;
    setState(() {
      selectedProductsList.add({
        'productId': selectedProduct,
        'productName': "منتج مختار", 
        'units': [{'price': double.parse(_priceController.text), 'unitName': 'وحدة'}],
      });
      _priceController.clear();
    });
  }
}

