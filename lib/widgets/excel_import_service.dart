import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ExcelImportService {
  static const String cloudName = "dgmmx6jbu";
  static const String uploadPreset = "commerce";

  static Future<void> importWithImages({
    required BuildContext context,
    required List<PlatformFile> imageFiles,
    required PlatformFile excelFile,
  }) async {
    try {
      var bytes = excelFile.bytes;
      var excel = Excel.decodeBytes(bytes!);

      for (var table in excel.tables.keys) {
        for (var i = 1; i < excel.tables[table]!.maxRows; i++) {
          var row = excel.tables[table]!.rows[i];
          
          String name = row[0]?.value?.toString() ?? "";
          
          // تنظيف الباركود من أي علامات عشرية (زي 622.0) ومن المسافات
          String rawBarcode = row[1]?.value?.toString() ?? "";
          String barcode = rawBarcode.split('.').first.trim();
          
          if (barcode.isEmpty) continue;

          _showSnackBar(context, "جاري معالجة: $name");

          // --- التعديل المدمج: البحث الذكي بالبداية ---
          PlatformFile? matchedImage;
          try {
            matchedImage = imageFiles.firstWhere((file) {
              String fileName = file.name.toLowerCase();
              String barcodeClean = barcode.toLowerCase();
              // التأكد من أن اسم الملف يبدأ بالباركود (يتجاهل الامتداد والمسافات)
              return fileName.startsWith(barcodeClean);
            });
            debugPrint("✅ تم التطابق: ${matchedImage.name}");
          } catch (e) {
            // لو فشل، بيطبع لك أول اسم ملف هو شايفه عشان نعرف العيب فين
            String hint = imageFiles.isNotEmpty ? imageFiles.first.name : "لا توجد صور";
            _showSnackBar(context, "❌ مفيش صورة لـ $barcode (أول ملف: $hint)", isError: true);
            matchedImage = null;
          }

          List<String> urls = [];
          List<String> publicIds = [];

          if (matchedImage != null) {
            var result = await _uploadToCloudinary(matchedImage);
            if (result != null) {
              urls.add(result['url']!);
              publicIds.add(result['public_id']!);
            } else {
              _showSnackBar(context, "⚠️ فشل رفع صورة: $barcode", isError: true);
            }
          }

          // إضافة البيانات لفايربيز
          await FirebaseFirestore.instance.collection('products').add({
            'name': name.trim(),
            'barcode': barcode,
            'description': row[2]?.value?.toString() ?? "",
            'mainId': await _getIdByName('mainCategory', row[3]?.value?.toString() ?? ""),
            'subId': await _getIdByName('subCategory', row[4]?.value?.toString() ?? ""),
            'manufacturerId': await _getIdByName('manufacturers', row[5]?.value?.toString() ?? ""),
            'status': 'active',
            'imageUrls': urls,
            'imagePublicIds': publicIds,
            'unitsWithFactors': _parseUnits(row[6]?.value?.toString() ?? "قطعة:1"),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
      _showDialog(context, "تمت العملية", "تم استيراد كافة المنتجات بنجاح ✅");
    } catch (e) {
      _showDialog(context, "خطأ غير متوقع", e.toString());
    }
  }

  static Future<Map<String, String>?> _uploadToCloudinary(PlatformFile file) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      
      dynamic fileBytes;
      if (kIsWeb) {
        fileBytes = file.bytes;
      } else {
        fileBytes = await File(file.path!).readAsBytes();
      }

      var request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = 'productImages'
        ..files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: file.name));

      var response = await request.send();
      if (response.statusCode == 200) {
        var data = jsonDecode(await response.stream.bytesToString());
        return {'url': data['secure_url'], 'public_id': data['public_id']};
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  static Future<String?> _getIdByName(String collection, String name) async {
    if (name.isEmpty) return null;
    var snap = await FirebaseFirestore.instance
        .collection(collection)
        .where('name', isEqualTo: name.trim())
        .limit(1)
        .get();
    return snap.docs.isNotEmpty ? snap.docs.first.id : null;
  }

  static List<Map<String, dynamic>> _parseUnits(String raw) {
    List<Map<String, dynamic>> list = [];
    for (var u in raw.split(',')) {
      var parts = u.trim().split(':');
      if (parts.isNotEmpty) {
        list.add({
          'unitName': parts[0],
          'subQty': parts.length > 1 ? (int.tryParse(parts[1]) ?? 1) : 1
        });
      }
    }
    return list;
  }

  static void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: isError ? Colors.red : Colors.blueGrey,
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  static void _showDialog(BuildContext context, String title, String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, textAlign: TextAlign.right),
        content: Text(msg, textAlign: TextAlign.right),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("تم"))],
      ),
    );
  }
}
