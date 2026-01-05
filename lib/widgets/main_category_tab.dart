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
  bool _isLoading = false;

  final String cloudName = "dgmmx6jbu";
  final String uploadPreset = "commerce";

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImage = pickedFile);
    }
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
    if (_nameController.text.isEmpty || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إدخال الاسم والصورة")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uploadResult = await _uploadToCloudinary(_selectedImage!);
      if (uploadResult != null) {
        await FirebaseFirestore.instance.collection('mainCategory').add({
          'name': _nameController.text.trim(),
          'order': int.tryParse(_orderController.text) ?? 0,
          'imageUrl': uploadResult['url'],
          'imagePublicId': uploadResult['public_id'],
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });
        _nameController.clear();
        _orderController.clear();
        setState(() => _selectedImage = null);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إضافة القسم الرئيسي")));
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
          TextField(controller: _nameController, textAlign: TextAlign.right, decoration: const InputDecoration(labelText: "اسم القسم الرئيسي", border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: _orderController, keyboardType: TextInputType.number, textAlign: TextAlign.right, decoration: const InputDecoration(labelText: "الترتيب", border: OutlineInputBorder())),
          const SizedBox(height: 15),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 150, width: double.infinity,
              decoration: BoxDecoration(border: Border.all(color: Colors.blue[200]!), borderRadius: BorderRadius.circular(10)),
              child: _selectedImage == null 
                ? const Center(child: Text("اضغط لرفع صورة القسم الرئيسي"))
                : ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(_selectedImage!.path, fit: BoxFit.cover)),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveMainCategory,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: const Color(0xFF4361ee)),
            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("حفظ القسم الرئيسي", style: TextStyle(color: Colors.white)),
          ),
          const Divider(height: 40),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('mainCategory').orderBy('order').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              return ListView.builder(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  return ListTile(
                    leading: Image.network(doc['imageUrl'], width: 50),
                    title: Text(doc['name']),
                    trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), 
                      onPressed: () => FirebaseFirestore.instance.collection('mainCategory').doc(doc.id).delete()),
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

