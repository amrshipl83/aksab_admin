import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SubCategoryTab extends StatefulWidget {
  const SubCategoryTab({super.key});

  @override
  State<SubCategoryTab> createState() => _SubCategoryTabState();
}

class _SubCategoryTabState extends State<SubCategoryTab> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _orderController = TextEditingController();

  String? _selectedMainId; 
  XFile? _selectedImage; // التغيير هنا: استخدام XFile بدلاً من File
  bool _isLoading = false;

  final String cloudName = "dgmmx6jbu";
  final String uploadPreset = "commerce";

  // --- دالة اختيار صورة (متوافقة مع الويب) ---
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImage = pickedFile);
    }
  }

  // --- دالة رفع الصورة (إرسال Bytes بدلاً من Path) ---
  Future<Map<String, String>?> _uploadToCloudinary(XFile xFile) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      
      // قراءة الملف كـ Bytes للويب
      final bytes = await xFile.readAsBytes();
      
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = 'subCategoryImages'
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: xFile.name,
        ));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonResponse = jsonDecode(responseData);
        return {
          'url': jsonResponse['secure_url'],
          'public_id': jsonResponse['public_id'],
        };
      }
    } catch (e) {
      print("Upload Error: $e");
    }
    return null;
  }

  // --- دالة الحذف ---
  Future<void> _confirmDelete(String docId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text("تأكيد الحذف"),
          content: const Text("هل أنت متأكد من حذف هذا القسم الفرعي؟"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("حذف الآن", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('subCategory').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الحذف بنجاح")));
    }
  }

  // --- دالة الحفظ النهائي ---
  Future<void> _saveSubCategory() async {
    if (_nameController.text.isEmpty || _selectedMainId == null || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("أكمل البيانات: الاسم، القسم، والصورة")));
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
          'imagePublicId': uploadResult['public_id'],
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });

        _clearForm();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تمت الإضافة بنجاح")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل رفع الصورة")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _orderController.clear();
    setState(() {
      _selectedImage = null;
      _selectedMainId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: "اسم القسم الفرعي", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('mainCategory').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              return DropdownButtonFormField<String>(
                value: _selectedMainId,
                hint: const Text("اختر القسم الرئيسي"),
                isExpanded: true,
                items: snapshot.data!.docs.map((doc) {
                  return DropdownMenuItem(value: doc.id, child: Text(doc['name'], textAlign: TextAlign.right));
                }).toList(),
                onChanged: (val) => setState(() => _selectedMainId = val),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              );
            },
          ),
          const SizedBox(height: 15),

          TextField(
            controller: _orderController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: "رقم الترتيب", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),

          // المعاينة هنا تعمل في الويب باستخدام Image.network
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(border: Border.all(color: Colors.blue[200]!), borderRadius: BorderRadius.circular(10)),
              child: _selectedImage == null
                  ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.cloud_upload, size: 40), Text("اضغط لرفع الصورة")])
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(_selectedImage!.path, fit: BoxFit.cover),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: _isLoading ? null : _saveSubCategory,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: const Color(0xFF4361ee)),
            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("إضافة قسم فرعي", style: TextStyle(color: Colors.white, fontSize: 18)),
          ),

          const Divider(height: 40),
          const Text("الأقسام الفرعية المضافة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 10),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('subCategory').orderBy('order').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  return Card(
                    child: ListTile(
                      leading: Image.network(doc['imageUrl'], width: 50, errorBuilder: (c, e, s) => const Icon(Icons.error)),
                      title: Text(doc['name']),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(doc.id),
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

