import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ExcelImportService {
  static const String cloudName = "dgmmx6jbu";
  static const String uploadPreset = "commerce";

  static Future<void> importWithImages({
    required List<PlatformFile> imageFiles,
    required PlatformFile excelFile,
    required Function(String) onProgress,
  }) async {
    var bytes = excelFile.bytes;
    var excel = Excel.decodeBytes(bytes!);

    for (var table in excel.tables.keys) {
      for (var i = 1; i < excel.tables[table]!.maxRows; i++) {
        var row = excel.tables[table]!.rows[i];
        String barcode = row[1]?.value?.toString() ?? "";
        if (barcode.isEmpty) continue;

        onProgress("جاري معالجة المنتج: $barcode");

        // البحث عن صورة تطابق الباركود في القائمة المختارة
        PlatformFile? matchedImage;
        try {
          matchedImage = imageFiles.firstWhere(
            (file) => file.name.split('.').first == barcode
          );
        } catch (e) { matchedImage = null; }

        List<String> urls = [];
        if (matchedImage != null) {
          // رفع الصورة إذا وجدت
          var url = await _uploadToCloudinary(matchedImage);
          if (url != null) urls.add(url);
        }

        // إضافة لفايربيز (مثال مختصر للبيانات)
        await FirebaseFirestore.instance.collection('products').add({
          'name': row[0]?.value?.toString() ?? "منتج بدون اسم",
          'barcode': barcode,
          'imageUrls': urls,
          'createdAt': FieldValue.serverTimestamp(),
          // ضيف باقي الحقول هنا (أقسام، وحدات... إلخ)
        });
      }
    }
  }

  static Future<String?> _uploadToCloudinary(PlatformFile file) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = 'productImages'
        ..files.add(http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name));

      final response = await request.send();
      if (response.statusCode == 200) {
        final data = jsonDecode(await response.stream.bytesToString());
        return data['secure_url'];
      }
    } catch (e) { return null; }
    return null;
  }
}

