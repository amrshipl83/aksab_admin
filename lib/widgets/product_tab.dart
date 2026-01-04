import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductTab extends StatefulWidget {
  @override
  _ProductTabState createState() => _ProductTabState();
}

class _ProductTabState extends State<ProductTab> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // الحقول الأساسية
  String productName = '';
  String? selectedMainId, selectedSubId, selectedManufacturerId;
  List<Map<String, String>> productUnits = [];
  final TextEditingController _unitController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              decoration: InputDecoration(labelText: 'اسم المنتج', border: OutlineInputBorder()),
              onChanged: (val) => productName = val,
            ),
            SizedBox(height: 15),
            // هنا تضع باقي الحقول والدروب داون كما في الكود السابق...
            Text("قسم إضافة المنتجات جاهز للربط بالـ Cloudinary", style: TextStyle(color: Colors.grey)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => print("حفظ المنتج"),
              child: Text("حفظ المنتج"),
            )
          ],
        ),
      ),
    );
  }
}

