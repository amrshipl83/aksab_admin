import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _tempPasswordController = TextEditingController(); // باسورد مؤقتة
  
  String _selectedRole = 'finance'; // القيمة الافتراضية
  bool _isLoading = false;

  Future<void> _addTeamMember() async {
    if (_emailController.text.isEmpty || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("برجاء ملء البيانات الأساسية")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. إنشاء الحساب في Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _tempPasswordController.text.trim(),
      );

      // 2. إرسال رابط المصادقة إلى إيميل Zoho
      await userCredential.user!.sendEmailVerification();

      // 3. تخزين البيانات الإضافية في Firestore
      await FirebaseFirestore.instance.collection('admins').doc(userCredential.user!.uid).set({
        'real_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'is_verified': false, // ستتغير عند ضغط الرابط في الإيميل
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("تم إضافة ${_nameController.text} وإرسال رابط المصادقة لـ ${_emailController.text}"))
        );
        _clearFields();
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: ${e.message}")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearFields() {
    _nameController.clear();
    _phoneController.clear();
    _emailController.clear();
    _tempPasswordController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إدارة طاقم العمل - إضافة مدير")),
      body: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 5,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("إضافة مستخدم جديد للمنصة", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(controller: _nameController, decoration: const InputDecoration(labelText: "الاسم الحقيقي للموظف")),
                  TextField(controller: _phoneController, decoration: const InputDecoration(labelText: "رقم التليفون")),
                  TextField(controller: _emailController, decoration: const InputDecoration(labelText: "إيميل زوهو الرسمي (مثال: finance@aksab.shop)")),
                  TextField(controller: _tempPasswordController, decoration: const InputDecoration(labelText: "كلمة مرور مؤقتة")),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    items: const [
                      DropdownMenuItem(value: 'finance', child: Text("الإدارة المالية")),
                      DropdownMenuItem(value: 'logistics', child: Text("المخازن والعمليات")),
                      DropdownMenuItem(value: 'marketing', child: Text("التسويق والمبيعات")),
                    ],
                    onChanged: (val) => setState(() => _selectedRole = val!),
                    decoration: const InputDecoration(labelText: "تحديد الصلاحية (Role)"),
                  ),
                  const SizedBox(height: 30),
                  _isLoading 
                    ? const CircularProgressIndicator() 
                    : ElevatedButton(
                        onPressed: _addTeamMember,
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                        child: const Text("إنشاء الحساب وإرسال رابط المصادقة"),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

