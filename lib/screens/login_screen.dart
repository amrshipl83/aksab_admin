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
  final _passwordController = TextEditingController();
  bool _isLoading = true; // خليناها true في البداية عشان بنشيك على الجلسة
  bool _isPasswordVisible = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    // 🚀 أول ما الصفحة تفتح، بنشيك هل فيه "جيميني" قصدي مستخدم مسجل؟
    _checkExistingSession();
  }

  // دالة فحص الجلسة المؤقتة
  Future<void> _checkExistingSession() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // لو فيه مستخدم، بنروح نجيب صلاحياته ونحوله فوراً
      await _proceedToDashboard(user.uid);
    } else {
      // لو مفيش، بنظهر صفحة اللوجن عادي
      setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _message = "⚠️ يرجى إدخال البريد الإلكتروني وكلمة المرور");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await _proceedToDashboard(userCredential.user!.uid);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          _message = "❌ هذا البريد غير مسجل";
        } else if (e.code == 'wrong-password') {
          _message = "❌ كلمة المرور غير صحيحة";
        } else {
          _message = "❌ خطأ في الدخول: ${e.message}";
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _proceedToDashboard(String uid) async {
    try {
      var adminDoc = await FirebaseFirestore.instance.collection('admins').doc(uid).get();
      if (adminDoc.exists) {
        String role = adminDoc.get('role') ?? 'user';
        _navigate(role);
      } else {
        setState(() {
          _message = "❌ ليس لديك صلاحيات دخول كمسؤول";
          _isLoading = false;
        });
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      setState(() {
        _message = "❌ خطأ في الاتصال بالسيرفر";
        _isLoading = false;
      });
    }
  }

  void _navigate(String role) {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardScreen(userRole: role)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // لو بنحمل (بنشيك على الجلسة)، بنظهر لودنج بس
    if (_isLoading && _emailController.text.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF1F2937))),
      );
    }

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
