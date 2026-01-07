import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

class RetailerBannersTab extends StatefulWidget {
  const RetailerBannersTab({super.key});

  @override
  State<RetailerBannersTab> createState() => _RetailerBannersTabState();
}

class _RetailerBannersTabState extends State<RetailerBannersTab> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _orderController = TextEditingController(text: "0");

  String _linkType = 'NONE';
  String? _targetId;
  XFile? _selectedImage;
  bool _isUploading = false;

  // إعدادات Cloudinary من كود الـ HTML
  final String cloudinaryUrl = 'https://api.cloudinary.com/v1_1/dgmmx6jbu/image/upload';
  final String uploadPreset = 'commerce';

  // دالة رفع الصورة (بنفس منطق uploadToCloudinary في الـ JS)
  Future<String?> _uploadToCloudinary() async {
    if (_selectedImage == null) return null;
    try {
      var request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl));
      request.fields['upload_preset'] = uploadPreset;
      var bytes = await _selectedImage!.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'banner.jpg'));

      var response = await request.send();
      var responseData = await response.stream.toBytes();
      var jsonRes = jsonDecode(utf8.decode(responseData));
      return jsonRes['secure_url'];
    } catch (e) {
      print("Cloudinary Error: $e");
      return null;
    }
  }

  // معالجة الفورم (بنفس منطق handleForm في الـ JS)
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى ملء البيانات واختيار صورة")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      String? imageUrl = await _uploadToCloudinary();
      if (imageUrl != null) {
        // نفس الـ docData الموجود في الـ HTML
        await FirebaseFirestore.instance.collection('retailerBanners').add({
          'name': _nameController.text,
          'imageUrl': imageUrl,
          'order': int.tryParse(_orderController.text) ?? 0,
          'linkType': _linkType,
          'targetId': _targetId,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });

        _resetForm();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الرفع بنجاح!")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _resetForm() {
    _nameController.clear();
    _orderController.text = "0";
    setState(() {
      _selectedImage = null;
      _linkType = 'NONE';
      _targetId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildFormCard(),
          const SizedBox(height: 25),
          const Divider(),
          const Text("البانرات الحالية لتاجر التجزئة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 15),
          _buildBannersList(),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("رفع بانر ذكي لمتجر التجزئة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 15),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "اسم البانر", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "مطلوب" : null,
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _linkType,
                decoration: const InputDecoration(labelText: "نوع الوجهة (أين يذهب المستخدم؟)", border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'NONE', child: Text("بدون وجهة (صورة فقط)")),
                  DropdownMenuItem(value: 'CATEGORY', child: Text("فتح قسم (Category)")),
                  DropdownMenuItem(value: 'RETAILER', child: Text("فتح صفحة تاجر (Seller)")),
                ],
                onChanged: (v) => setState(() { _linkType = v!; _targetId = null; }),
              ),
              if (_linkType != 'NONE') ...[
                const SizedBox(height: 15),
                _buildTargetDropdown(),
              ],
              const SizedBox(height: 15),
              _buildImagePicker(),
              const SizedBox(height: 15),
              TextFormField(
                controller: _orderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "الترتيب", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007bff)),
                  child: _isUploading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("رفع البانر الذكي", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetDropdown() {
    // تحديد المجموعة والحقل بناءً على نوع الوجهة تماماً كما في الـ JS
    String collection = _linkType == 'CATEGORY' ? 'mainCategory' : 'sellers';
    String field = _linkType == 'CATEGORY' ? 'name' : 'fullname';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        
        return DropdownButtonFormField<String>(
          value: _targetId,
          hint: const Text("اختر من القائمة"),
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: snapshot.data!.docs.map((doc) {
            return DropdownMenuItem(
              value: doc.id,
              child: Text(doc.get(field) ?? 'بدون اسم'),
            );
          }).toList(),
          onChanged: (v) => setState(() => _targetId = v),
        );
      },
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("صورة البانر:", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final img = await ImagePicker().pickImage(source: ImageSource.gallery);
            if (img != null) setState(() => _selectedImage = img);
          },
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[100],
            ),
            child: _selectedImage == null
                ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.cloud_upload, size: 40), Text("اضغط لاختيار صورة")])
                : Image.network(_selectedImage!.path, fit: BoxFit.contain),
          ),
        ),
      ],
    );
  }

  Widget _buildBannersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('retailerBanners').orderBy('order', descending: false).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Text("لا توجد بانرات.");

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(data['imageUrl'], width: 60, height: 60, fit: BoxFit.cover),
                ),
                title: Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("الوجهة: ${data['linkType'] ?? 'بدون'}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDelete(doc.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(String docId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("حذف؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("حذف", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('retailerBanners').doc(docId).delete();
    }
  }
}

