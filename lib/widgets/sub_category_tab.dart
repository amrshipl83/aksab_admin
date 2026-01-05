import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class SubCategoryTab extends StatefulWidget {
  const SubCategoryTab({super.key});

  @override
  State<SubCategoryTab> createState() => _SubCategoryTabState();
}

class _SubCategoryTabState extends State<SubCategoryTab> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _orderController = TextEditingController();
  
  String? _selectedMainId; // القسم الرئيسي المختار
  File? _selectedImage;
  bool _isLoading = false;

  // إعدادات Cloudinary (استخدم بياناتك الحقيقية)
  final String cloudName = "dgmmx6jbu"; 
  final String uploadPreset = "commerce";

  // --- دالة اختيار صورة ---
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  // --- دالة رفع الصورة إلى Cloudinary مع الحصول على الـ Public ID ---
  Future<Map<String, String>?> _uploadToCloudinary(File imageFile) async {
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder'] = 'subCategoryImages'
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();
    if (response.statusCode == 200) {
      final responseData = await response.stream.toBytes();
      final jsonResponse = jsonDecode(String.fromCharCodes(responseData));
      return {
        'url': jsonResponse['secure_url'],
        'public_id': jsonResponse['public_id'],
      };
    }
    return null;
  }

  // --- دالة الحذف مع رسالة تأكيد ---
  Future<void> _confirmDelete(String docId, String? publicId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text("تأكيد الحذف"),
          content: const Text("هل أنت متأكد من حذف هذا القسم الفرعي؟ سيتم حذف المنتجات المرتبطة به أيضاً كما في الـ Web."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("حذف", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('subCategory').doc(docId).delete();
      // ملاحظة: حذف الصورة من كلودناري يتطلب Token أمان أو Backend
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الحذف بنجاح")));
    }
  }

  // --- دالة الحفظ ---
  Future<void> _saveSubCategory() async {
    if (_nameController.text.isEmpty || _selectedMainId == null || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إكمال كافة البيانات")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uploadResult = await _uploadToCloudinary(_selectedImage!);
      if (uploadResult != null) {
        await FirebaseFirestore.instance.collection('subCategory').add({
          'name': _nameController.text.trim(),
          'mainId': _selectedMainId,
          'order': int.tryParse(_orderController.text) ?? 0,
          'imageUrl': uploadResult['url'],
          'imagePublicId': uploadResult['public_id'], // حفظ الـ ID كما طلبت
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        _nameController.clear();
        _orderController.clear();
        setState(() {
          _selectedImage = null;
          _selectedMainId = null;
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // اسم القسم الفرعي
          TextField(
            controller: _nameController,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: "اسم القسم الفرعي", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),

          // اختيار القسم الرئيسي (من Firestore)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('mainCategory').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              var items = snapshot.data!.docs;
              return DropdownButtonFormField<String>(
                value: _selectedMainId,
                hint: const Text("اختر القسم الرئيسي"),
                isExpanded: true,
                items: items.map((doc) {
                  return DropdownMenuItem(
                    value: doc.id,
                    child: Text(doc['name'], textAlign: TextAlign.right),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedMainId = val),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              );
            },
          ),
          const SizedBox(height: 15),

          // الترتيب
          TextField(
            controller: _orderController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: "رقم الترتيب", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),

          // اختيار صورة
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(border: Border.all(color: Colors.blue), borderRadius: BorderRadius.circular(10)),
              child: _selectedImage == null 
                ? const Center(child: Text("اضغط لرفع صورة القسم الفرعي"))
                : Image.file(_selectedImage!, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 20),

          // زر الإضافة
          ElevatedButton(
            onPressed: _isLoading ? null : _saveSubCategory,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            child: _isLoading ? const CircularProgressIndicator() : const Text("إضافة قسم فرعي"),
          ),

          const Divider(height: 40),

          // قائمة الأقسام الفرعية الحالية
          const Text("الأقسام الفرعية الحالية", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('subCategory').orderBy('order').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  return Card(
                    child: ListTile(
                      leading: Image.network(doc['imageUrl'], width: 50),
                      title: Text(doc['name']),
                      subtitle: Text("الترتيب: ${doc['order']}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(doc.id, doc['imagePublicId']),
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

