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
  String? selectedUnit; // الوحدة المختارة من قائمة وحدات المنتج
  List<dynamic> availableUnits = []; // الوحدات القادمة من الفايربيز للمنتج المختار

  final TextEditingController _priceController = TextEditingController();
  
  List<Map<String, dynamic>> currentProductUnits = []; 
  List<Map<String, dynamic>> finalProductsToUpload = []; 

  // جلب بيانات المنتج المختار لمعرفة وحداته المسجلة (كما يفعل الـ HTML)
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
        availableUnits = productDoc.data()!['units']; // جلب المصفوفة من الفايربيز
      });
    }
  }

  void _addUnitToProduct() {
    if (selectedUnit == null || _priceController.text.isEmpty) return;
    setState(() {
      currentProductUnits.add({
        'unitName': selectedUnit,
        'price': double.parse(_priceController.text),
        'pieces': 1, // القيمة الافتراضية كما في المنطق البرمي
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
      title: Text("إعداد منتجات ${widget.supermarketName}"),
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
                  _onProductChanged(val, name);
                }, filterField: "subId", filterValue: selectedSubCat),

              if (selectedProduct != null) ...[
                const Divider(color: Colors.blue),
                // قائمة الوحدات (تظهر فقط الوحدات المسجلة لهذا المنتج في السيستم)
                DropdownButtonFormField<String>(
                  value: selectedUnit,
                  decoration: const InputDecoration(labelText: "اختر الوحدة المسجلة لهذا المنتج"),
                  items: availableUnits.map((u) => DropdownMenuItem<String>(
                    value: u['unitName'].toString(),
                    child: Text(u['unitName'].toString()),
                  )).toList(),
                  onChanged: (val) => setState(() => selectedUnit = val),
                ),
                TextField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: "السعر لهذا السوبر ماركت"),
                  keyboardType: TextInputType.number,
                ),
                ElevatedButton(onPressed: _addUnitToProduct, child: const Text("إضافة الوحدة")),
                
                Wrap(
                  children: currentProductUnits.map((u) => Chip(
                    label: Text("${u['unitName']}: ${u['price']} ج.م"),
                    onDeleted: () => setState(() => currentProductUnits.remove(u)),
                  )).toList(),
                ),
                
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: currentProductUnits.isEmpty ? null : _saveProductToList,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text("حفظ المنتج والوحدات"),
                ),
              ],
              
              const Divider(height: 30),
              ...finalProductsToUpload.map((p) => ListTile(
                title: Text(p['productName']),
                subtitle: Text("تم تسعير ${p['units'].length} وحدات"),
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
          child: const Text("موافقة نهائية وتفعيل"),
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
            var doc = docs.firstWhere((d) => d.id == val);
            onChanged(val!, doc['name']);
          },
        );
      },
    );
  }
}

