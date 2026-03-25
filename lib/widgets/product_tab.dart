import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
  final _barcodeController = TextEditingController(); // حقل الباركود

  String? selectedMainId;
  String? selectedSubId;
  String? selectedManufacturerId;
  String status = 'active';

  List<XFile?> selectedImages = [null, null, null, null];
  List<String> units = [];
  bool _isLoading = false;

  final String cloudName = "dgmmx6jbu";
  final String uploadPreset = "commerce";

  // --- دالة مساعدة للبحث عن الـ ID بالاسم لضمان الربط الصحيح مع الإكسل ---
  Future<String?> _findDocIdByName(String collection, String name) async {
    if (name.isEmpty) return null;
    try {
      final snap = await FirebaseFirestore.instance
          .collection(collection)
          .where('name', isEqualTo: name.trim())
          .limit(1)
          .get();
      return snap.docs.isNotEmpty ? snap.docs.first.id : null;
    } catch (e) {
      debugPrint("Search Error ($collection): $e");
      return null;
    }
  }

  // --- دالة استيراد الإكسل الذكية ---
  Future<void> _importFromExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        var bytes = result.files.first.bytes;
        var excel = Excel.decodeBytes(bytes!);
        int importedCount = 0;

        for (var table in excel.tables.keys) {
          // تبدأ البيانات من الصف الثاني (تجاوز العنوان)
          for (var i = 1; i < excel.tables[table]!.maxRows; i++) {
            var row = excel.tables[table]!.rows[i];
            
            String name = row[0]?.value?.toString() ?? "";
            String barcode = row[1]?.value?.toString() ?? "";
            String desc = row[2]?.value?.toString() ?? "";
            String mainCatName = row[3]?.value?.toString() ?? "";
            String subCatName = row[4]?.value?.toString() ?? "";
            String manufacturerName = row[5]?.value?.toString() ?? "";
            
            if (name.isEmpty || barcode.isEmpty) continue;

            // جلب الـ IDs للأقسام والشركة تلقائياً
            String? mId = await _findDocIdByName('mainCategory', mainCatName);
            String? sId = await _findDocIdByName('subCategory', subCatName);
            String? mfgId = await _findDocIdByName('manufacturers', manufacturerName);

            // تركيب رابط الصورة التلقائي (الباركود هو اسم الصورة)
            String autoImageUrl = "https://res.cloudinary.com/$cloudName/image/upload/v1/productImages/$barcode.jpg";

            await FirebaseFirestore.instance.collection('products').add({
              'name': name.trim(),
              'barcode': barcode.trim(),
              'description': desc.trim(),
              'mainId': mId ?? selectedMainId, // الإكسل أولاً ثم المختار يدوياً
              'subId': sId ?? selectedSubId,
              'manufacturerId': mfgId ?? selectedManufacturerId,
              'order': 0,
              'status': 'active',
              'imageUrls': [autoImageUrl],
              'imagePublicIds': [], // فارغ لأنها مرفوعة مسبقاً برابط مباشر
              'units': [{'unitName': 'قطعة'}],
              'createdAt': FieldValue.serverTimestamp(),
            });
            importedCount++;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم استيراد $importedCount منتج بنجاح")));
      } catch (e) {
        debugPrint("Excel Error: $e");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("خطأ في قراءة ملف الإكسل")));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- دالة فتح سكانر الباركود ---
  void _openScanner() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("اسحب الباركود أمام الكاميرا", textAlign: TextAlign.center),
        content: SizedBox(
          width: 300,
          height: 300,
          child: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                setState(() => _barcodeController.text = barcodes.first.rawValue ?? "");
                Navigator.pop(context);
              }
            },
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(int index) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => selectedImages[index] = image);
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
    if (_nameController.text.isEmpty || _barcodeController.text.isEmpty ||
        selectedMainId == null || selectedSubId == null ||
        selectedManufacturerId == null || (selectedImages[0] == null && units.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إكمال البيانات الأساسية والباركود")));
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
    _barcodeController.clear();
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
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _importFromExcel,
                  icon: const Icon(Icons.upload_file, color: Colors.white),
                  label: const Text("استيراد إكسل ذكي", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 15)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductsReportPage())),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text("عرض الكتالوج"),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),

          TextField(
            controller: _barcodeController,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              labelText: "رقم الباركود",
              prefixIcon: IconButton(onPressed: _openScanner, icon: const Icon(Icons.qr_code_scanner, color: Colors.blue)),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _nameController,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: "اسم المنتج", border: OutlineInputBorder()),
          ),
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
                    .map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name'], textAlign: TextAlign.right)))
                    .toList(),
                onChanged: (val) => setState(() { selectedMainId = val; selectedSubId = null; }),
              );
            },
          ),
          const SizedBox(height: 10),

          // اختيار القسم الفرعي
          if (selectedMainId != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('subCategory').where('mainId', isEqualTo: selectedMainId).snapshots(),
              builder: (context, snapshot) {
                return DropdownButtonFormField<String>(
                  value: selectedSubId,
                  hint: const Text("اختر القسم الفرعي"),
                  isExpanded: true,
                  items: snapshot.data?.docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name']))).toList(),
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
                items: snapshot.data?.docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name']))).toList(),
                onChanged: (val) => setState(() => selectedManufacturerId = val),
              );
            },
          ),
          const SizedBox(height: 30),

          ElevatedButton(
            onPressed: _isLoading ? null : _saveProduct,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: const Color(0xFF4361ee)),
            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("حفظ المنتج النهائي", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

