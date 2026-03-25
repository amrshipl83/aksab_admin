import 'dart:io';
import 'dart:typed_data'; 
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
        var rows = excel.tables[table]!.rows;
        
        // نبدأ من الصف الثاني (i=1) لتجاهل العناوين
        for (var i = 1; i < rows.length; i++) {
          var row = rows[i];
          
          String name = row[0]?.value?.toString() ?? "";
          
          // تنظيف الباركود من أي تنسيق رقمي زائد (مثل .0) وضمان أنه نص نقي
          String rawBarcode = row[1]?.value?.toString() ?? "";
          String barcode = rawBarcode.split('.').first.trim();
          
          if (barcode.isEmpty || name.isEmpty) continue;

          _showSnackBar(context, "جاري معالجة: $name");

          // الربط بالترتيب: أول منتج يأخذ أول صورة مختارة وهكذا
          PlatformFile? matchedImage;
          int imageIndex = i - 1; 

          if (imageIndex < imageFiles.length) {
            matchedImage = imageFiles[imageIndex];
          } else {
            _showSnackBar(context, "⚠️ لا توجد صورة لمنتج: $name", isError: true);
          }

          List<String> urls = [];
          List<String> publicIds = [];

          if (matchedImage != null) {
            var result = await _uploadToCloudinary(matchedImage);
            if (result != null) {
              urls.add(result['url']!);
              publicIds.add(result['public_id']!);
            }
          }

          // معالجة الوحدات
          String unitsRaw = row[6]?.value?.toString() ?? "قطعة:1";
          List<Map<String, dynamic>> parsedUnits = _parseUnits(unitsRaw);

          // تحويل المصفوفة للشكل القديم (unitName فقط) لضمان توافق التطبيقات الحالية
          List<Map<String, dynamic>> oldStyleUnits = parsedUnits.map((u) => {
            'unitName': u['unitName']
          }).toList();

          // إضافة البيانات لفايربيز مع الالتزام بكافة الحقول المطلوبة
          await FirebaseFirestore.instance.collection('products').add({
            'name': name.trim(),
            'barcode': barcode,
            'description': row[2]?.value?.toString() ?? "",
            'mainId': await _getIdByName('mainCategory', row[3]?.value?.toString() ?? ""),
            'subId': await _getIdByName('subCategory', row[4]?.value?.toString() ?? ""),
            'manufacturerId': await _getIdByName('manufacturers', row[5]?.value?.toString() ?? ""),
            'status': 'active',
            'order': 0, // إضافة حقل الترتيب الافتراضي
            'imageUrls': urls,
            'imagePublicIds': publicIds,
            'units': oldStyleUnits, // الشكل القديم للتوافق
            'unitsWithFactors': parsedUnits, // الشكل الجديد للحسابات اللوجستية
            'createdAt': FieldValue.serverTimestamp(),
          });
          
          // تأخير بسيط لتجنب الضغط على الـ API أثناء الرفع المتتابع
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      _showDialog(context, "تمت العملية", "تم استيراد المنتجات ورفع الصور وربط الوحدات بنجاح ✅");
    } catch (e) {
      _showDialog(context, "خطأ في الاستيراد", e.toString());
    }
  }

  static Future<Map<String, String>?> _uploadToCloudinary(PlatformFile file) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      
      Uint8List fileBytes;
      if (kIsWeb) {
        fileBytes = file.bytes!;
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
        return {
          'url': data['secure_url'], 
          'public_id': data['public_id']
        };
      }
    } catch (e) {
      debugPrint("Cloudinary Upload Error: $e");
      return null;
    }
    return null;
  }

  static Future<String?> _getIdByName(String collection, String name) async {
    if (name.isEmpty) return null;
    try {
      var snap = await FirebaseFirestore.instance.collection(collection)
          .where('name', isEqualTo: name.trim())
          .limit(1)
          .get();
      return snap.docs.isNotEmpty ? snap.docs.first.id : null;
    } catch (e) {
      return null;
    }
  }

  static List<Map<String, dynamic>> _parseUnits(String raw) {
    List<Map<String, dynamic>> list = [];
    try {
      // يتوقع صيغة مثل "قطعة:1,كرتونة:12"
      for (var u in raw.split(',')) {
        var parts = u.trim().split(':');
        if (parts.isNotEmpty && parts[0].isNotEmpty) {
          list.add({
            'unitName': parts[0],
            'subQty': parts.length > 1 ? (int.tryParse(parts[1]) ?? 1) : 1
          });
        }
      }
    } catch (e) {
      list.add({'unitName': 'قطعة', 'subQty': 1});
    }
    return list;
  }

  static void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: isError ? Colors.red : Colors.blueGrey,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  static void _showDialog(BuildContext context, String title, String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')),
        content: Text(msg, textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("تم", style: TextStyle(fontFamily: 'Cairo'))
          )
        ],
      ),
    );
  }
}
