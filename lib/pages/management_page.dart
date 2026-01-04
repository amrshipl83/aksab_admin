import 'package:flutter/material.dart';
import '../widgets/main_category_tab.dart';
import '../widgets/sub_category_tab.dart';
import '../widgets/product_tab.dart';
import '../widgets/manufacturer_tab.dart';

class ManagementPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('إدارة المتجر', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          backgroundColor: Color(0xFF4361ee),
          centerTitle: true,
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            tabs: [
              Tab(icon: Icon(Icons.layers), text: 'رئيسي'),
              Tab(icon: Icon(Icons.folder_shared), text: 'فرعي'),
              Tab(icon: Icon(Icons.shopping_bag), text: 'منتجات'),
              Tab(icon: Icon(Icons.business), text: 'شركات'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            MainCategoryTab(),    // ينادي الملف في widgets/main_category_tab.dart
            SubCategoryTab(),     // ينادي الملف في widgets/sub_category_tab.dart
            ProductTab(),         // ينادي الملف في widgets/product_tab.dart
            ManufacturerTab(),    // ينادي الملف في widgets/manufacturer_tab.dart
          ],
        ),
      ),
    );
  }
}

