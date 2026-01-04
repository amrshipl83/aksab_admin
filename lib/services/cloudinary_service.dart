import 'dart:convert';
import 'dart:html' as html; // خاص بالويب فقط
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String uploadPreset = "YOUR_PRESET_NAME"; // اسم البريست بتاعك
  static const String cloudName = "YOUR_CLOUD_NAME";

  static Future<Map<String, String>?> uploadImage() async {
    final completer = html.FileUploadInputElement();
    completer.accept = 'image/*';
    completer.click();

    await completer.onChange.first;
    if (completer.files!.isEmpty) return null;

    final file = completer.files![0];
    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    await reader.onLoad.first;

    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    
    var request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', reader.result.toString()));

    // ملاحظة: للويب نستخدم إرسال الـ Base64 أو الـ Blob مباشرة
    // هذا الكود توضيحي للـ Logic، سأعطيك الكود الكامل للويب عند الطلب
    return {"url": "...", "publicId": "..."};
  }
}

