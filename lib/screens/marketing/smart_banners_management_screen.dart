import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// الاسم المقترح: SmartBannersManagementScreen
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
    // التبويب الأول للمستهلك (Consumer) والثاني لتجار التجزئة (Retailer)
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
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: const Text(
          "إدارة البانرات الذكية",
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A2C3D),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF1ABC9C), // لون التمييز الأخضر الخاص بك
          indicatorWeight: 4,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
          tabs: const [
            Tab(text: "متجر المستهلك", icon: Icon(Icons.shopping_bag_outlined)),
            Tab(text: "متجر التجزئة", icon: Icon(Icons.storefront_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // سنقوم ببناء الـ Widgets المنفصلة هنا في الخطوة القادمة
          _buildBannerListAndForm(collectionName: "consumerBanners", type: "consumer"),
          _buildBannerListAndForm(collectionName: "retailerBanners", type: "retailer"),
        ],
      ),
    );
  }

  // دالة بناء المحتوى (سيتم استبدالها بـ Widgets ذكية)
  Widget _buildBannerListAndForm({required String collectionName, required String type}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildQuickActionHeader(type),
          const SizedBox(height: 20),
          // هنا سيتم وضع الـ Form لاحقاً
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Icon(Icons.cloud_upload_outlined, size: 50, color: Colors.grey[400]),
                const SizedBox(height: 10),
                Text("جاري تجهيز محرك الرفع لـ $collectionName..."),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionHeader(String type) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          type == "consumer" ? "بانرات المستهلك الحالية" : "بانرات التجزئة الحالية",
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold),
        ),
        ElevatedButton.icon(
          onPressed: () {}, // سيفتح الـ Form
          icon: const Icon(Icons.add),
          label: const Text("إضافة بانر جديد"),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1ABC9C), foregroundColor: Colors.white),
        )
      ],
    );
  }
}

