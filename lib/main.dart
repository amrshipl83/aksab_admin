import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart'; // ✅ إضافة مكتبة برو فايدر
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'controllers/revenue_controller.dart'; // ✅ إضافة ملف التحكم في الإيرادات

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase Initialization Error: $e");
  }
  
  // ✅ تغليف التطبيق بالـ MultiProvider ليكون جاهزاً لإدارة الحالة المالية
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RevenueController()),
        // يمكنك إضافة أي controllers أخرى هنا مستقبلاً
      ],
      child: const AksabAdminApp(),
    ),
  );
}

class AksabAdminApp extends StatelessWidget {
  const AksabAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'إدارة أكسب',
      debugShowCheckedModeBanner: false,
      // دعم اللغة العربية بشكل رسمي
      locale: const Locale('ar', 'EG'),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Tajawal', // تأكد من وجود الخط في pubspec.yaml
        useMaterial3: true,
        // تحسين ألوان الثيم لتناسب الهوية المالية
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB21F2D)),
      ),
      
      // الشاشة الافتراضية عند الفتح
      home: const LoginScreen(),

      // نظام المسارات (Routes)
      onGenerateRoute: (settings) {
        if (settings.name == '/admin') {
          final String role = (settings.arguments as String?) ?? 'guest';
          return MaterialPageRoute(
            builder: (context) => DashboardScreen(userRole: role),
          );
        }
        // العودة للوجن في حال حدوث خطأ في المسار
        return MaterialPageRoute(builder: (context) => const LoginScreen());
      },
    );
  }
}

