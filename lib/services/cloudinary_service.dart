import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  // 💡 ضع قيمك هنا لتجنب الخطأ
  static const String uploadPreset = "commerce"; 
  static const String cloudName = "dgmmx6jbu";

  static Future<Map<String, String>?> uploadImage(XFile xFile) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      
      // في الويب نستخدم readAsBytes بدلاً من Path
      final bytes = await xFile.readAsBytes();
      
      var request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: xFile.name,
        ));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        var json = jsonDecode(responseData);
        return {
          "url": json['secure_url'],
          "publicId": json['public_id']
        };
      } else {
        print("Cloudinary Error: $responseData");
        return null;
      }
    } catch (e) {
      print("Upload Error: $e");
      return null;
    }
  }
}

