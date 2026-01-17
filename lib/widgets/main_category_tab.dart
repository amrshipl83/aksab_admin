import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MainCategoryTab extends StatefulWidget {
  const MainCategoryTab({super.key});

  @override
  State<MainCategoryTab> createState() => _MainCategoryTabState();
}

class _MainCategoryTabState extends State<MainCategoryTab> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _orderController = TextEditingController();
  XFile? _selectedImage;
  String? _existingImageUrl; // لحفظ رابط الصورة الحالية عند التعديل
  String? _editingDocId;    // المعرف الخاص بالقسم الذي يتم تعديله حالياً
  bool _isLoading = false;

  final String cloudName = "dgmmx6jbu";
  final String uploadPreset = "commerce";

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
        _existingImageUrl = null; // بمجرد اختيار صورة جديدة، نلغي القديمة
      });
    }
  }

  // دالة لبدء وضع التعديل
  void _prepareUpdate(DocumentSnapshot doc) {
    setState(() {
      _editingDocId = doc.id;
      _nameController.text = doc['name'];
      _orderController.text = doc['order'].toString();
      _existingImageUrl = doc['imageUrl'];
      _selectedImage = null; // لم نختر ملفاً جديداً بعد
    });
  }

  // دالة لمسح الحقول والعودة لوضع الإضافة
  void _resetForm() {
    setState(() {
      _editingDocId = null;
      _nameController.clear();
      _orderController.clear();
      _selectedImage = null;
      _existingImageUrl = null;
    });
  }

  Future<Map<String, String>?> _uploadToCloudinary(XFile xFile) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final bytes = await xFile.readAsBytes();
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = 'mainCategoryImages'
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: xFile.name));

      final response = await request.send();
      if (response.statusCode == 200) {
        final data = jsonDecode(await response.stream.bytesToString());
        return {'url': data['secure_url'], 'public_id': data['public_id']};
      }
    } catch (e) { print("Upload Error: $e"); }
    return null;
  }

  Future<void> _saveMainCategory() async {
    // التحقق: إذا كان تعديل، الصورة ليست إجبارية (ممكن نعدل الاسم فقط)
    if (_nameController.text.isEmpty || (_selectedImage == null && _existingImageUrl == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إدخال الاسم والصورة")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? finalImageUrl = _existingImageUrl;
      String? finalPublicId;

      // إذا اختار المستخدم صورة جديدة، نرفعها
      if (_selectedImage != null) {
        final uploadResult = await _uploadToCloudinary(_selectedImage!);
        if (uploadResult != null) {
          finalImageUrl = uploadResult['url'];
          finalPublicId = uploadResult['public_id'];
        }
      }

      final Map<String, dynamic> data = {
        'name': _nameController.text.trim(),
        'order': int.tryParse(_orderController.text) ?? 0,
        'imageUrl': finalImageUrl,
        'status': 'active',
      };
      if (finalPublicId != null) data['imagePublicId'] = finalPublicId;

      if (_editingDocId != null) {
        // تحديث (Update)
        await FirebaseFirestore.instance.collection('mainCategory').doc(_editingDocId).update(data);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تحديث القسم بنجاح")));
      } else {
        // إضافة جديد (Add)
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('mainCategory').add(data);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إضافة القسم بنجاح")));
      }

      _resetForm();
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
          TextField(controller: _nameController, textAlign: TextAlign.right, decoration: const InputDecoration(labelText: "اسم القسم الرئيسي", border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: _orderController, keyboardType: TextInputType.number, textAlign: TextAlign.right, decoration: const InputDecoration(labelText: "الترتيب", border: OutlineInputBorder())),
          const SizedBox(height: 15),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 150, width: double.infinity,
              decoration: BoxDecoration(border: Border.all(color: Colors.blue[200]!), borderRadius: BorderRadius.circular(10)),
              child: (_selectedImage == null && _existingImageUrl == null)
                  ? const Center(child: Text("اضغط لرفع صورة القسم الرئيسي"))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _selectedImage != null 
                        ? Image.network(_selectedImage!.path, fit: BoxFit.cover) // عرض صورة من الجهاز
                        : Image.network(_existingImageUrl!, fit: BoxFit.cover), // عرض صورة من السيرفر عند التعديل
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (_editingDocId != null) // زر إلغاء التعديل
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: ElevatedButton(
                      onPressed: _resetForm,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                      child: const Text("إلغاء", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveMainCategory,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4361ee)),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text(_editingDocId == null ? "حفظ القسم الرئيسي" : "تحديث البيانات", style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
          const Divider(height: 40),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('mainCategory').orderBy('order').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  return ListTile(
                    leading: CircleAvatar(backgroundImage: NetworkImage(doc['imageUrl'])),
                    title: Text(doc['name']),
                    subtitle: Text("ترتيب: ${doc['order']}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _prepareUpdate(doc)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), 
                          onPressed: () => _showDeleteDialog(doc.id)),
                      ],
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

  // حماية إضافية: تنبيه قبل الحذف
  void _showDeleteDialog(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تنبيه"),
        content: const Text("هل أنت متأكد من حذف القسم؟ سيؤثر هذا على البيانات المرتبطة به."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('mainCategory').doc(id).delete();
              Navigator.pop(ctx);
            }, 
            child: const Text("حذف", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }
}

