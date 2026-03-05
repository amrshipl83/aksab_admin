import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    _checkIncomingLink();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _checkIncomingLink() async {
    final auth = FirebaseAuth.instance;
    String link = Uri.base.toString();

    if (auth.isSignInWithEmailLink(link)) {
      setState(() => _isLoading = true);
      try {
        final prefs = await SharedPreferences.getInstance();
        String? email = prefs.getString('user_email') ?? _emailController.text.trim();

        if (email.isEmpty) {
          setState(() => _message = "⚠️ يرجى كتابة بريدك الإلكتروني مرة أخرى للتأكيد");
          setState(() => _isLoading = false);
          return;
        }

        final userCredential = await auth.signInWithEmailLink(
          email: email,
          emailLink: link,
        );

        if (userCredential.user != null) {
          await prefs.remove('user_email');
          _proceedToDashboard(userCredential.user!.uid);
        }
      } catch (e) {
        setState(() => _message = "❌ الرابط منتهي الصلاحية أو غير صحيح.");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _message = "⚠️ يرجى كتابة البريد الإلكتروني أولاً");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email);

      var acs = ActionCodeSettings(
        // الرابط الذي سيعود إليه المستخدم (GitHub Pages)
        url: 'https://amrshipl83.github.io/aksab_admin/',
        handleCodeInApp: true,
        // اسم الباكيج الخاص بتطبيق الأندرويد لفتحه تلقائياً إن وجد
        androidPackageName: 'com.aksabeg', 
        androidInstallApp: true,
        androidMinimumVersion: '12',
        // ✅ المفتاح السحري: استخدام دومين الهوستنج كبوابة بديلة للـ Dynamic Links
      
      );

      await FirebaseAuth.instance.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: acs,
      );

      setState(() => _message = "✅ تم إرسال رابط الدخول إلى $email.\nافحص بريدك الآن واضغط على الرابط.");
    } catch (e) {
      setState(() => _message = "❌ خطأ: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _proceedToDashboard(String uid) async {
    // محاولة جلب بيانات الأدمن بالـ UID
    var adminDoc = await FirebaseFirestore.instance.collection('admins').doc(uid).get();

    if (adminDoc.exists) {
      _navigate(adminDoc.get('role') ?? 'user');
    } else {
      // لو أول مرة يدخل، نبحث عنه بالإيميل لتحديث بياناته
      final email = FirebaseAuth.instance.currentUser?.email;
      final query = await FirebaseFirestore.instance
          .collection('admins')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        String role = query.docs.first.get('role') ?? 'user';
        await _updateAdminRecord(query.docs.first.id, uid);
        _navigate(role);
      } else {
        setState(() => _message = "❌ ليس لديك صلاحيات دخول كمسؤول.");
        await FirebaseAuth.instance.signOut();
      }
    }
  }

  Future<void> _updateAdminRecord(String oldDocId, String uid) async {
    final data = (await FirebaseFirestore.instance.collection('admins').doc(oldDocId).get()).data();
    if (data != null) {
      await FirebaseFirestore.instance.collection('admins').doc(uid).set({
        ...data,
        'status': 'active',
        'last_login': FieldValue.serverTimestamp(),
      });
      // اختياري: حذف المستند القديم المعرف بالإيميل فقط
      if (oldDocId != uid) {
        await FirebaseFirestore.instance.collection('admins').doc(oldDocId).delete();
      }
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
              const SizedBox(height: 10),
              const Text("سيصلك رابط تسجيل دخول آمن على بريدك",
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontFamily: 'Tajawal')),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "البريد الإلكتروني",
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("إرسال رابط الدخول", style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Tajawal')),
                    ),
              if (_message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(_message, textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

