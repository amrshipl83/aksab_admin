import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductSelectorSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onProductAdded;
  const ProductSelectorSheet({super.key, required this.onProductAdded});

  @override
  State<ProductSelectorSheet> createState() => _ProductSelectorSheetState();
}

class _ProductSelectorSheetState extends State<ProductSelectorSheet> {
  String? selectedMainCatId;
  String? selectedSubCatId;
  Map<String, dynamic>? selectedProduct;
  
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("إضافة منتجات التاجر", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        
        // 1. اختيار القسم الرئيسي
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('mainCategory').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const LinearProgressIndicator();
            return DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "القسم الرئيسي"),
              value: selectedMainCatId,
              items: snapshot.data!.docs.map((doc) {
                return DropdownMenuItem(value: doc.id, child: Text(doc['name']));
              }).toList(),
              onChanged: (val) => setState(() { selectedMainCatId = val; selectedSubCatId = null; selectedProduct = null; }),
            );
          },
        ),

        // 2. اختيار القسم الفرعي (يعتمد على الرئيسي)
        if (selectedMainCatId != null)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('subCategory')
                .where('mainId', isEqualTo: selectedMainCatId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              return DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "القسم الفرعي"),
                value: selectedSubCatId,
                items: snapshot.data!.docs.map((doc) {
                  return DropdownMenuItem(value: doc.id, child: Text(doc['name']));
                }).toList(),
                onChanged: (val) => setState(() { selectedSubCatId = val; selectedProduct = null; }),
              );
            },
          ),

        // 3. اختيار المنتج (يعتمد على الفرعي)
        if (selectedSubCatId != null)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('products')
                .where('subId', isEqualTo: selectedSubCatId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              return DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(labelText: "المنتج"),
                items: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return DropdownMenuItem(value: {...data, 'id': doc.id}, child: Text(data['name']));
                }).toList(),
                onChanged: (val) => setState(() => selectedProduct = val),
              );
            },
          ),

        if (selectedProduct != null) ...[
          Row(
            children: [
              Expanded(child: TextField(controller: _priceController, decoration: const InputDecoration(labelText: "السعر"), keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _stockController, decoration: const InputDecoration(labelText: "الكمية"), keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              if (_priceController.text.isNotEmpty) {
                widget.onProductAdded({
                  'productId': selectedProduct!['id'],
                  'productName': selectedProduct!['name'],
                  'price': double.parse(_priceController.text),
                  'stock': int.parse(_stockController.text),
                  'imageUrl': selectedProduct!['imageUrl'] ?? '',
                });
                _priceController.clear();
                _stockController.clear();
              }
            },
            child: const Text("إضافة المنتج للقائمة"),
          )
        ]
      ],
    );
  }
}

