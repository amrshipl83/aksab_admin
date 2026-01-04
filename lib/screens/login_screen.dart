import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _errorMsg = '';
  String _uid = '';
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMsg = '';
      _uid = '';
    });

    try {
      // 1. تسجيل الدخول عبر Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String uid = userCredential.user!.uid;
      setState(() => _uid = 'UID: $uid');

      // 2. التحقق من الصلاحيات في مجموعة admins
      DocumentSnapshot adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(uid)
          .get();

      if (!adminDoc.exists) {
        setState(() => _errorMsg = 'ليست لديك صلاحية الدخول.');
        return;
      }

      var data = adminDoc.data() as Map<String, dynamic>;
      if (data['role'] == 'superadmin') {
        // الانتقال للوحة التحكم (سنقوم بإنشائها)
        if (mounted) {
           Navigator.pushReplacementNamed(context, '/admin');
        }
      } else {
        setState(() => _errorMsg = 'تم تسجيل الدخول ولكن ليست لديك الصلاحيات الكافية.');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMsg = 'خطأ: ${e.message}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: Container(
          width: 350,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("إدارة أسواق أكسب", 
                style: TextStyle(color: Color(0xFF007BFF), fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: "البريد الإلكتروني",
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: "كلمة المرور",
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                ),
              ),
              const SizedBox(height: 20),
              _isLoading 
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007BFF),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("دخول", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
              if (_errorMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Text(_errorMsg, style: const TextStyle(color: Colors.red, fontSize: 14)),
                ),
              if (_uid.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Text(_uid, style: const TextStyle(color: Colors.green, fontSize: 14)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

