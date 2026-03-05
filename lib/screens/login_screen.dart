import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; // نحتاج هذه المكتبة لحفظ الإيميل مؤقتاً
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    super.dispose();
  }

  // دالة للتحقق من الرابط عند العودة للتطبيق
  Future<void> _checkIncomingLink() async {
    final auth = FirebaseAuth.instance;
    // التحقق من الرابط الحالي في المتصفح
    String link = Uri.base.toString();

    if (auth.isSignInWithEmailLink(link)) {
      setState(() => _isLoading = true);
      try {
        // جلب الإيميل الذي حفظناه قبل إرسال الرابط
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
          // مسح الإيميل من الذاكرة بعد النجاح
          await prefs.remove('user_email');
          _proceedToDashboard(userCredential.user!.uid);
        }
      } catch (e) {
        debugPrint("Error signing in with link: $e");
        setState(() => _message = "❌ الرابط منتهي الصلاحية أو غير صحيح.");
      } finally {
        if (mounted) setState(() => _isLoading = false);
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
      // حفظ الإيميل محلياً لاستخدامه عند العودة من الرابط
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email);

      var acs = ActionCodeSettings(
        // ✅ تم تعديل الرابط ليطابق الدومين الخاص بك على GitHub
        url: 'https://amrshipl83.github.io/aksab_admin/', 
        handleCodeInApp: true,
        androidPackageName: 'com.example.aksab_admin',
        androidInstallApp: true,
        androidMinimumVersion: '12',
      );

      await FirebaseAuth.instance.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: acs,
      );

      setState(() => _message = "✅ تم إرسال رابط الدخول إلى $email.\nافتح بريد Zoho (أو الجيميل) واضغط على الرابط.");
    } catch (e) {
      setState(() => _message = "❌ خطأ: ${e.toString()}");
      debugPrint("Firebase Send Link Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _proceedToDashboard(String uid) async {
    final adminDoc = await FirebaseFirestore.instance.collection('admins').doc(uid).get();
    
    // ملاحظة: لو الموظف جديد (Pending)، المستند قد لا يكون موجوداً بـ الـ UID 
    // بل بالإيميل، لذا سنبحث بالاثنين
    if (adminDoc.exists) {
      _navigate(adminDoc.get('role') ?? 'user');
    } else {
      // بحث إضافي بالإيميل لو كان أول دخول له
      final email = FirebaseAuth.instance.currentUser?.email;
      final query = await FirebaseFirestore.instance
          .collection('admins')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        String role = query.docs.first.get('role') ?? 'user';
        // تحديث الـ Document ليأخذ الـ UID الجديد بدلاً من الإيميل فقط
        await _updateAdminRecord(query.docs.first.id, uid);
        _navigate(role);
      } else {
        setState(() => _message = "❌ ليس لديك صلاحيات دخول بالسيستم.");
        await FirebaseAuth.instance.signOut();
      }
    }
  }

  Future<void> _updateAdminRecord(String oldDocId, String uid) async {
    // تحديث بسيط لربط الحساب بالـ UID الفعلي لفايربيز
    await FirebaseFirestore.instance.collection('admins').doc(uid).set({
      ... (await FirebaseFirestore.instance.collection('admins').doc(oldDocId).get()).data()!,
      'status': 'active',
      'last_login': FieldValue.serverTimestamp(),
    });
    // حذف المستند القديم (المسجل بالإيميل) لو لزم الأمر أو تركه
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
              const Text("دخول الموظفين", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
              const SizedBox(height: 10),
              const Text("ادخل بريدك وسيصلك رابط دخول مباشر", 
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontFamily: 'Tajawal')),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "البريد الإلكتروني الرسمي",
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

