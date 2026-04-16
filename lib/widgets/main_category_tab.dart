import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image/image.dart' as img; // مكتبة الضغط
import 'dart:typed_data'; // للتعامل مع الـ Bytes في الويب

class MainCategoryTab extends StatefulWidget {
  const MainCategoryTab({super.key});

  @override
  State<MainCategoryTab> createState() => _MainCategoryTabState();
}

class _MainCategoryTabState extends State<MainCategoryTab> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _orderController = TextEditingController();
  final ScrollController _scrollController = ScrollController(); // للتحكم في الصعود لأعلى

  XFile? _selectedImage;
  String? _existingImageUrl;
  String? _editingDocId;
  bool _isLoading = false;
  bool _isForConsumer = false; // المتغير الخاص بالشيك بوكس

  final String cloudName = "dgmmx6jbu";
  final String uploadPreset = "commerce";

  // فانكشن ضغط الصور المخصصة للويب
  Future<Uint8List> _compressWebImage(Uint8List bytes) async {
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return bytes;

    // تصغير العرض لـ 800 بكسل لصور الأقسام للحفاظ على مساحة كلوديناري
    if (image.width > 800) {
      image = img.copyResize(image, width: 800);
    }

    // ضغط الصورة بجودة 70% وتحويلها لـ JPG
    return Uint8List.fromList(img.encodeJpg(image, quality: 70));
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
        _existingImageUrl = null;
      });
    }
  }

  void _prepareUpdate(DocumentSnapshot doc) {
    setState(() {
      _editingDocId = doc.id;
      _nameController.text = doc['name'];
      _orderController.text = doc['order'].toString();
      _existingImageUrl = doc['imageUrl'];
      _selectedImage = null;

      // قراءة حالة متاح للمستهلك
      final behavior = doc.data().toString().contains('offerBehavior') ? doc['offerBehavior'] : "";
      _isForConsumer = (behavior == "supermarket_offers");
    });

    // 🚀 التحديث يطلعك فوق أوتوماتيكياً
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
  }

  void _resetForm() {
    setState(() {
      _editingDocId = null;
      _nameController.clear();
      _orderController.clear();
      _selectedImage = null;
      _existingImageUrl = null;
      _isForConsumer = false;
    });
  }

  // رسالة نجاح في منتصف الشاشة
  void _showSuccessDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 15),
            Text(msg, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("تم"))],
      ),
    );
  }

  Future<Map<String, String>?> _uploadToCloudinary(XFile xFile) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      
      // 1. قراءة البيانات الأصلية
      Uint8List originalBytes = await xFile.readAsBytes();
      
      // 2. تطبيق الضغط لتقليل استهلاك الكريديت في كلوديناري
      Uint8List compressedBytes = await _compressWebImage(originalBytes);

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = 'mainCategoryImages'
        // 3. رفع البيانات المضغوطة
        ..files.add(http.MultipartFile.fromBytes(
          'file', 
          compressedBytes, 
          filename: 'compressed_${xFile.name}.jpg'
        ));

      final response = await request.send();
      if (response.statusCode == 200) {
        final data = jsonDecode(await response.stream.bytesToString());
        return {'url': data['secure_url'], 'public_id': data['public_id']};
      }
    } catch (e) { print("Upload Error: $e"); }
    return null;
  }

  Future<void> _saveMainCategory() async {
    if (_nameController.text.isEmpty || (_selectedImage == null && _existingImageUrl == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إدخال الاسم والصورة")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? finalImageUrl = _existingImageUrl;
      String? finalPublicId;

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
        'updatedAt': FieldValue.serverTimestamp(),
        // 💡 إضافة الحقل المطلوب بالمنطق اللي طلبته
        'offerBehavior': _isForConsumer ? "supermarket_offers" : "",
      };

      if (finalPublicId != null) data['imagePublicId'] = finalPublicId;

      if (_editingDocId != null) {
        await FirebaseFirestore.instance.collection('mainCategory').doc(_editingDocId).update(data);
        _showSuccessDialog("تم تحديث القسم بنجاح");
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('mainCategory').add(data);
        _showSuccessDialog("تم إضافة القسم بنجاح");
        _resetForm(); // في حالة الإضافة الجديدة فقط نمسح الحقول
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController, // ربط السكرول
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(controller: _nameController, textAlign: TextAlign.right, decoration: const InputDecoration(labelText: "اسم القسم الرئيسي", border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: _orderController, keyboardType: TextInputType.number, textAlign: TextAlign.right, decoration: const InputDecoration(labelText: "الترتيب", border: OutlineInputBorder())),
          const SizedBox(height: 15),

          // 💡 الشيك بوكس الجديد
          CheckboxListTile(
            title: const Text("متاح للمستهلك (عروض سوبر ماركت)", textAlign: TextAlign.right),
            value: _isForConsumer,
            activeColor: const Color(0xFF4361ee),
            onChanged: (val) => setState(() => _isForConsumer = val ?? false),
            controlAffinity: ListTileControlAffinity.leading,
          ),

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
                        ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
                        : Image.network(_existingImageUrl!, fit: BoxFit.cover),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (_editingDocId != null)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: ElevatedButton(
                      onPressed: _resetForm,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                      child: const Text("إلغاء التعديل", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveMainCategory,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4361ee)),
                  child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_editingDocId == null ? "حفظ القسم الرئيسي" : "تحديث البيانات الآن", style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
          const Divider(height: 40),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('mainCategory').orderBy('order').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  bool isPromo = (doc.data().toString().contains('offerBehavior') && doc['offerBehavior'] == "supermarket_offers");

                  return ListTile(
                    leading: CircleAvatar(backgroundImage: NetworkImage(doc['imageUrl'])),
                    title: Text(doc['name']),
                    subtitle: Text("ترتيب: ${doc['order']} ${isPromo ? ' | 🎁 عرض' : ''}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _prepareUpdate(doc)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _showDeleteDialog(doc.id)),
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

  void _showDeleteDialog(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تنبيه الحذف"),
        content: const Text("هل أنت متأكد من حذف هذا القسم نهائياً؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('mainCategory').doc(id).delete();
              Navigator.pop(ctx);
            },
            child: const Text("حذف", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

