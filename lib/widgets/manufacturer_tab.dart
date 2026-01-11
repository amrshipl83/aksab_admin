import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ManufacturerTab extends StatefulWidget {
  const ManufacturerTab({super.key});

  @override
  State<ManufacturerTab> createState() => _ManufacturerTabState();
}

class _ManufacturerTabState extends State<ManufacturerTab> {
  final TextEditingController _nameController = TextEditingController();
  XFile? _selectedImage;
  bool _isLoading = false;
  
  // 🎯 متغيرات جديدة للاختيار من متعدد
  List<String> _selectedSubCategoryIds = [];

  final String cloudName = "dgmmx6jbu";
  final String uploadPreset = "commerce";

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _selectedImage = image);
  }

  Future<void> _saveManufacturer() async {
    if (_nameController.text.isEmpty || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("برجاء إدخال الاسم واختيار الصورة")));
      return;
    }
    setState(() => _isLoading = true);

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = 'manufacturers'
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: _selectedImage!.name));

      final response = await request.send();
      if (response.statusCode == 200) {
        final data = jsonDecode(await response.stream.bytesToString());

        // 🎯 التعديل: إضافة isActive و subCategoryIds
        await FirebaseFirestore.instance.collection('manufacturers').add({
          'name': _nameController.text.trim(),
          'imageUrl': data['secure_url'],
          'imagePublicId': data['public_id'],
          'isActive': true, // الحقل المطلوب
          'subCategoryIds': _selectedSubCategoryIds, // المصفوفة المطلوبة للفلترة
          'createdAt': FieldValue.serverTimestamp(),
        });

        _nameController.clear();
        setState(() {
          _selectedImage = null;
          _selectedSubCategoryIds = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إضافة الشركة بنجاح")));
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
        crossAxisAlignment: CrossAxisAlignment.end, // للمحاذاة لليمين
        children: [
          TextField(
            controller: _nameController, 
            textAlign: TextAlign.right, 
            decoration: const InputDecoration(labelText: "اسم الشركة / المصنع", border: OutlineInputBorder())
          ),
          const SizedBox(height: 15),
          
          // 🎯 ويدجت اختيار الأقسام الفرعية (Multi-select Chips)
          const Text("اختر الأقسام الفرعية المرتبطة:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('subCategory').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              
              return Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                direction: Axis.horizontal,
                children: snapshot.data!.docs.map((doc) {
                  final isSelected = _selectedSubCategoryIds.contains(doc.id);
                  return FilterChip(
                    label: Text(doc['name']),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _selectedSubCategoryIds.add(doc.id);
                        } else {
                          _selectedSubCategoryIds.remove(doc.id);
                        }
                      });
                    },
                    selectedColor: Colors.blue[100],
                    checkmarkColor: Colors.blue,
                  );
                }).toList(),
              );
            },
          ),
          
          const SizedBox(height: 15),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 120, width: double.infinity,
              decoration: BoxDecoration(border: Border.all(color: Colors.blue[200]!), borderRadius: BorderRadius.circular(10)),
              child: _selectedImage == null
                ? const Center(child: Text("رفع شعار الشركة (Logo)"))
                : Image.network(_selectedImage!.path, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveManufacturer,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: const Color(0xFF4361ee)),
            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("حفظ الشركة", style: TextStyle(color: Colors.white)),
          ),
          const Divider(height: 30),
          
          // قائمة الشركات الحالية
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('manufacturers').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  return ListTile(
                    leading: Image.network(doc['imageUrl'], width: 40),
                    title: Text(doc['name']),
                    subtitle: Text("أقسام: ${(doc.data() as Map).containsKey('subCategoryIds') ? (doc['subCategoryIds'] as List).length : 0}"),
                    trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => FirebaseFirestore.instance.collection('manufacturers').doc(doc.id).delete()),
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

