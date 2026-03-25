import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_picker/file_picker.dart';
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
  final _factorController = TextEditingController(text: "1"); // جديد: للمُعامل
  final _barcodeController = TextEditingController(); // جديد: للباركود

  String? selectedMainId;
  String? selectedSubId;
  String? selectedManufacturerId;
  String status = 'active';

  List<XFile?> selectedImages = [null, null, null, null];
  // تعديل: الوحدات بقت بتشيل الاسم والمعامل
  List<Map<String, dynamic>> unitsWithFactors = []; 
  bool _isLoading = false;

  final String cloudName = "dgmmx6jbu";
  final String uploadPreset = "commerce";

  // دالة مساعدة للاكسل عشان تجيب الـ ID بالاسم
  Future<String?> _getIdByName(String collection, String name) async {
    if (name.isEmpty) return null;
    var snap = await FirebaseFirestore.instance.collection(collection).where('name', isEqualTo: name.trim()).limit(1).get();
    return snap.docs.isNotEmpty ? snap.docs.first.id : null;
  }

  Future<void> _pickImage(int index) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => selectedImages[index] = image);
  }

  void _addUnit() {
    if (_unitController.text.isNotEmpty) {
      setState(() {
        unitsWithFactors.add({
          'unitName': _unitController.text.trim(),
          'subQty': int.tryParse(_factorController.text) ?? 1
        });
        _unitController.clear();
        _factorController.text = "1";
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
    } catch (e) { debugPrint("Upload Error: $e"); }
    return null;
  }

  // حفظ يدوي (نفس منطق الأصل بالظبط مع زيادة الحقول الجديدة)
  Future<void> _saveProduct() async {
    if (_nameController.text.isEmpty || selectedMainId == null || selectedSubId == null || 
        selectedManufacturerId == null || selectedImages[0] == null || unitsWithFactors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إكمال البيانات والصورة الأساسية ووحدة واحدة على الأقل")));
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
        'barcode': _barcodeController.text.trim(), // زيادة الباركود
        'description': _descController.text.trim(),
        'mainId': selectedMainId,
        'subId': selectedSubId,
        'manufacturerId': selectedManufacturerId,
        'order': int.tryParse(_orderController.text) ?? 0,
        'status': status,
        'imageUrls': imageUrls,
        'imagePublicIds': imagePublicIds,
        'units': unitsWithFactors, // الوحدات الجديدة
        'unitsWithFactors': unitsWithFactors, // للربط مع السيستم الجديد
        'createdAt': FieldValue.serverTimestamp(),
      });

      _resetForm();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إضافة المنتج بنجاح")));
    } finally { setState(() => _isLoading = false); }
  }

  // دالة استيراد الإكسل (منفصلة تماماً)
  Future<void> _importExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx']);
    if (result == null) return;
    setState(() => _isLoading = true);
    try {
      var bytes = result.files.first.bytes;
      var excel = excel_lib.Excel.decodeBytes(bytes!);
      for (var table in excel.tables.keys) {
        for (var i = 1; i < excel.tables[table]!.maxRows; i++) {
          var row = excel.tables[table]!.rows[i];
          String name = row[0]?.value?.toString() ?? "";
          String barcode = row[1]?.value?.toString() ?? "";
          if (name.isEmpty) continue;

          var mId = await _getIdByName('mainCategory', row[3]?.value?.toString() ?? "");
          var sId = await _getIdByName('subCategory', row[4]?.value?.toString() ?? "");
          var mfgId = await _getIdByName('manufacturers', row[5]?.value?.toString() ?? "");

          List<Map<String, dynamic>> excelUnits = [];
          String rawUnits = row[6]?.value?.toString() ?? "قطعة:1";
          for (var u in rawUnits.split(',')) {
            var p = u.trim().split(':');
            excelUnits.add({'unitName': p[0], 'subQty': p.length > 1 ? (int.tryParse(p[1]) ?? 1) : 1});
          }

          await FirebaseFirestore.instance.collection('products').add({
            'name': name.trim(),
            'barcode': barcode.trim(),
            'description': row[2]?.value?.toString() ?? "",
            'mainId': mId, 'subId': sId, 'manufacturerId': mfgId,
            'status': 'active', 'order': 0,
            'imageUrls': ["https://res.cloudinary.com/$cloudName/image/upload/v1/productImages/$barcode.jpg"],
            'imagePublicIds': ["productImages/$barcode"],
            'units': excelUnits, 'unitsWithFactors': excelUnits,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } finally { setState(() => _isLoading = false); }
  }

  void _resetForm() {
    _nameController.clear(); _descController.clear(); _orderController.clear(); _barcodeController.clear();
    setState(() { selectedImages = [null, null, null, null]; unitsWithFactors = []; selectedSubId = null; });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // زرار الكتالوج الأصلي
          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductsReportPage())),
            child: Container(/* ... نفس تصميمك في الأصل ... */
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF4361ee).withOpacity(0.3))),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.arrow_back_ios, size: 16, color: Color(0xFF4361ee)),
                  Row(children: [Text("عرض كتالوج المنتجات", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4361ee))), SizedBox(width: 10), Icon(Icons.inventory_2_outlined, color: Color(0xFF4361ee))]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // زرار الإكسل الجديد (منفصل)
          ElevatedButton.icon(onPressed: _importExcel, icon: const Icon(Icons.upload_file), label: const Text("استيراد من إكسل"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 45))),
          
          const SizedBox(height: 25),
          // حقل الباركود الجديد
          TextField(controller: _barcodeController, textAlign: TextAlign.right, decoration: const InputDecoration(labelText: "باركود المنتج (يدوي أو اسكنر)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.qr_code))),
          const SizedBox(height: 10),
          TextField(controller: _nameController, textAlign: TextAlign.right, decoration: const InputDecoration(labelText: "اسم المنتج", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _descController, textAlign: TextAlign.right, maxLines: 2, decoration: const InputDecoration(labelText: "وصف المنتج", border: OutlineInputBorder())),
          const SizedBox(height: 10),

          // القوائم المنسدلة (نفس الأصل)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('mainCategory').snapshots(),
            builder: (context, snapshot) => DropdownButtonFormField<String>(
              value: selectedMainId, hint: const Text("اختر القسم الرئيسي"), isExpanded: true,
              items: snapshot.data?.docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name'], textAlign: TextAlign.right))).toList(),
              onChanged: (val) => setState(() { selectedMainId = val; selectedSubId = null; }),
            ),
          ),
          const SizedBox(height: 10),
          if (selectedMainId != null) StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('subCategory').where('mainId', isEqualTo: selectedMainId).snapshots(),
            builder: (context, snapshot) => DropdownButtonFormField<String>(
              value: selectedSubId, hint: const Text("اختر القسم الفرعي"), isExpanded: true,
              items: snapshot.data?.docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name']))).toList(),
              onChanged: (val) => setState(() => selectedSubId = val),
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('manufacturers').snapshots(),
            builder: (context, snapshot) => DropdownButtonFormField<String>(
              value: selectedManufacturerId, hint: const Text("اختر الشركة المصنعة"), isExpanded: true,
              items: snapshot.data?.docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name']))).toList(),
              onChanged: (val) => setState(() => selectedManufacturerId = val),
            ),
          ),
          const SizedBox(height: 10),
          TextField(controller: _orderController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "الترتيب", border: OutlineInputBorder())),
          
          const SizedBox(height: 20),
          const Text("صور المنتج (الصورة الأولى إجبارية)", style: TextStyle(fontWeight: FontWeight.bold)),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5),
            itemCount: 4,
            itemBuilder: (context, index) => GestureDetector(
              onTap: () => _pickImage(index),
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: index == 0 ? Colors.blue : Colors.grey), borderRadius: BorderRadius.circular(8)),
                child: selectedImages[index] == null 
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add_a_photo), Text("صورة ${index + 1}")])
                  : ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(selectedImages[index]!.path, fit: BoxFit.cover)),
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text("وحدات البيع والمعامل", style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              IconButton(onPressed: _addUnit, icon: const Icon(Icons.add_circle, color: Colors.green)),
              Expanded(child: TextField(controller: _unitController, textAlign: TextAlign.right, decoration: const InputDecoration(hintText: "كرتونة"))),
              const SizedBox(width: 5),
              Expanded(child: TextField(controller: _factorController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: "12"))),
            ],
          ),
          Wrap(spacing: 8, children: unitsWithFactors.map((u) => Chip(label: Text("${u['unitName']} (${u['subQty']})"), onDeleted: () => setState(() => unitsWithFactors.remove(u)))).toList()),

          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveProduct,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: const Color(0xFF4361ee)),
            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("حفظ المنتج النهائي", style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}
