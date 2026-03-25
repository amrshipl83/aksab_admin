import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart' as excel_lib; // حل مشكلة التعارض هنا
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
  final _factorController = TextEditingController(text: "1"); // حقل معامل التحويل
  final _barcodeController = TextEditingController();

  String? selectedMainId;
  String? selectedSubId;
  String? selectedManufacturerId;
  String status = 'active';

  List<XFile?> selectedImages = [null, null, null, null];
  List<Map<String, dynamic>> units = []; // تغيير مصفوفة الوحدات لتشمل المعامل
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

  Future<void> _importFromExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        var bytes = result.files.first.bytes;
        var excel = excel_lib.Excel.decodeBytes(bytes!); // استخدام اللقب الجديد
        int importedCount = 0;

        for (var table in excel.tables.keys) {
          for (var i = 1; i < excel.tables[table]!.maxRows; i++) {
            var row = excel.tables[table]!.rows[i];
            String name = row[0]?.value?.toString() ?? "";
            String barcode = row[1]?.value?.toString() ?? "";
            String desc = row[2]?.value?.toString() ?? "";
            String mainCatName = row[3]?.value?.toString() ?? "";
            String subCatName = row[4]?.value?.toString() ?? "";
            String manufacturerName = row[5]?.value?.toString() ?? "";
            String unitsRaw = row[6]?.value?.toString() ?? "قطعة:1";

            if (name.isEmpty || barcode.isEmpty) continue;

            String? mId = await _findDocIdByName('mainCategory', mainCatName);
            String? sId = await _findDocIdByName('subCategory', subCatName);
            String? mfgId = await _findDocIdByName('manufacturers', manufacturerName);

            // معالجة الوحدات بالمعامل (اسم:معامل)
            List<Map<String, dynamic>> excelUnits = unitsRaw.split(',').map((u) {
              var parts = u.trim().split(':');
              return {
                'unitName': parts[0],
                'subQty': parts.length > 1 ? (int.tryParse(parts[1]) ?? 1) : 1,
              };
            }).toList();

            String autoImageUrl = "https://res.cloudinary.com/$cloudName/image/upload/v1/productImages/$barcode.jpg";

            await FirebaseFirestore.instance.collection('products').add({
              'name': name.trim(),
              'barcode': barcode.trim(),
              'description': desc.trim(),
              'mainId': mId ?? selectedMainId,
              'subId': sId ?? selectedSubId,
              'manufacturerId': mfgId ?? selectedManufacturerId,
              'order': 0,
              'status': 'active',
              'imageUrls': [autoImageUrl],
              'imagePublicIds': [],
              'units': excelUnits,
              'createdAt': FieldValue.serverTimestamp(),
            });
            importedCount++;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم استيراد $importedCount منتج بنجاح")));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("خطأ في قراءة ملف الإكسل")));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openScanner() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("اسحب الباركود أمام الكاميرا", textAlign: TextAlign.center),
        content: SizedBox(
          width: 300, height: 300,
          child: MobileScanner(
            controller: MobileScannerController(formats: [BarcodeFormat.all], facing: CameraFacing.back),
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
    if (image != null) setState(() => selectedImages[index] = image);
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
    } catch (e) { return null; }
    return null;
  }

  Future<void> _saveProduct() async {
    if (_nameController.text.isEmpty || _barcodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إدخال الاسم والباركود")));
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
        'units': units.isEmpty ? [{'unitName': 'قطعة', 'subQty': 1}] : units,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _resetForm();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إضافة المنتج بنجاح")));
    } finally { setState(() => _isLoading = false); }
  }

  void _resetForm() {
    _nameController.clear(); _descController.clear(); _orderController.clear(); _barcodeController.clear();
    setState(() { selectedImages = [null, null, null, null]; units = []; });
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
          // ... (StreamBuilders للقسم الرئيسي والفرعي والشركة تبقى كما هي) ...
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('mainCategory').snapshots(),
            builder: (context, snapshot) {
              return DropdownButtonFormField<String>(
                value: selectedMainId,
                hint: const Text("اختر القسم الرئيسي"),
                isExpanded: true,
                items: snapshot.data?.docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name'], textAlign: TextAlign.right))).toList(),
                onChanged: (val) => setState(() { selectedMainId = val; selectedSubId = null; }),
              );
            },
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 20),
          // واجهة الصور اليدوية (تم حل تعارض Border هنا تلقائياً بفضل Flutter)
          const Text("صور المنتج (4 صور بحد أقصى)", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5),
            itemCount: 4,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _pickImage(index),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: index == 0 ? Colors.blue : Colors.grey), // تم استخدام Border من Flutter
                    borderRadius: BorderRadius.circular(8)),
                  child: selectedImages[index] == null
                    ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add_a_photo), Text("صورة ${index + 1}")])
                    : ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(selectedImages[index]!.path, fit: BoxFit.cover)),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text("إضافة وحدات يدوية (الاسم : المعامل)", style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              IconButton(onPressed: () { 
                if(_unitController.text.isNotEmpty) {
                  setState(() {
                    units.add({
                      'unitName': _unitController.text.trim(),
                      'subQty': int.tryParse(_factorController.text) ?? 1
                    });
                    _unitController.clear();
                    _factorController.text = "1";
                  });
                }
              }, icon: const Icon(Icons.add_circle, color: Colors.green)),
              Expanded(flex: 2, child: TextField(controller: _unitController, textAlign: TextAlign.right, decoration: const InputDecoration(hintText: "اسم الوحدة (كرتونة)"))),
              const SizedBox(width: 10),
              Expanded(flex: 1, child: TextField(controller: _factorController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: "المعامل (12)"))),
            ],
          ),
          Wrap(spacing: 8, children: units.map((u) => Chip(label: Text("${u['unitName']} (${u['subQty']})"), onDeleted: () => setState(() => units.remove(u)))).toList()),
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
