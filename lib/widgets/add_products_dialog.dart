import 'package:flutter/material.dart';
import '../models/supermarket_model.dart';
import '../services/delivery_service.dart';

class AddProductsDialog extends StatefulWidget {
  final SupermarketModel request;
  final DeliveryService service;

  const AddProductsDialog({super.key, required this.request, required this.service});

  @override
  State<AddProductsDialog> createState() => _AddProductsDialogState();
}

class _AddProductsDialogState extends State<AddProductsDialog> {
  // هنا سنضع المتغيرات الخاصة بالاختيارات (نفس منطق الـ HTML)
  List<Map<String, dynamic>> selectedProducts = [];
  
  // دالة الحفظ النهائي (الموافقة)
  void _confirmApproval() async {
    if (selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("برجاء إضافة منتجات أولاً")),
      );
      return;
    }

    try {
      await widget.service.approveRequest(
        widget.request.id,
        widget.request.name,
        widget.request.address,
        widget.request.deliveryFee,
        selectedProducts,
      );
      if (mounted) Navigator.pop(context); // إغلاق النافذة بعد النجاح
    } catch (e) {
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("إضافة منتجات لـ ${widget.request.name}"),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("هنا سنضع القوائم المنسدلة (Dropdowns) لـ:"),
            const Text("القسم الرئيسي > القسم الفرعي > المنتج > السعر"),
            const Divider(),
            // عرض المنتجات المضافة حالياً
            Expanded(
              child: ListView.builder(
                itemCount: selectedProducts.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text(selectedProducts[index]['productName']),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => setState(() => selectedProducts.removeAt(index)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
        ElevatedButton(
          onPressed: _confirmApproval,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text("موافقة وتفعيل", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

