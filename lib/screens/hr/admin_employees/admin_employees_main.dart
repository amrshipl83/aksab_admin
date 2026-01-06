import 'package:flutter/material.dart';
import 'tabs/admin_list_tab.dart';
import 'tabs/add_admin_tab.dart';
import 'tabs/admin_branches_tab.dart';

class AdminEmployeesMain extends StatefulWidget {
  const AdminEmployeesMain({super.key});

  @override
  State<AdminEmployeesMain> createState() => _AdminEmployeesMainState();
}

class _AdminEmployeesMainState extends State<AdminEmployeesMain> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // تم رفع العدد إلى 3 تابات لتشمل إدارة الفروع (Geofencing)
    _tabController = TabController(length: 3, vsync: this);
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
          "شؤون الموظفين الإداريين",
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)
        ),
        backgroundColor: const Color(0xFF1A2C3D),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.people), text: "القائمة"),
            Tab(icon: Icon(Icons.person_add), text: "إضافة موظف"),
            Tab(icon: Icon(Icons.location_on), text: "نطاق الحضور"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // 1. عرض وتعديل البيانات المالية الخام
          AdminListTab(),

          // 2. نموذج إضافة موظف جديد ببياناته الأولية
          AddAdminTab(),

          // 3. إدارة الفروع المسموح للموظف تسجيل الحضور منها (Geofencing)
          AdminBranchesTab(),
        ],
      ),
    );
  }
}

