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

  // الوجهة الذكية
  String _linkType = 'NONE';
  String? _targetId; // هذا سيحمل الـ ID الخاص بالوجهة (المعرف)

  XFile? _selectedImage;
  bool _isUploading = false;

  final String cloudinaryUrl = 'https://api.cloudinary.com/v1_1/dgmmx6jbu/image/upload';
  final String uploadPreset = 'commerce';

  // --- دالة رفع الصور كما هي ---
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
          'linkType': _linkType, // نوع الوجهة (SELLER, RETAILER, CATEGORY...)
          'targetId': _targetId ?? '', // المعرف (ID)
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
          _buildBannersList(),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "اسم البانر", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "مطلوب" : null,
              ),
              const SizedBox(height: 15),
              _buildImagePicker(),
              const SizedBox(height: 15),
              
              // 🎯Dropdown اختيار نوع الوجهة المطور
              DropdownButtonFormField<String>(
                value: _linkType,
                decoration: const InputDecoration(labelText: "ماذا يفتح البانر؟", border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'NONE', child: Text("صورة فقط")),
                  DropdownMenuItem(value: 'CATEGORY', child: Text("قسم رئيسي (مثل: ملابس)")),
                  DropdownMenuItem(value: 'SUB_CATEGORY', child: Text("قسم فرعي (مثل: قمصان)")),
                  DropdownMenuItem(value: 'RETAILER', child: Text("سوبر ماركت (توصيل)")),
                  DropdownMenuItem(value: 'SELLER', child: Text("تاجر محدد (مثل: محل ملابس)")),
                ],
                onChanged: (v) => setState(() { _linkType = v!; _targetId = null; }),
              ),

              if (_linkType != 'NONE') ...[
                const SizedBox(height: 15),
                _buildTargetDropdown(), // المحرك الذي يجلب البيانات من المجموعات
              ],

              const SizedBox(height: 15),
              // ترتيب الظهور وزر الرفع...
              TextFormField(
                controller: _orderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "ترتيب الظهور", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isUploading ? null : _submitForm,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: _isUploading ? const CircularProgressIndicator() : const Text("رفع البانر الذكي"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🎯 المحرك الذكي لجلب الأسماء والمعرفات من المجموعات
  Widget _buildTargetDropdown() {
    String collectionPath;
    String nameField = 'name';

    // تحديد المجموعة والحقل المطلوب بناءً على النوع
    switch (_linkType) {
      case 'CATEGORY':
        collectionPath = 'mainCategory';
        break;
      case 'SUB_CATEGORY':
        collectionPath = 'subCategory';
        break;
      case 'RETAILER':
        collectionPath = 'deliverySupermarkets';
        nameField = 'supermarketName'; // الحقل اللي بتحبه في السوبر ماركت
        break;
      case 'SELLER':
        collectionPath = 'sellers';
        nameField = 'fullname'; // أو 'storeName' حسب المجموعة عندك
        break;
      default:
        return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collectionPath).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        
        return DropdownButtonFormField<String>(
          value: _targetId,
          hint: Text("اختر من قائمة $collectionPath"),
          decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF0F7FF)),
          items: snapshot.data!.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            return DropdownMenuItem(
              value: doc.id, // نرسل الـ ID
              child: Text(data[nameField] ?? 'بدون اسم'), // نعرض الاسم
            );
          }).toList(),
          onChanged: (v) => setState(() => _targetId = v),
          validator: (v) => v == null ? "برجاء الاختيار" : null,
        );
      },
    );
  }

  // ... (باقي ويدجت الـ ImagePicker والـ List كما هي)
}

