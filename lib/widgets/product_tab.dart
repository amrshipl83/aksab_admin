import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_picker/file_picker.dart';
import '../pages/products_report_page.dart';
import 'excel_import_service.dart';
import 'dart:typed_data'; // للتعامل مع الـ Bytes في الويب

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
  final _factorController = TextEditingController(text: "1");
  final _barcodeController = TextEditingController();

  String? selectedMainId;
  String? selectedSubId;
  String? selectedManufacturerId;
  String status = 'active';

  List<XFile?> selectedImages = [null, null, null, null];
  List<Map<String, dynamic>> unitsWithFactors = [];
  bool _isLoading = false;

  final String cloudName = "dgmmx6jbu";
  final String uploadPreset = "commerce";

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

  // الرفع المباشر بدون ضغط محلي لتجنب تجمد المتصفح
  Future<Map<String, String>?> _uploadSingleImage(XFile xFile) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      
      // 1. قراءة بيانات الصورة الأصلية مباشرة
      Uint8List originalBytes = await xFile.readAsBytes();

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = 'productImages'
        // 2. رفع الملف الأصلي وترك مهمة الضغط لـ Cloudinary بناءً على الـ Preset
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          originalBytes,
          filename: 'prod_${xFile.name}.jpg'
        ));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final data = jsonDecode(responseData);
        return {'url': data['secure_url'], 'public_id': data['public_id']};
      }
    } catch (e) {
      debugPrint("Upload Error: $e");
    }
    return null;
  }

  Future<void> _saveProduct() async {
    if (_nameController.text.isEmpty || selectedMainId == null || selectedSubId == null ||
        selectedManufacturerId == null || selectedImages[0] == null || unitsWithFactors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إكمال كافة البيانات")));
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
        'barcode': _barcodeController.text.trim(),
        'description': _descController.text.trim(),
        'mainId': selectedMainId,
        'subId': selectedSubId,
        'manufacturerId': selectedManufacturerId,
        'order': int.tryParse(_orderController.text) ?? 0,
        'status': status,
        'imageUrls': imageUrls,
        'imagePublicIds': imagePublicIds,
        'units': unitsWithFactors,
        'unitsWithFactors': unitsWithFactors,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _resetForm();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إضافة المنتج بنجاح")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importExcelWithImages() async {
    FilePickerResult? excelResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (excelResult == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("الآن اختر جميع صور المنتجات من الاستوديو"))
    );

    FilePickerResult? imagesResult = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (imagesResult == null) return;

    setState(() => _isLoading = true);
    try {
      await ExcelImportService.importWithImages(
        context: context,
        excelFile: excelResult.files.first,
        imageFiles: imagesResult.files,
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ أثناء الاستيراد: $e"))
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    _nameController.clear();
    _descController.clear();
    _orderController.clear();
    _barcodeController.clear();
    _unitController.clear();
    _factorController.text = "1";
    setState(() {
      selectedImages = [null, null, null, null];
      unitsWithFactors = [];
      selectedSubId = null;
      selectedMainId = null;
      selectedManufacturerId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductsReportPage())),
            child: Container(
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
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _importExcelWithImages,
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
            label: const Text("استيراد (إكسل + صور)", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, minimumSize: const Size(double.infinity, 45)),
          ),
          const SizedBox(height: 25),
          TextField(controller: _barcodeController, textAlign: TextAlign.right, decoration: const InputDecoration(labelText: "باركود المنتج (يدوي أو اسكنر)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.qr_code))),
          const SizedBox(height: 10),
          TextField(controller: _nameController, textAlign: TextAlign.right, decoration: const InputDecoration(labelText: "اسم المنتج", border: OutlineInputBorder()),),
          const SizedBox(height: 10),
          TextField(controller: _descController, textAlign: TextAlign.right, maxLines: 2, decoration: const InputDecoration(labelText: "وصف المنتج", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('mainCategory').snapshots(),
            builder: (context, snapshot) => DropdownButtonFormField<String>(
              value: selectedMainId,
              hint: const Text("اختر القسم الرئيسي"),
              isExpanded: true,
              items: snapshot.data?.docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name'], textAlign: TextAlign.right))).toList(),
              onChanged: (val) => setState(() {
                selectedMainId = val;
                selectedSubId = null;
              }),
            ),
          ),
          const SizedBox(height: 10),
          if (selectedMainId != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('subCategory').where('mainId', isEqualTo: selectedMainId).snapshots(),
              builder: (context, snapshot) => DropdownButtonFormField<String>(
                value: selectedSubId,
                hint: const Text("اختر القسم الفرعي"),
                isExpanded: true,
                items: snapshot.data?.docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name']))).toList(),
                onChanged: (val) => setState(() => selectedSubId = val),
              ),
            ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('manufacturers').snapshots(),
            builder: (context, snapshot) => DropdownButtonFormField<String>(
              value: selectedManufacturerId,
              hint: const Text("اختر الشركة المصنعة"),
              isExpanded: true,
              items: snapshot.data?.docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name']))).toList(),
              onChanged: (val) => setState(() => selectedManufacturerId = val),
            ),
          ),
          const SizedBox(height: 10),
          TextField(controller: _orderController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "الترتيب", border: OutlineInputBorder())),
          const SizedBox(height: 20),
          const Text("صور المنتج (الصورة الأولى إجبارية)", style: TextStyle(fontWeight: FontWeight.bold)),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
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

