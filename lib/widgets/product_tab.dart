import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// استيراد صفحة التقارير للربط
import '../pages/products_report_page.dart';

class ProductTab extends StatefulWidget {
  const ProductTab({super.key});

  @override
  State<ProductTab> createState() => _ProductTabState();
}

class _ProductTabState extends State<ProductTab> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _orderController = TextEditingController();
  final _unitController = TextEditingController();

  String? selectedMainId;
  String? selectedSubId;
  String? selectedManufacturerId;
  String status = 'active';

  List<XFile?> selectedImages = [null, null, null, null];
  List<String> units = [];
  bool _isLoading = false;

  final String cloudName = "dgmmx6jbu";
  final String uploadPreset = "commerce";

  Future<void> _pickImage(int index) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => selectedImages[index] = image);
    }
  }

  void _addUnit() {
    if (_unitController.text.isNotEmpty) {
      setState(() {
        units.add(_unitController.text.trim());
        _unitController.clear();
      });
    }
  }

  Future<Map<String, String>?> _uploadSingleImage(XFile xFile) async {
    try {
      final bytes = await xFile.readAsBytes();
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = 'productImages'
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: xFile.name));

      final response = await request.send();
      if (response.statusCode == 200) {
        final data = jsonDecode(await response.stream.bytesToString());
        return {'url': data['secure_url'], 'public_id': data['public_id']};
      }
    } catch (e) {
      debugPrint("Upload Error: $e");
    }
    return null;
  }

  Future<void> _saveProduct() async {
    if (_nameController.text.isEmpty ||
        selectedMainId == null ||
        selectedSubId == null ||
        selectedManufacturerId == null ||
        selectedImages[0] == null ||
        units.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("يرجى إكمال البيانات والصورة الأساسية ووحدة واحدة على الأقل")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      List<String> imageUrls = [];
      List<String> imagePublicIds = [];

      for (var img in selectedImages) {
        if (img != null) {
          final result = await _uploadSingleImage(img);
          if (result != null) {
            imageUrls.add(result['url']!);
            imagePublicIds.add(result['public_id']!);
          }
        }
      }

      await FirebaseFirestore.instance.collection('products').add({
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'mainId': selectedMainId,
        'subId': selectedSubId,
        'manufacturerId': selectedManufacturerId,
        'order': int.tryParse(_orderController.text) ?? 0,
        'status': status,
        'imageUrls': imageUrls,
        'imagePublicIds': imagePublicIds,
        'units': units.map((u) => {'unitName': u}).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _resetForm();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إضافة المنتج بنجاح")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    _nameController.clear();
    _descController.clear();
    _orderController.clear();
    setState(() {
      selectedImages = [null, null, null, null];
      units = [];
      selectedSubId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // الزرار الاحترافي للانتقال لتقرير المنتجات المربوط فعلياً
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProductsReportPage()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4361ee).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.arrow_back_ios, size: 16, color: Color(0xFF4361ee)),
                  Row(
                    children: [
                      Text(
                        "عرض كتالوج المنتجات المضافة",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4361ee)),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.inventory_2_outlined, color: Color(0xFF4361ee)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 25),

          TextField(
              controller: _nameController,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: "اسم المنتج", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(
              controller: _descController,
              textAlign: TextAlign.right,
              maxLines: 3,
              decoration: const InputDecoration(labelText: "وصف المنتج", border: OutlineInputBorder())),
          const SizedBox(height: 10),

          // اختيار القسم الرئيسي
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('mainCategory').snapshots(),
            builder: (context, snapshot) {
              return DropdownButtonFormField<String>(
                value: selectedMainId,
                hint: const Text("اختر القسم الرئيسي"),
                isExpanded: true,
                items: snapshot.data?.docs
                    .map((doc) => DropdownMenuItem(
                        value: doc.id, child: Text(doc['name'], textAlign: TextAlign.right)))
                    .toList(),
                onChanged: (val) => setState(() {
                  selectedMainId = val;
                  selectedSubId = null;
                }),
              );
            },
          ),
          const SizedBox(height: 10),

          // اختيار القسم الفرعي - المصحح
          if (selectedMainId != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('subCategory')
                  .where('mainId', isEqualTo: selectedMainId)
                  .snapshots(),
              builder: (context, snapshot) {
                return DropdownButtonFormField<String>(
                  value: selectedSubId,
                  hint: const Text("اختر القسم الفرعي"),
                  isExpanded: true,
                  items: snapshot.data?.docs
                      .map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name'])))
                      .toList(),
                  onChanged: (val) => setState(() => selectedSubId = val),
                );
              },
            ),
          const SizedBox(height: 10),

          // اختيار الشركة المصنعة
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('manufacturers').snapshots(),
            builder: (context, snapshot) {
              return DropdownButtonFormField<String>(
                value: selectedManufacturerId,
                hint: const Text("اختر الشركة المصنعة"),
                isExpanded: true,
                items: snapshot.data?.docs
                    .map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name'])))
                    .toList(),
                onChanged: (val) => setState(() => selectedManufacturerId = val),
              );
            },
          ),
          const SizedBox(height: 10),

          TextField(
              controller: _orderController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "الترتيب", border: OutlineInputBorder())),
          const SizedBox(height: 20),

          const Text("صور المنتج (الصورة الأولى إجبارية)", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5),
            itemCount: 4,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _pickImage(index),
                child: Container(
                  decoration: BoxDecoration(
                      border: Border.all(color: index == 0 ? Colors.blue : Colors.grey),
                      borderRadius: BorderRadius.circular(8)),
                  child: selectedImages[index] == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [const Icon(Icons.add_a_photo), Text("صورة ${index + 1}")])
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(selectedImages[index]!.path, fit: BoxFit.cover)),
                ),
              );
            },
          ),

          const SizedBox(height: 20),
          const Text("وحدات البيع", style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              IconButton(onPressed: _addUnit, icon: const Icon(Icons.add_circle, color: Colors.green)),
              Expanded(
                  child: TextField(
                      controller: _unitController,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(hintText: "مثال: كرتونة، علبة..."))),
            ],
          ),
          Wrap(
            spacing: 8,
            children:
                units.map((u) => Chip(label: Text(u), onDeleted: () => setState(() => units.remove(u)))).toList(),
          ),

          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveProduct,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50), backgroundColor: const Color(0xFF4361ee)),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("حفظ المنتج النهائي", style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}

