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
      initialRoute: '/',
      // ✅ الحل الجذري: نستخدم onGenerateRoute لاستقبال الـ Role وتمريره
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(builder: (context) => const LoginScreen());
        }
        
        if (settings.name == '/admin') {
          // هنا بنستلم الـ Role اللي باعتينه من صفحة الـ Login
          final role = settings.arguments as String? ?? 'guest'; // لو مبعتش حاجة خليه ضيف (أمان)
          
          return MaterialPageRoute(
            builder: (context) => DashboardScreen(userRole: role),
          );
        }
        return null;
      },
    );
  }
}

