import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart' as excel_lib; // حل تعارض الـ Border
import 'package:file_picker/file_picker.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart'; // المكتبة المتوافقة
import '../pages/products_report_page.dart';

class ProductTab extends StatefulWidget {
  const ProductTab({super.key});

  @override
  State<ProductTab> createState() => _ProductTabState();
}

class _ProductTabState extends State<ProductTab> {
  // الكنترولرز
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _orderController = TextEditingController(text: "0");
  final _unitController = TextEditingController();
  final _factorController = TextEditingController(text: "1"); // معامل التحويل
  final _barcodeController = TextEditingController();

  String? selectedMainId;
  String? selectedSubId;
  String? selectedManufacturerId;
  String status = 'active';

  List<XFile?> selectedImages = [null, null, null, null];
  List<Map<String, dynamic>> unitsWithFactors = []; // مصفوفة الوحدات الجديدة
  bool _isLoading = false;

  final String cloudName = "dgmmx6jbu";
  final String uploadPreset = "commerce";

  // دالة البحث عن ID القسم بالاسم (للإكسل)
  Future<String?> _findDocIdByName(String collection, String name) async {
    if (name.isEmpty) return null;
    try {
      final snap = await FirebaseFirestore.instance
          .collection(collection)
          .where('name', isEqualTo: name.trim())
          .limit(1)
          .get();
      return snap.docs.isNotEmpty ? snap.docs.first.id : null;
    } catch (e) { return null; }
  }

  // فتح السكانر المتوافق
  void _openScanner() async {
    try {
      String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
        "#ff6666", "إلغاء", true, ScanMode.BARCODE
      );
      if (!mounted) return;
      if (barcodeScanRes != "-1") {
        setState(() => _barcodeController.text = barcodeScanRes);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("خطأ في فتح الكاميرا")));
    }
  }

  // استيراد إكسل (يدعم الحقول المزدوجة)
  Future<void> _importFromExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['xlsx'],
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        var bytes = result.files.first.bytes;
        var excel = excel_lib.Excel.decodeBytes(bytes!);
        int importedCount = 0;

        for (var table in excel.tables.keys) {
          for (var i = 1; i < excel.tables[table]!.maxRows; i++) {
            var row = excel.tables[table]!.rows[i];
            String name = row[0]?.value?.toString() ?? "";
            String barcode = row[1]?.value?.toString() ?? "";
            String desc = row[2]?.value?.toString() ?? "";
            String mainCatName = row[3]?.value?.toString() ?? "";
            String subCatName = row[4]?.value?.toString() ?? "";
            String mfgName = row[5]?.value?.toString() ?? "";
            String unitsRaw = row[6]?.value?.toString() ?? "قطعة:1";

            if (name.isEmpty || barcode.isEmpty) continue;

            String? mId = await _findDocIdByName('mainCategory', mainCatName);
            String? sId = await _findDocIdByName('subCategory', subCatName);
            String? mfgId = await _findDocIdByName('manufacturers', mfgName);

            // معالجة الوحدات للنسختين
            List<String> oldUnits = [];
            List<Map<String, dynamic>> newUnits = [];
            for (var u in unitsRaw.split(',')) {
              var parts = u.trim().split(':');
              String uName = parts[0];
              int uFactor = parts.length > 1 ? (int.tryParse(parts[1]) ?? 1) : 1;
              oldUnits.add(uName);
              newUnits.add({'unitName': uName, 'subQty': uFactor});
            }

            await FirebaseFirestore.instance.collection('products').add({
              'name': name.trim(),
              'barcode': barcode.trim(),
              'description': desc.trim(),
              'mainId': mId,
              'subId': sId,
              'manufacturerId': mfgId,
              'status': 'active',
              'imageUrls': ["https://res.cloudinary.com/$cloudName/image/upload/v1/productImages/$barcode.jpg"],
              'units': oldUnits, // للنسخة الـ Live
              'unitsWithFactors': newUnits, // للنسخة الجديدة والـ ERP
              'createdAt': FieldValue.serverTimestamp(),
            });
            importedCount++;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم استيراد $importedCount منتج")));
      } finally { setState(() => _isLoading = false); }
    }
  }

  // حفظ يدوي (يدعم الحقول المزدوجة)
  Future<void> _saveProduct() async {
    if (_nameController.text.isEmpty || _barcodeController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      List<String> imageUrls = [];
      for (var img in selectedImages) {
        if (img != null) {
          final bytes = await img.readAsBytes();
          final request = http.MultipartRequest('POST', Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'))
            ..fields['upload_preset'] = uploadPreset
            ..fields['folder'] = 'productImages'
            ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: img.name));
          final response = await request.send();
          if (response.statusCode == 200) {
            imageUrls.add(jsonDecode(await response.stream.bytesToString())['secure_url']);
          }
        }
      }

      List<String> oldUnits = unitsWithFactors.map((u) => u['unitName'].toString()).toList();
      
      await FirebaseFirestore.instance.collection('products').add({
        'name': _nameController.text.trim(),
        'barcode': _barcodeController.text.trim(),
        'description': _descController.text.trim(),
        'mainId': selectedMainId,
        'subId': selectedSubId,
        'manufacturerId': selectedManufacturerId,
        'status': status,
        'imageUrls': imageUrls,
        'units': oldUnits.isEmpty ? ['قطعة'] : oldUnits,
        'unitsWithFactors': unitsWithFactors.isEmpty ? [{'unitName': 'قطعة', 'subQty': 1}] : unitsWithFactors,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _resetForm();
    } finally { setState(() => _isLoading = false); }
  }

  void _resetForm() {
    _nameController.clear(); _descController.clear(); _barcodeController.clear();
    setState(() { selectedImages = [null, null, null, null]; unitsWithFactors = []; });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // أزرار الإكسل والتقرير
          Row(
            children: [
              Expanded(child: ElevatedButton.icon(onPressed: _importFromExcel, icon: const Icon(Icons.upload_file), label: const Text("استيراد إكسل"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductsReportPage())), icon: const Icon(Icons.list), label: const Text("الكتالوج"))),
            ],
          ),
          const SizedBox(height: 20),
          // حقول الإدخال
          TextField(controller: _barcodeController, decoration: InputDecoration(labelText: "الباركود", prefixIcon: IconButton(onPressed: _openScanner, icon: const Icon(Icons.qr_code_scanner)))),
          const SizedBox(height: 10),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: "اسم المنتج")),
          const SizedBox(height: 20),
          // واجهة الصور
          const Text("صور المنتج", style: TextStyle(fontWeight: FontWeight.bold)),
          GridView.builder(
            shrinkWrap: true, itemCount: 4, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2),
            itemBuilder: (context, index) => GestureDetector(
              onTap: () async {
                final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (img != null) setState(() => selectedImages[index] = img);
              },
              child: Container(
                margin: const EdgeInsets.all(5),
                decoration: BoxDecoration(border: Border.all(color: index == 0 ? Colors.blue : Colors.grey), borderRadius: BorderRadius.circular(8)),
                child: selectedImages[index] == null ? const Icon(Icons.add_a_photo) : Image.network(selectedImages[index]!.path, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // إضافة الوحدات بالمعامل
          const Text("الوحدات (الاسم والمعامل)", style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              IconButton(onPressed: () {
                if (_unitController.text.isNotEmpty) {
                  setState(() {
                    unitsWithFactors.add({'unitName': _unitController.text.trim(), 'subQty': int.tryParse(_factorController.text) ?? 1});
                    _unitController.clear(); _factorController.text = "1";
                  });
                }
              }, icon: const Icon(Icons.add_circle, color: Colors.green)),
              Expanded(child: TextField(controller: _unitController, decoration: const InputDecoration(hintText: "كرتونة"))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _factorController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: "12"))),
            ],
          ),
          Wrap(children: unitsWithFactors.map((u) => Chip(label: Text("${u['unitName']} (${u['subQty']})"), onDeleted: () => setState(() => unitsWithFactors.remove(u)))).toList()),
          const SizedBox(height: 30),
          ElevatedButton(onPressed: _isLoading ? null : _saveProduct, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), child: _isLoading ? const CircularProgressIndicator() : const Text("حفظ المنتج")),
        ],
      ),
    );
  }
}

