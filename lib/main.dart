import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart'; // تأكد من إضافة هذا السطر

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
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
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'EG'),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Tajawal', // غيرناه لـ Tajawal ليناسب تصميمك الأصلي
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/admin': (context) => const DashboardScreen(), // ربط الشاشة الحقيقية هنا
      },
    );
  }
}

