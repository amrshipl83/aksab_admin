import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_screen.dart'; // تأكد من استيراد الداشبورد

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _message = '';

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      // 1. تسجيل الدخول الأساسي
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;

      if (user != null) {
        // تحديث حالة المستخدم للتأكد من آخر وضع للـ Verification
        await user.reload();
        user = FirebaseAuth.instance.currentUser;

        // 2. التحقق من مصادقة إيميل زوهو
        if (!user!.emailVerified) {
          // لو مش متفعل، نبعت رابط التحقق فوراً
          await user.sendEmailVerification();
          setState(() {
            _message = "⚠️ حسابك غير موثق. تم إرسال رابط تأكيد جديد إلى بريدك في Zoho. يرجى الضغط عليه ثم حاول الدخول مجدداً.";
          });
          await FirebaseAuth.instance.signOut(); // نخرجه لحد ما يفعل
          return;
        }

        // 3. لو مفعل، نجيب الـ Role من Firestore
        DocumentSnapshot adminDoc = await FirebaseFirestore.instance
            .collection('admins')
            .doc(user.uid)
            .get();

        if (adminDoc.exists) {
          String role = adminDoc.get('role') ?? 'user';
          
          if (mounted) {
            // الدخول للوحة وتمرير الصلاحية
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => DashboardScreen(userRole: role)),
            );
          }
        } else {
          setState(() => _message = "❌ خطأ: لم يتم العثور على صلاحيات لهذا الحساب.");
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorText = "حدث خطأ في الدخول";
      if (e.code == 'user-not-found') errorText = "المستخدم غير موجود";
      else if (e.code == 'wrong-password') errorText = "كلمة المرور غير صحيحة";
      setState(() => _message = "❌ $errorText");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("لوحة تحكم أكسب", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "البريد الإلكتروني (Zoho)", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "كلمة المرور", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 25),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F2937),
                        minimumSize: const Size(double.infinity, 55),
                      ),
                      child: const Text("دخول للمنصة", style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
              if (_message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(_message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

