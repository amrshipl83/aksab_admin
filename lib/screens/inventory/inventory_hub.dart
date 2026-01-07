import 'package:flutter/material.dart';
import 'tabs/purchase_invoice_screen.dart'; // استيراد الصفحة الجديدة

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
    // طول القائمة 3 كما هو
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
        title: const Text('إدارة المشتريات والمخازن', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: const Color(0xFF1F2937),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFF57C00),
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
          // ✅ تم الربط هنا: استبدال الـ Placeholder بالصفحة الحقيقية
          const PurchaseInvoiceScreen(), 
          
          _buildPlaceholder("صفحة جرد المخزن الرئيسي"),
          _buildPlaceholder("صفحة جرد رفوف المتجر"),
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

