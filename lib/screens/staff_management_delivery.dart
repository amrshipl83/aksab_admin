import 'package:flutter/material.dart';
// استيراد التبويبات من المجلد الفرعي tabs
import 'tabs/pending_free_drivers_tab.dart'; 
import 'tabs/pending_staff_tab.dart'; 

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
    // 5 تابات مقسمة حسب منطق قاعدة البيانات لدينا
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
        foregroundColor: Colors.white, // لضمان ظهور الأيقونات باللون الأبيض
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, // للسماح بالتنقل السلس بين الـ 5 أقسام
          indicatorColor: Colors.orange,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.motorcycle), text: "انتظار (حر)"),
            Tab(icon: Icon(Icons.person_add_alt_1), text: "انتظار (موظفين)"),
            Tab(icon: Icon(Icons.delivery_dining), text: "مناديب أحرار"),
            Tab(icon: Icon(Icons.badge), text: "مناديب الشركة"),
            Tab(icon: Icon(Icons.admin_panel_settings), text: "المشرفين والمديرين"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. التبويب الأول: طلبات المناديب الأحرار
          const PendingFreeDriversTab(),

          // 2. التبويب الثاني: طلبات الموظفين (مناديب شركة + مديرين)
          const PendingStaffTab(),

          // 3. التبويبات القادمة (سيتم استبدالها بملفات منفصلة تباعاً)
          _buildPlaceholder("المناديب الأحرار المعتمدين (freeDrivers)"),
          _buildPlaceholder("مناديب الشركة المعتمدين (deliveryReps)"),
          _buildPlaceholder("المشرفين والمديرين (managers)"),
        ],
      ),
    );
  }

  // ويدجت مؤقت للأقسام التي لم تبرمج بعد
  Widget _buildPlaceholder(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.construction, size: 50, color: Colors.grey),
          const SizedBox(height: 10),
          Text(
            title, 
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

