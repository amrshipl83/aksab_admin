import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; 
import 'screens/login_screen.dart'; 

void main() async {
  // التأكد من تهيئة أدوات فلاتر قبل تشغيل أي كود
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // تهيئة فايربيس للويب باستخدام الخيارات التي وضعناها في firebase_options.dart
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase Initialization Error: $e");
  }
  
  runApp(const AksabAdminApp());
}

class AksabAdminApp extends StatelessWidget {
  const AksabAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'إدارة أكسب',
      // لإزالة علامة التوضيح الحمراء (Debug banner) من الزاوية
      debugShowCheckedModeBanner: false,
      
      // تحديد اللغة الافتراضية للواجهة لتناسب المحتوى العربي
      locale: const Locale('ar', 'EG'),
      
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Arial', // يمكنك تغيير الخط لاحقاً ليناسب ذوقك
        useMaterial3: true,
      ),

      // المسار الابتدائي هو شاشة الدخول
      initialRoute: '/',
      
      routes: {
        '/': (context) => const LoginScreen(),
        
        // سنقوم بإنشاء هذه الشاشة في الخطوة التالية
        '/admin': (context) => const Scaffold(
          body: Center(child: Text("جاري تحميل لوحة التحكم...")),
        ),
      },
    );
  }
}

