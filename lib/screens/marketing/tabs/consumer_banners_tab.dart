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

  // الجمهور المستهدف (عام أو تاجر محدد)
  String _targetAudience = 'general'; 
  String? _selectedOwnerId;

  // الوجهة الذكية (مثل البانر التاجر)
  String _linkType = 'NONE';
  String? _targetId;
  
  XFile? _selectedImage;
  bool _isUploading = false;

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
    _orderController.text = "0";
    setState(() {
      _selectedImage = null;
      _targetAudience = 'general';
      _selectedOwnerId = null;
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
              
              // --- اختيار نوع الوجهة (نفس منطق التاجر) ---
              DropdownButtonFormField<String>(
                value: _linkType,
                decoration: const InputDecoration(labelText: "نوع الوجهة (أين يذهب المستخدم؟)", border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'NONE', child: Text("بدون وجهة (صورة فقط)")),
                  DropdownMenuItem(value: 'CATEGORY', child: Text("فتح قسم رئيسي")),
                  DropdownMenuItem(value: 'SUB_CATEGORY', child: Text("فتح قسم فرعي (منتجات)")),
                  DropdownMenuItem(value: 'RETAILER', child: Text("فتح صفحة تاجر توصيل")),
                ],
                onChanged: (v) => setState(() { _linkType = v!; _targetId = null; }),
              ),
              if (_linkType != 'NONE') ...[
                const SizedBox(height: 15),
                _buildTargetDropdown(), // الدالة التي تجلب البيانات بناءً على النوع
              ],

              const SizedBox(height: 15),
              // --- اختيار الجمهور المستهدف ---
              DropdownButtonFormField<String>(
                value: _targetAudience,
                decoration: const InputDecoration(labelText: "الجمهور المستهدف", border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'general', child: Text("عام (يظهر للجميع)")),
                  DropdownMenuItem(value: 'dealer', child: Text("يظهر لتجار محددين")),
                ],
                onChanged: (v) => setState(() { _targetAudience = v!; _selectedOwnerId = null; }),
              ),
              if (_targetAudience == 'dealer') ...[
                const SizedBox(height: 15),
                _buildDealerSelector(), // لاختيار التاجر الذي سيظهر له البانر
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

  // دالة جلب الوجهات (أقسام، أقسام فرعية، تجار توصيل)
  Widget _buildTargetDropdown() {
    String collection;
    if (_linkType == 'CATEGORY') {
      collection = 'mainCategory';
    } else if (_linkType == 'SUB_CATEGORY') {
      collection = 'subCategory';
    } else {
      collection = 'deliverySupermarkets';
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        return DropdownButtonFormField<String>(
          value: _targetId,
          hint: const Text("اختر الوجهة المحددة"),
          decoration: const InputDecoration(border: OutlineInputBorder(), fillColor: Color(0xFFF0F7FF), filled: true),
          items: snapshot.data!.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            String name = (_linkType == 'RETAILER') ? (data['supermarketName'] ?? 'بدون اسم') : (data['name'] ?? 'بدون اسم');
            return DropdownMenuItem(value: doc.id, child: Text(name));
          }).toList(),
          onChanged: (v) => setState(() => _targetId = v),
          validator: (v) => v == null ? "مطلوب" : null,
        );
      },
    );
  }

  // دالة جلب التجار لتحديد الجمهور المستهدف
  Widget _buildDealerSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('deliverySupermarkets').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        return DropdownButtonFormField<String>(
          value: _selectedOwnerId,
          hint: const Text("اختر التاجر المستهدف"),
          decoration: const InputDecoration(border: OutlineInputBorder(), fillColor: Color(0xFFFFF4F4), filled: true),
          items: snapshot.data!.docs.map((doc) {
            return DropdownMenuItem(
              value: doc.id,
              child: Text(doc.get('supermarketName') ?? 'بدون اسم'),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedOwnerId = v),
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
                subtitle: Text("النوع: ${data['linkType']} - للجمهور: ${data['targetAudience']}"),
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

