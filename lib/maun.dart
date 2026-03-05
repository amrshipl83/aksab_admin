import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

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
        fontFamily: 'Tajawal',
        useMaterial3: true,
      ),
      // ✅ التعديل هنا: نلغي initialRoute ونستخدم home عشان نضمن ظهور صفحة اللوجن فوراً
      home: const LoginScreen(),
      
      // ✅ تحسين الـ onGenerateRoute ليكون أكثر مرونة مع الروابط
      onGenerateRoute: (settings) {
        if (settings.name == '/admin') {
          // استلام الـ Role بشكل آمن
          final String role = (settings.arguments as String?) ?? 'guest';
          return MaterialPageRoute(
            builder: (context) => DashboardScreen(userRole: role),
          );
        }
        // في حالة المسارات غير المعروفة، ارجع للرئيسية
        return MaterialPageRoute(builder: (context) => const LoginScreen());
      },
    );
  }
}

