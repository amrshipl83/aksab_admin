import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart'; 
import '../pages/products_report_page.dart';

class ProductTab extends StatefulWidget {
  const ProductTab({super.key});

  @override
  State<ProductTab> createState() => _ProductTabState();
}

class _ProductTabState extends State<ProductTab> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _orderController = TextEditingController(text: "0");
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

  void _openScanner() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("برجاء استخدام مسدس الباركود أو الإدخال اليدوي (الكاميرا للموبايل فقط)"))
      );
      return;
    }
    try {
      String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
        "#ff6666", "إلغاء", true, ScanMode.BARCODE
      );
      if (!mounted) return;
      if (barcodeScanRes != "-1") {
        setState(() => _barcodeController.text = barcodeScanRes);
      }
    } catch (e) {
      debugPrint("Scanner Error: $e");
    }
  }

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
              'units': oldUnits,
              'unitsWithFactors': newUnits,
              'createdAt': FieldValue.serverTimestamp(),
            });
            importedCount++;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم استيراد $importedCount منتج")));
      } finally { setState(() => _isLoading = false); }
    }
  }

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
        'order': int.tryParse(_orderController.text) ?? 0,
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
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Expanded(child: ElevatedButton.icon(onPressed: _importFromExcel, icon: const Icon(Icons.upload_file), label: const Text("استيراد إكسل"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductsReportPage())), icon: const Icon(Icons.list), label: const Text("الكتالوج"))),
            ],
          ),
          const SizedBox(height: 25),
          TextField(
            controller: _barcodeController,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              labelText: "الباركود",
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
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('mainCategory').snapshots(),
            builder: (context, snapshot) {
              return DropdownButtonFormField<String>(
                value: selectedMainId,
                hint: const Text("القسم الرئيسي"),
                isExpanded: true,
                items: snapshot.data?.docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name'], textAlign: TextAlign.right))).toList(),
                onChanged: (val) => setState(() { selectedMainId = val; selectedSubId = null; }),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text("صور المنتج", style: TextStyle(fontWeight: FontWeight.bold)),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2),
            itemCount: 4,
            itemBuilder: (context, index) => GestureDetector(
              onTap: () async {
                final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (img != null) setState(() => selectedImages[index] = img);
              },
              child: Container(
                margin: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  border: Border.all(color: index == 0 ? Colors.blue : Colors.grey),
                  borderRadius: BorderRadius.circular(8)),
                child: selectedImages[index] == null ? const Icon(Icons.add_a_photo) : Image.network(selectedImages[index]!.path, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text("إضافة وحدات (اسم : معامل)", style: TextStyle(fontWeight: FontWeight.bold)),
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
              Expanded(flex: 2, child: TextField(controller: _unitController, textAlign: TextAlign.right, decoration: const InputDecoration(hintText: "كرتونة"))),
              const SizedBox(width: 10),
              Expanded(flex: 1, child: TextField(controller: _factorController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: "12"))),
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
