import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class MainCategoryTab extends StatefulWidget {
  const MainCategoryTab({super.key});

  @override
  State<MainCategoryTab> createState() => _MainCategoryTabState();
}

class _MainCategoryTabState extends State<MainCategoryTab> {
  // المتحكمات والمتغيرات
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _orderController = TextEditingController();
  String _selectedBehavior = 'supermarket_offers'; 
  File? _selectedImage;
  bool _isLoading = false;

  // إعدادات Cloudinary (استبدل القيم ببيانات حسابك)
  final String cloudName = "your_cloud_name"; 
  final String uploadPreset = "your_preset";

  // اختيار صورة من المعرض
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  // دالة رفع الصورة إلى Cloudinary والحصول على الرابط
  Future<String?> _uploadImage(File imageFile) async {
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();
    if (response.statusCode == 200) {
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);
      final jsonResponse = jsonDecode(responseString);
      return jsonResponse['secure_url'];
    }
    return null;
  }

  // دالة الحفظ النهائية في Firestore
  Future<void> _saveCategory() async {
    if (_nameController.text.isEmpty || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى إدخال الاسم واختيار صورة")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. رفع الصورة أولاً
      String? imageUrl = await _uploadImage(_selectedImage!);

      if (imageUrl != null) {
        // 2. حفظ البيانات في كولكشن mainCategory
        await FirebaseFirestore.instance.collection('mainCategory').add({
          'name': _nameController.text,
          'order': int.tryParse(_orderController.text) ?? 0,
          'offerBehavior': _selectedBehavior,
          'imageUrl': imageUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // مسح الحقول بعد النجاح
        _nameController.clear();
        _orderController.clear();
        setState(() => _selectedImage = null);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم إضافة القسم بنجاح")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("حدث خطأ: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // حقل اسم القسم
          TextField(
            controller: _nameController,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: "اسم القسم الرئيسي",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 15),

          // حقل الترتيب
          TextField(
            controller: _orderController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: "رقم الترتيب (مثلاً: 1)",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 15),

          // اختيار سلوك العرض
          DropdownButtonFormField<String>(
            value: _selectedBehavior,
            decoration: const InputDecoration(labelText: "سلوك العرض"),
            items: const [
              DropdownMenuItem(value: 'supermarket_offers', child: Text("عروض السوبر ماركت")),
              DropdownMenuItem(value: 'direct_seller_offers', child: Text("عروض التاجر")),
            ],
            onChanged: (val) => setState(() => _selectedBehavior = val!),
          ),
          const SizedBox(height: 20),

          // معاينة الصورة المختارة
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blueAccent),
              ),
              child: _selectedImage == null
                  ? const Center(child: Text("اضغط هنا لرفع صورة القسم"))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    ),
            ),
          ),
          const SizedBox(height: 25),

          // زر الإضافة
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4361ee),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: _isLoading ? null : _saveCategory,
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("إضافة القسم", style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
          ),

          const Divider(height: 50, thickness: 2),

          // عرض الأقسام الحالية من الداتابيز
          const Text("الأقسام الحالية المضافة", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('mainCategory').orderBy('order').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Text("لا توجد أقسام مضافة حالياً");

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Image.network(doc['imageUrl'], width: 60, height: 60, fit: BoxFit.cover),
                      title: Text(doc['name'], textAlign: TextAlign.right),
                      subtitle: Text("ترتيب: ${doc['order']}", textAlign: TextAlign.right),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => FirebaseFirestore.instance.collection('mainCategory').doc(doc.id).delete(),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

