import 'dart:convert';
import 'package:flutter/foundation.dart'; // مهم لدعم kIsWeb
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show File; // استخدام مشروط للـ File

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  String _selectedSource = 'office';
  DateTime _selectedDate = DateTime.now();
  dynamic _imageFile; // تغيير النوع ليدعم الويب والموبايل
  bool _isUploading = false;

  final Map<String, String> _expenseSources = {
    'office': 'إيجار ومرافق المكتب',
    'salaries': 'مرتبات وحوافز',
    'marketing': 'تسويق وإعلانات',
    'maintenance': 'صيانة وتجهيزات',
    'other': 'مصاريف أخرى',
  };

  // --- دالة اختيار الصورة ---
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile; // نخزن الـ XFile مباشرة
      });
    }
  }

  // --- دالة الرفع إلى Cloudinary (تدعم الويب والموبايل) ---
  Future<String?> _uploadToCloudinary() async {
    if (_imageFile == null) return null;

    const String cloudName = 'dgmmx6jbu';
    const String uploadPreset = 'commerce';
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

    try {
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset;

      // قراءة الملف كـ Bytes لضمان العمل على الويب
      final bytes = await _imageFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: _imageFile.name,
      ));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = utf8.decode(responseData);
        final jsonResponse = jsonDecode(responseString);
        return jsonResponse['secure_url'];
      }
    } catch (e) {
      debugPrint("Cloudinary Upload Error: $e");
    }
    return null;
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("برجاء إرفاق صورة مستند المصروف 📸"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      String? imageUrl = await _uploadToCloudinary();
      if (imageUrl == null) throw Exception("فشل رفع الصورة");

      String periodLabel = DateFormat('yyyy-MM').format(_selectedDate);
      await FirebaseFirestore.instance.collection('platform_ledger').add({
        'period': periodLabel,
        'entryType': 'expense',
        'source': _selectedSource,
        'totalAmount': double.parse(_amountController.text),
        'details': _detailsController.text,
        'attachmentUrl': imageUrl,
        'createdAt': Timestamp.fromDate(_selectedDate),
        'recordedBy': 'Admin',
      });

      if (mounted) {
        // رسالة نجاح في منتصف الشاشة
        _showSuccessDialog();
        
        // تصفير البيانات للبقاء في نفس الصفحة وإضافة مصروف جديد
        _formKey.currentState!.reset();
        _amountController.clear();
        _detailsController.clear();
        setState(() {
          _imageFile = null;
          _selectedDate = DateTime.now();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("حدث خطأ: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 15),
            Text("تم الحفظ بنجاح ✅", style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            Text("يمكنك الآن إضافة مصروف آخر أو العودة", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("حسناً", style: TextStyle(fontFamily: 'Cairo'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("تسجيل مصروف جديد", style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: const Color(0xFFB21F2D),
        // زرار الرجوع الافتراضي سيعود خطوة للخلف للقائمة
      ),
      body: _isUploading
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 10), Text("جاري الرفع والحفظ...")] ))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // --- قسم الصورة ---
                    GestureDetector(
                      onTap: () => _showImageSourceOptions(),
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: _imageFile == null ? Colors.red : Colors.green, width: 2),
                        ),
                        child: _imageFile == null
                            ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, size: 50, color: Colors.grey), Text("إرفاق صورة المستند (إجباري)")])
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: kIsWeb 
                                  ? Image.network(_imageFile.path, fit: BoxFit.cover) 
                                  : Image.file(File(_imageFile.path), fit: BoxFit.cover),
                              ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // حقل المبلغ
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: "المبلغ (ج.م)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      validator: (value) => value!.isEmpty ? "يرجى إدخال المبلغ" : null,
                    ),
                    const SizedBox(height: 20),

                    // حقل البيان (إدخال يدوي)
                    TextFormField(
                      controller: _detailsController,
                      maxLines: 2,
                      decoration: InputDecoration(labelText: "بيان المصروف / التفاصيل", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      validator: (value) => value!.isEmpty ? "يرجى إدخال بيان للمصروف" : null,
                    ),
                    const SizedBox(height: 20),

                    DropdownButtonFormField<String>(
                      value: _selectedSource,
                      decoration: InputDecoration(labelText: "تصنيف المصروف", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      items: _expenseSources.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                      onChanged: (val) => setState(() => _selectedSource = val!),
                    ),
                    const SizedBox(height: 20),

                    ListTile(
                      title: Text("التاريخ: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}"),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2025), lastDate: DateTime(2030));
                        if (picked != null) setState(() => _selectedDate = picked);
                      },
                      tileColor: Colors.grey[100],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _saveExpense,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB21F2D)),
                        child: const Text("حفظ المصروف والمستند", style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Cairo')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text("الكاميرا"), onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
            ListTile(leading: const Icon(Icons.photo_library), title: const Text("المعرض"), onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
          ],
        ),
      ),
    );
  }
}

