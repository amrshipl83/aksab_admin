import 'package:flutter/material.dart';

// استيراد كافة التبويبات التي قمنا ببنائها
import 'tabs/pending_free_drivers_tab.dart';    // 1. انتظار (حر)
import 'tabs/pending_staff_tab.dart';           // 2. انتظار (موظفين)
import 'tabs/active_free_drivers_tab.dart';     // 3. المناديب الأحرار
import 'tabs/company_reps_tab.dart';            // 4. مناديب الشركة
import 'tabs/managers_tab.dart';                // 5. المشرفين والمديرين

class StaffManagementMain extends StatefulWidget {
  const StaffManagementMain({super.key});

  @override
  State<StaffManagementMain> createState() => _StaffManagementMainState();
}

class _StaffManagementMainState extends State<StaffManagementMain> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // تم تهيئة 5 تابات تغطي كامل الهيكل الهرمي للنظام
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "إدارة طاقم العمل والشركاء",
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)
        ),
        backgroundColor: const Color(0xFF1A2C3D),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, // ضروري لأن عدد التابات 5 وعناوينها طويلة نسبياً
          indicatorColor: Colors.orange,
          indicatorWeight: 3,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontFamily: 'Cairo', 
            fontSize: 12, 
            fontWeight: FontWeight.bold
          ),
          tabs: const [
            Tab(icon: Icon(Icons.motorcycle), text: "انتظار (حر)"),
            Tab(icon: Icon(Icons.person_add_alt_1), text: "انتظار (موظفين)"),
            Tab(icon: Icon(Icons.delivery_dining), text: "مناديب أحرار"),
            Tab(icon: Icon(Icons.badge), text: "مناديب الشركة"),
            Tab(icon: Icon(Icons.admin_panel_settings), text: "المشرفين والمديرين"),
          ],
        ),
      ),
      body: Container(
        color: const Color(0xFFF5F7F9), // لون خلفية خفيف للراحة البصرية
        child: TabBarView(
          controller: _tabController,
          children: const [
            // 1. طلبات المناديب الأحرار (تفعيل مباشر)
            PendingFreeDriversTab(),

            // 2. طلبات الموظفين (فلترة: تحصيل فقط + نافذة بيانات مالية)
            PendingStaffTab(),

            // 3. المناديب الأحرار المعتمدين (تحكم في الائتمان وحالة الاتصال)
            ActiveFreeDriversTab(),

            // 4. مناديب الشركة (تعديل الراتب + اختيار المشرف من قائمة منسدلة)
            CompanyRepsTab(),

            // 5. الإدارة (تعديل بيانات المشرفين والمديرين + ربط التسلسل الهرمي)
            ManagersTab(),
          ],
        ),
      ),
    );
  }
}

