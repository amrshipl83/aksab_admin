import 'package:flutter/material.dart';
import 'tabs/pending_view.dart';
import 'tabs/managers_view.dart';
import 'tabs/supervisors_view.dart';
import 'tabs/reps_view.dart';

class SalesManagementScreen extends StatefulWidget {
  const SalesManagementScreen({super.key});

  @override
  State<SalesManagementScreen> createState() => _SalesManagementScreenState();
}

class _SalesManagementScreenState extends State<SalesManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        title: const Text("إدارة المبيعات", 
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A2C3D),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFFF57C00),
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.person_search), text: "انتظار الموافقة"),
            Tab(icon: Icon(Icons.badge), text: "المديرون"),
            Tab(icon: Icon(Icons.groups), text: "المشرفون"),
            Tab(icon: Icon(Icons.handshake), text: "المناديب"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          PendingView(),
          ManagersView(),
          SupervisorsView(),
          RepsView(),
        ],
      ),
    );
  }
}

