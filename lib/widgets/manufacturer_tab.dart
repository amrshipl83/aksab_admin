// المسار: lib/widgets/manufacturer_tab.dart
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
  
  // قائمة لتخزين معرفات الأقسام المختارة
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("برجاء إدخال الاسم واختيار الصورة"))
      );
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

        // 🎯 التأكد من أسماء الحقول لتطابق الموديل في الفرونت
        await FirebaseFirestore.instance.collection('manufacturers').add({
          'name': _nameController.text.trim(),
          'imageUrl': data['secure_url'], // الحقل المسؤول عن عرض الصورة
          'imagePublicId': data['public_id'],
          'isActive': true, 
          'subCategoryIds': _selectedSubCategoryIds, 
          'createdAt': FieldValue.serverTimestamp(),
        });

        _nameController.clear();
        setState(() {
          _selectedImage = null;
          _selectedSubCategoryIds = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إضافة الشركة بنجاح")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end, 
        children: [
          TextField(
            controller: _nameController, 
            textAlign: TextAlign.right, 
            decoration: const InputDecoration(
              labelText: "اسم الشركة / المصنع", 
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business)
            )
          ),
          const SizedBox(height: 20),
          
          const Text("اختر الأقسام الفرعية المرتبطة:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          
          // ويدجت اختيار الأقسام (FilterChips)
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
          
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 150, width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(color: Colors.blue[200]!, width: 2), 
                borderRadius: BorderRadius.circular(12)
              ),
              child: _selectedImage == null
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload, size: 40, color: Colors.blue),
                      Text("رفع شعار الشركة (Logo)"),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(_selectedImage!.path, fit: BoxFit.contain)
                  ),
            ),
          ),
          const SizedBox(height: 25),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveManufacturer,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 55), 
              backgroundColor: const Color(0xFF4361ee),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            child: _isLoading 
              ? const CircularProgressIndicator(color: Colors.white) 
              : const Text("حفظ الشركة والبيانات", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 40, thickness: 2),
          
          const Text("الشركات المسجلة حالياً:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),

          // قائمة الشركات الحالية (المصححة لتجنب الشاشة الرمادية)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('manufacturers').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Text("خطأ في تحميل البيانات");
              if (!snapshot.hasData) return const SizedBox();
              
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                  
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!)
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          data['imageUrl'] ?? '', 
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported),
                        ),
                      ),
                    ),
                    title: Text(data['name'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("مرتبطة بـ ${(data['subCategoryIds'] as List?)?.length ?? 0} أقسام"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => FirebaseFirestore.instance.collection('manufacturers').doc(doc.id).delete()
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

