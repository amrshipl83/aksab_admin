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
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _orderController = TextEditingController(text: "0");

  String _targetAudience = 'general'; // الجمهور المستهدف
  String? _selectedDealerId;
  XFile? _selectedImage;
  bool _isUploading = false;

  // إعدادات Cloudinary المتطابقة مع الـ HTML
  final String cloudinaryUrl = 'https://api.cloudinary.com/v1_1/dgmmx6jbu/image/upload';
  final String uploadPreset = 'commerce';

  Future<String?> _uploadToCloudinary() async {
    if (_selectedImage == null) return null;
    try {
      var request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl));
      request.fields['upload_preset'] = uploadPreset;
      var bytes = await _selectedImage!.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: 'consumer_banner.jpg'));

      var response = await request.send();
      var responseData = await response.stream.toBytes();
      var jsonRes = jsonDecode(utf8.decode(responseData));
      return jsonRes['secure_url'];
    } catch (e) {
      debugPrint("Cloudinary Error: $e");
      return null;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("برجاء إكمال البيانات وصورة البانر")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      String? imageUrl = await _uploadToCloudinary();
      if (imageUrl != null) {
        // نفس الحقول المطلوبة في الـ HTML
        await FirebaseFirestore.instance.collection('consumerBanners').add({
          'name': _nameController.text,
          'imageUrl': imageUrl,
          'link': _linkController.text,
          'targetAudience': _targetAudience,
          'ownerId': _targetAudience == 'dealer' ? _selectedDealerId : '',
          'order': int.tryParse(_orderController.text) ?? 0,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });

        _resetForm();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم رفع بانر المستهلك بنجاح!")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _resetForm() {
    _nameController.clear();
    _linkController.clear();
    _orderController.text = "0";
    setState(() {
      _selectedImage = null;
      _targetAudience = 'general';
      _selectedDealerId = null;
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
          const Text("البانرات الحالية للمستهلك", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 15),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("رفع بانر لمتجر المستهلك", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "اسم البانر", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "مطلوب" : null,
              ),
              const SizedBox(height: 15),
              _buildImagePicker(),
              const SizedBox(height: 15),
              TextFormField(
                controller: _linkController,
                decoration: const InputDecoration(labelText: "رابط البانر (Link)", hintText: "الرابط القديم أو وجهة مخصصة", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _targetAudience,
                decoration: const InputDecoration(labelText: "الجمهور المستهدف", border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'general', child: Text("عام (يظهر للجميع)")),
                  DropdownMenuItem(value: 'dealer', child: Text("تاجر محدد")),
                ],
                onChanged: (v) => setState(() { _targetAudience = v!; _selectedDealerId = null; }),
              ),
              if (_targetAudience == 'dealer') ...[
                const SizedBox(height: 15),
                _buildDealerDropdown(),
              ],
              const SizedBox(height: 15),
              TextFormField(
                controller: _orderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "ترتيب الظهور", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: _isUploading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("رفع البانر الآن", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDealerDropdown() {
    return StreamBuilder<QuerySnapshot>(
      // نستخدم هنا الكولكشن deliverySupermarkets التي تواصلنا بخصوصها مسبقاً
      stream: FirebaseFirestore.instance.collection('deliverySupermarkets').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        return DropdownButtonFormField<String>(
          value: _selectedDealerId,
          hint: const Text("اختر التاجر"),
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: snapshot.data!.docs.map((doc) {
            return DropdownMenuItem(
              value: doc.id,
              child: Text(doc.get('supermarketName') ?? 'بدون اسم'),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedDealerId = v),
          validator: (v) => _targetAudience == 'dealer' && v == null ? "برجاء اختيار تاجر" : null,
        );
      },
    );
  }

  Widget _buildImagePicker() {
    return InkWell(
      onTap: () async {
        final img = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (img != null) setState(() => _selectedImage = img);
      },
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8), color: Colors.grey[50]),
        child: _selectedImage == null
            ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey), Text("اختر صورة البانر")])
            : Image.network(_selectedImage!.path, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildBannersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('consumerBanners').orderBy('order').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                leading: Image.network(data['imageUrl'], width: 50, height: 50, fit: BoxFit.cover),
                title: Text(data['name'] ?? ''),
                subtitle: Text("الوجهة: ${data['link']}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteBanner(doc.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _deleteBanner(String id) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("حذف البانر؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("حذف")),
        ],
      ),
    );
    if (confirm) await FirebaseFirestore.instance.collection('consumerBanners').doc(id).delete();
  }
}

