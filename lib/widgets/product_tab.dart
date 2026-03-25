import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // نعرف إحنا ويب ولا لا
import '../pages/products_report_page.dart';

// استيراد مشروط: يحمل المكتبة فقط لو مش ويب
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';

class ProductTab extends StatefulWidget {
  const ProductTab({super.key});

  @override
  State<ProductTab> createState() => _ProductTabState();
}

class _ProductTabState extends State<ProductTab> {
  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _unitController = TextEditingController();
  final _factorController = TextEditingController(text: "1");
  
  String? selectedMainId;
  String? selectedSubId;
  String? selectedManufacturerId;
  List<XFile?> selectedImages = [null, null, null, null];
  List<Map<String, dynamic>> unitsWithFactors = [];
  bool _isLoading = false;

  final String cloudName = "dgmmx6jbu";
  final String uploadPreset = "commerce";

  // دالة السكانر الذكية
  void _openScanner() async {
    if (kIsWeb) {
      // الويب بيعتمد على السكانر الخارجي (المسدس) أو الكتابة اليدوية
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("الكاميرا متاحة في نسخة الموبايل فقط. في الويب استخدم السكانر الخارجي."))
      );
      return;
    }

    try {
      // الكود ده هيتنفذ على الموبايل (APK) بس
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

  // ... (بقية الدوال: _importFromExcel و _saveProduct) ...
  // تأكد من استخدام excel_lib.Border لتجنب خطأ الـ Build القديم
  
  @override
  Widget build(BuildContext context) {
    // نفس كود الـ UI اللي فات
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
           // زرار الباركود بينادي _openScanner اللي بقت ذكية دلوقتي
           TextField(
             controller: _barcodeController,
             decoration: InputDecoration(
               labelText: "الباركود",
               prefixIcon: IconButton(onPressed: _openScanner, icon: const Icon(Icons.qr_code_scanner)),
               border: const OutlineInputBorder(),
             ),
           ),
           // ... بقية الحقول ...
        ],
      ),
    );
  }
}
