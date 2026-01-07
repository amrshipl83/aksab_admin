import 'package:flutter/material.dart';
// استيراد التبويبين (سننشئ هذه الملفات الآن)
import 'tabs/consumer_banners_tab.dart';
import 'tabs/retailer_banners_tab.dart';

class SmartBannersManagementScreen extends StatefulWidget {
  const SmartBannersManagementScreen({super.key});

  @override
  State<SmartBannersManagementScreen> createState() => _SmartBannersManagementScreenState();
}

class _SmartBannersManagementScreenState extends State<SmartBannersManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text(
          "إدارة البانرات الذكية",
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A2C3D),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF1ABC9C),
          indicatorWeight: 4,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "بانرات المستهلك", icon: Icon(Icons.person)),
            Tab(text: "بانرات التجزئة", icon: Icon(Icons.storefront)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ConsumerBannersTab(), // الجزء الثاني
          RetailerBannersTab(), // الجزء الثالث
        ],
      ),
    );
  }
}

