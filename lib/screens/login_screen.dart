import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // التحقق فوراً إذا كان التطبيق فُتح عن طريق رابط مرسل للإيميل
    _checkIncomingLink();
  }

  // دالة للتحقق من الرابط عند العودة للتطبيق
  Future<void> _checkIncomingLink() async {
    final auth = FirebaseAuth.instance;
    if (auth.isSignInWithEmailLink(Uri.base.toString())) {
      setState(() => _isLoading = true);
      try {
        // نحتاج الإيميل لإتمام العملية (مخزن مؤقتاً أو نطلبه من المستخدم)
        // سنحاول جلب الإيميل المحفوظ محلياً أو نطلب إعادة كتابته
        String email = _emailController.text.trim(); 
        
        final userCredential = await auth.signInWithEmailLink(
          email: email,
          emailLink: Uri.base.toString(),
        );

        if (userCredential.user != null) {
          _proceedToDashboard(userCredential.user!.uid);
        }
      } catch (e) {
        setState(() => _message = "❌ الرابط منتهي الصلاحية أو غير صحيح.");
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // إرسال الرابط للإيميل
  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _message = "⚠️ يرجى كتابة البريد الإلكتروني أولاً");
      return;
    }

    setState(() => _isLoading = true);
    try {
      var acs = ActionCodeSettings(
        url: 'https://aksab-admin.web.app/admin', // رابط الويب الخاص بك
        handleCodeInApp: true,
        androidPackageName: 'com.example.aksab_admin', // اسم الباكيج الخاص بك
        androidInstallApp: true,
        androidMinimumVersion: '12',
      );

      await FirebaseAuth.instance.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: acs,
      );

      setState(() => _message = "✅ تم إرسال رابط الدخول إلى $email. يرجى فحص بريد Zoho والضغط على الرابط.");
    } catch (e) {
      setState(() => _message = "❌ خطأ في إرسال الرابط: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _proceedToDashboard(String uid) async {
    final adminDoc = await FirebaseFirestore.instance.collection('admins').doc(uid).get();
    if (adminDoc.exists) {
      String role = adminDoc.get('role') ?? 'user';
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen(userRole: role)),
        );
      }
    } else {
      setState(() => _message = "❌ ليس لديك صلاحيات دخول.");
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
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("دخول الموظفين", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("سيتم إرسال كود دخول آمن لبريدك في Zoho", 
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "بريد Zoho الإلكتروني",
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 25),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _sendMagicLink,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F2937),
                        minimumSize: const Size(double.infinity, 55),
                      ),
                      child: const Text("إرسال رابط الدخول", style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
              if (_message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(_message, textAlign: TextAlign.center, 
                      style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w500)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

