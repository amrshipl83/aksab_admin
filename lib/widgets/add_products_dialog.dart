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
  String? selectedMainCat, selectedSubCat, selectedProduct, productName;
  final TextEditingController _unitNameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _piecesController = TextEditingController();
  
  List<Map<String, dynamic>> currentProductUnits = []; 
  List<Map<String, dynamic>> finalProductsToUpload = []; 

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
      title: Text("تسعير منتجات ${widget.supermarketName}", style: const TextStyle(fontFamily: 'Tajawal')),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                const Text("إضافة الوحدات (مثل الـ HTML)", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _unitNameController, decoration: const InputDecoration(labelText: "اسم الوحدة (كرتونة/قطعة)"))),
                    const SizedBox(width: 5),
                    Expanded(child: TextField(controller: _priceController, decoration: const InputDecoration(labelText: "السعر"), keyboardType: TextInputType.number)),
                    const SizedBox(width: 5),
                    Expanded(child: TextField(controller: _piecesController, decoration: const InputDecoration(labelText: "القطع"), keyboardType: TextInputType.number)),
                    IconButton(icon: const Icon(Icons.add_circle, color: Colors.green, size: 30), onPressed: _addUnitToProduct),
                  ],
                ),
                
                // --- الجزء الذي تمت إضافته لعرض الوحدات فوراً ---
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8.0,
                  children: currentProductUnits.map((u) => Chip(
                    backgroundColor: Colors.blue.shade50,
                    label: Text("${u['unitName']}: ${u['price']} ج.م (${u['pieces']} قطعة)"),
                    onDeleted: () => setState(() => currentProductUnits.remove(u)),
                    deleteIconColor: Colors.red,
                  )).toList(),
                ),
                // --------------------------------------------

                const SizedBox(height: 15),
                ElevatedButton.icon(
                  onPressed: currentProductUnits.isEmpty ? null : _saveProductToList,
                  icon: const Icon(Icons.save),
                  label: const Text("حفظ هذا المنتج في القائمة"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                ),
              ],
              
              const Divider(height: 40, thickness: 2),
              const Text("القائمة النهائية للموافقة", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ...finalProductsToUpload.map((p) => Card(
                color: Colors.grey.shade100,
                child: ListTile(
                  title: Text(p['productName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("الوحدات: ${p['units'].map((u) => u['unitName']).join(' - ')}"),
                  trailing: IconButton(icon: const Icon(Icons.delete_forever, color: Colors.red), onPressed: () => setState(() => finalProductsToUpload.remove(p))),
                ),
              )),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
        ElevatedButton(
          onPressed: finalProductsToUpload.isEmpty ? null : () => widget.onConfirm(finalProductsToUpload),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          child: const Text("تفعيل وتدشين الماركت"),
        ),
      ],
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
            if (val == null) return;
            var doc = docs.firstWhere((d) => d.id == val);
            onChanged(val, doc['name']);
          },
        );
      },
    );
  }
}

