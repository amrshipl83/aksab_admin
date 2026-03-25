import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart'; // عشان kIsWeb

class ExcelImportService {
  static const String cloudName = "dgmmx6jbu";
  static const String uploadPreset = "commerce";

  // دالة مساعدة لجلب الـ ID من الاسم (عشان نربط الأقسام والمصنعين صح)
  static Future<String?> _getIdByName(String collection, String name) async {
    if (name.isEmpty) return null;
    var snap = await FirebaseFirestore.instance
        .collection(collection)
        .where('name', isEqualTo: name.trim())
        .limit(1)
        .get();
    return snap.docs.isNotEmpty ? snap.docs.first.id : null;
  }

  static Future<void> importWithImages({
    required List<PlatformFile> imageFiles,
    required PlatformFile excelFile,
    required Function(String) onProgress,
  }) async {
    var bytes = excelFile.bytes;
    var excel = Excel.decodeBytes(bytes!);

    for (var table in excel.tables.keys) {
      // نبدأ من 1 لتخطي سطر العنوان
      for (var i = 1; i < excel.tables[table]!.maxRows; i++) {
        var row = excel.tables[table]!.rows[i];
        
        String name = row[0]?.value?.toString() ?? "";
        String barcode = row[1]?.value?.toString() ?? "";
        
        if (barcode.isEmpty || name.isEmpty) continue;

        onProgress("جاري معالجة: $name ($barcode)");

        // 1. جلب الـ IDs (مطابقة لليدوي)
        var mId = await _getIdByName('mainCategory', row[3]?.value?.toString() ?? "");
        var sId = await _getIdByName('subCategory', row[4]?.value?.toString() ?? "");
        var mfgId = await _getIdByName('manufacturers', row[5]?.value?.toString() ?? "");

        // 2. معالجة الوحدات (قطعة:1,كرتونة:12)
        List<Map<String, dynamic>> units = [];
        String rawUnits = row[6]?.value?.toString() ?? "قطعة:1";
        for (var u in rawUnits.split(',')) {
          var p = u.trim().split(':');
          if (p.isNotEmpty) {
            units.add({
              'unitName': p[0],
              'subQty': p.length > 1 ? (int.tryParse(p[1]) ?? 1) : 1
            });
          }
        }

        // 3. البحث عن الصورة (مطابقة مرنة للباركود)
        PlatformFile? matchedImage;
        try {
          matchedImage = imageFiles.firstWhere(
            (file) => file.name.split('.').first.trim() == barcode.trim()
          );
        } catch (e) {
          matchedImage = null;
        }

        List<String> urls = [];
        List<String> publicIds = [];

        if (matchedImage != null) {
          // الرفع باستخدام الطريقة المضمونة (Bytes من الـ Path)
          var result = await _uploadToCloudinary(matchedImage);
          if (result != null) {
            urls.add(result['url']!);
            publicIds.add(result['public_id']!);
          }
        }

        // 4. الإضافة لفايربيز بنفس حقول اليدوي بالظبط
        await FirebaseFirestore.instance.collection('products').add({
          'name': name.trim(),
          'barcode': barcode.trim(),
          'description': row[2]?.value?.toString() ?? "",
          'mainId': mId,
          'subId': sId,
          'manufacturerId': mfgId,
          'status': 'active',
          'order': 0,
          'imageUrls': urls,
          'imagePublicIds': publicIds,
          'units': units,
          'unitsWithFactors': units, // الحقل الأساسي في السيستم الجديد
          'createdAt': FieldValue.serverTimestamp(),
        });

        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  static Future<Map<String, String>?> _uploadToCloudinary(PlatformFile file) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      
      // قراءة الـ Bytes بطريقة الأندرويد المضمونة (زي اليدوي)
      Uint8List fileBytes;
      if (kIsWeb) {
        fileBytes = file.bytes!;
      } else {
        fileBytes = await File(file.path!).readAsBytes();
      }

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = 'productImages'
        ..files.add(http.MultipartFile.fromBytes(
          'file', 
          fileBytes, 
          filename: file.name
        ));

      final response = await request.send();
      if (response.statusCode == 200) {
        final data = jsonDecode(await response.stream.bytesToString());
        return {
          'url': data['secure_url'],
          'public_id': data['public_id']
        };
      } else {
        debugPrint("Cloudinary Error Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Upload Exception: $e");
    }
    return null;
  }
}

