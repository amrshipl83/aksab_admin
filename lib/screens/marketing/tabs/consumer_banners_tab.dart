// lib/screens/marketing/tabs/consumer_banners_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

class ConsumerBannersTab extends StatefulWidget {
  const ConsumerBannersTab({super.key});

  @override
  State<ConsumerBannersTab> createState() => _ConsumerBannersTabState();
}

class _ConsumerBannersTabState extends State<ConsumerBannersTab> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _orderController = TextEditingController(text: "0");

  String _targetAudience = 'general';
  String? _selectedOwnerId;
  String _linkType = 'NONE';
  String? _targetId;
  XFile? _selectedImage;
  bool _isUploading = false;

  final String cloudinaryUrl = 'https://api.cloudinary.com/v1_1/dgmmx6jbu/image/upload';
  final String uploadPreset = 'commerce';

  // --- دالة رفع الصور ---
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
      return null;
    }
  }

  // --- دالة الحفظ ---
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("أكمل البيانات والصورة")));
      return;
    }
    setState(() => _isUploading = true);
    try {
      String? imageUrl = await _uploadToCloudinary();
      if (imageUrl != null) {
        await FirebaseFirestore.instance.collection('consumerBanners').add({
          'name': _nameController.text,
          'imageUrl': imageUrl,
          'linkType': _linkType,
          'targetId': _targetId ?? '',
          'targetAudience': _targetAudience,
          'ownerId': _targetAudience == 'dealer' ? _selectedOwnerId : '',
          'order': int.tryParse(_orderController.text) ?? 0,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });
        _resetForm();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الرفع بنجاح")));
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _resetForm() {
    _nameController.clear();
    _orderController.text = "0";
    setState(() { _selectedImage = null; _linkType = 'NONE'; _targetId = null; });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildFormCard(),
          const SizedBox(height: 25),
          const Text("البانرات الحالية", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 15),
          _buildBannersList(), // ✅ الآن أصبحت معرفة بالأسفل
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: "اسم البانر")),
              const SizedBox(height: 15),
              _buildImagePicker(), // ✅ الآن أصبحت معرفة بالأسفل
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _linkType,
                items: const [
                  DropdownMenuItem(value: 'NONE', child: Text("بدون وجهة")),
                  DropdownMenuItem(value: 'CATEGORY', child: Text("قسم رئيسي")),
                  DropdownMenuItem(value: 'SUB_CATEGORY', child: Text("قسم فرعي")),
                  DropdownMenuItem(value: 'RETAILER', child: Text("سوبر ماركت")),
                  DropdownMenuItem(value: 'SELLER', child: Text("تاجر")),
                ],
                onChanged: (v) => setState(() { _linkType = v!; _targetId = null; }),
              ),
              if (_linkType != 'NONE') _buildTargetDropdown(),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _isUploading ? null : _submitForm, child: Text(_isUploading ? "جارِ الرفع..." : "رفع الآن")),
            ],
          ),
        ),
      ),
    );
  }

  // 1️⃣ دالة اختيار الصور (اللي كانت ناقصة)
  Widget _buildImagePicker() {
    return InkWell(
      onTap: () async {
        final img = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (img != null) setState(() => _selectedImage = img);
      },
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
        child: _selectedImage == null
            ? const Icon(Icons.add_a_photo, size: 50, color: Colors.grey)
            : Image.network(_selectedImage!.path, fit: BoxFit.contain),
      ),
    );
  }

  // 2️⃣ دالة عرض القائمة (اللي كانت ناقصة)
  Widget _buildBannersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('consumerBanners').orderBy('order').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                leading: Image.network(data['imageUrl'], width: 50),
                title: Text(data['name'] ?? ''),
                trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => doc.reference.delete()),
              ),
            );
          },
        );
      },
    );
  }

  // دالة جلب الوجهات
  Widget _buildTargetDropdown() {
    String collection = _linkType == 'CATEGORY' ? 'mainCategory' : (_linkType == 'SUB_CATEGORY' ? 'subCategory' : (_linkType == 'RETAILER' ? 'deliverySupermarkets' : 'sellers'));
    String nameField = (_linkType == 'RETAILER') ? 'supermarketName' : (_linkType == 'SELLER' ? 'fullname' : 'name');

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        return DropdownButtonFormField<String>(
          value: _targetId,
          items: snapshot.data!.docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc.get(nameField) ?? 'بدون اسم'))).toList(),
          onChanged: (v) => setState(() => _targetId = v),
        );
      },
    );
  }
}

