import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController(); // كنترولر الباسورد
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String _message = '';

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _message = "⚠️ يرجى إدخال البريد الإلكتروني وكلمة المرور");
      return;
    }

    setState(() => _isLoading = true);
    try {
      // ✅ تسجيل الدخول المباشر
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        _proceedToDashboard(userCredential.user!.uid);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        setState(() => _message = "❌ هذا البريد غير مسجل");
      } else if (e.code == 'wrong-password') {
        setState(() => _message = "❌ كلمة المرور غير صحيحة");
      } else {
        setState(() => _message = "❌ خطأ في الدخول: ${e.message}");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _proceedToDashboard(String uid) async {
    var adminDoc = await FirebaseFirestore.instance.collection('admins').doc(uid).get();
    if (adminDoc.exists) {
      _navigate(adminDoc.get('role') ?? 'user');
    } else {
      setState(() => _message = "❌ ليس لديك صلاحيات دخول كمسؤول");
      await FirebaseAuth.instance.signOut();
    }
  }

  void _navigate(String role) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => DashboardScreen(userRole: role)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("دخول الإدارة", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "البريد الإلكتروني", prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: "كلمة المرور",
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F2937), minimumSize: const Size(double.infinity, 55)),
                      child: const Text("دخول", style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
              if (_message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(_message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
