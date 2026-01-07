import 'package:flutter/material.dart';

class InventoryHub extends StatefulWidget {
  const InventoryHub({super.key});

  @override
  State<InventoryHub> createState() => _InventoryHubState();
}

class _InventoryHubState extends State<InventoryHub> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // لدينا 3 أقسام بناءً على كود الـ HTML الخاص بك
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      app_bar: AppBar(
        title: const Text('إدارة المشتريات والمخازن', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: const Color(0xFF1A2C3D), // نفس لون الـ Sidebar في الـ HTML
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFF57C00), // البرتقالي المميز في الـ CSS
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.shopping_bag), text: "المشتريات"),
            Tab(icon: Icon(Icons.inventory), text: "رصيد المخزن"),
            Tab(icon: Icon(Icons.storefront), text: "رصيد المتجر"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // هنا نضع الصفحات الفعلية لكل قسم
          _buildPlaceholder("صفحة تسجيل المشتريات والتكاليف (cost.html)"),
          _buildPlaceholder("صفحة جرد المخزن الرئيسي (inventory_balance.html)"),
          _buildPlaceholder("صفحة جرد رفوف المتجر (store_inventory.html)"),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.construction, size: 50, color: Colors.grey),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 16)),
        ],
      ),
    );
  }
}

