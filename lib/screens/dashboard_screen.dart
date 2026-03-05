import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // البديل الحديث لـ dart:html

// الربط بالصفحات
import '../pages/management_page.dart';
import '../pages/orders_report_page.dart';
import '../pages/buyers_page.dart'; // تجار التجزئة
import '../pages/sellers_page.dart'; // الموردين

// استيراد الشاشات
import '../screens/delivery_management_screen.dart';
import '../screens/hr_management_screen.dart';
import '../screens/marketing/marketing_management_screen.dart';
import '../screens/inventory/inventory_hub.dart';
import '../screens/financial_dashboard_screen.dart';
import '../screens/team_management_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userRole;

  const DashboardScreen({super.key, required this.userRole});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // متغيرات البيانات
  double _salesTotal = 0;
  int _ordersCount = 0;
  int _sellersCount = 0; // الموردين
  int _buyersCount = 0;  // تجار التجزئة
  int _consumersCount = 0; // المستهلكين الجدد

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final ordersSnapshot = await FirebaseFirestore.instance.collection("orders").get();
      final sellersSnapshot = await FirebaseFirestore.instance.collection("sellers").get();
      final buyersSnapshot = await FirebaseFirestore.instance.collection("buyers").get(); // تجار التجزئة
      final consumersSnapshot = await FirebaseFirestore.instance.collection("users").get(); // المستهلكين

      double totalSales = 0;
      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('total')) {
          totalSales += (data['total'] as num).toDouble();
        }
      }

      if (mounted) {
        setState(() {
          _salesTotal = totalSales;
          _ordersCount = ordersSnapshot.size;
          _sellersCount = sellersSnapshot.size;
          _buyersCount = buyersSnapshot.size;
          _consumersCount = consumersSnapshot.size;
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // قاعدة التوافق: تحديد نوع الشاشة
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 800;
        return Scaffold(
          backgroundColor: const Color(0xFFF2F4F8),
          appBar: isMobile
              ? AppBar(
                  title: const Text("أكسب - الإدارة", style: TextStyle(fontFamily: 'Tajawal')),
                  backgroundColor: const Color(0xFF1F2937),
                  foregroundColor: Colors.white,
                )
              : null,
          drawer: isMobile ? Drawer(child: _buildSidebarContent(context)) : null,
          body: Row(
            children: [
              if (!isMobile)
                Container(
                  width: 110,
                  color: const Color(0xFF1F2937),
                  child: _buildSidebarContent(context),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 15 : 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 25),
                      _buildSummaryGrid(isMobile, constraints.maxWidth),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "مرحباً بك، نظام أكسب الذكي",
          style: TextStyle(fontSize: 16, color: Colors.grey[600], fontFamily: 'Tajawal'),
        ),
        Text(
          "لوحة التحكم (${widget.userRole})",
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1F2937), fontFamily: 'Tajawal'),
        ),
      ],
    );
  }

  Widget _buildSummaryGrid(bool isMobile, double width) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? 1 : (width > 1200 ? 4 : 2),
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      childAspectRatio: isMobile ? 2.8 : 1.6,
      children: [
        _buildStatusCard("${_salesTotal.toStringAsFixed(0)} ج.م", "المبيعات", Icons.account_balance_wallet, Colors.blue),
        _buildStatusCard("$_ordersCount", "الطلبات الحالية", Icons.shopping_cart, Colors.orange),
        _buildStatusCard("$_sellersCount", "الموردين", Icons.store, Colors.purple),
        _buildStatusCard("$_consumersCount", "المستهلكين", Icons.person_pin, Colors.teal),
      ],
    );
  }

  Widget _buildSidebarContent(BuildContext context) {
    final role = widget.userRole.toLowerCase();
    bool isSuper = role == 'superadmin';
    bool isFinance = role == 'finance';
    bool isLogistics = role == 'logistics' || role == 'inventory'; // المخازن
    bool isMarketing = role == 'marketing';

    return Column(
      children: [
        const SizedBox(height: 30),
        // 1. حسابي (للجميع)
        _buildSidebarItem(Icons.person_outline, "حسابي", () {}, color: Colors.cyanAccent),
        const Divider(color: Colors.white10),

        // 2. إدارة الفريق (سوبر أدمن فقط)
        if (isSuper)
          _buildSidebarItem(Icons.admin_panel_settings, "إدارة الفريق", () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const TeamManagementScreen()));
          }, color: Colors.orangeAccent),

        // 3. المالية (سوبر أدمن + مالية فقط)
        if (isSuper || isFinance)
          _buildSidebarItem(Icons.paid, "المالية", () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const FinancialDashboard()));
          }, color: const Color(0xFF10B981)),

        // 4. الأقسام والمنتجات + المخازن (سوبر أدمن + مخازن فقط)
        if (isSuper || isLogistics) ...[
          _buildSidebarItem(Icons.add_box, "إضافة منتج", () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ManagementPage()));
          }),
          _buildSidebarItem(Icons.warehouse, "المخازن", () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const InventoryHub()));
          }),
        ],

        // 5. الأقسام المتاحة للكل (ما عدا شروطك الخاصة)
        _buildSidebarItem(Icons.inventory_2, "الطلبات", () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const OrdersReportPage()));
        }),
        
        _buildSidebarItem(Icons.group, "تجار التجزئة", () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const BuyersPage()));
        }),

        _buildSidebarItem(Icons.storefront, "الموردين", () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const SellersPage()));
        }),

        // 6. المستهلكين (الكل يشوفها)
        _buildSidebarItem(Icons.people_alt, "المستهلكين", () {
          // هنا ستوجه لصفحة المستهلكين الجديدة لاحقاً
        }, color: Colors.yellowAccent),

        // 7. التسويق (سوبر + تسويق)
        if (isSuper || isMarketing)
          _buildSidebarItem(Icons.campaign, "التسويق", () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const MarketingManagementScreen()));
          }),

        const Spacer(),
        _buildSidebarItem(Icons.logout, "خروج", () => _logout(context), color: Colors.redAccent),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, VoidCallback onTap, {Color color = Colors.white}) {
    return ListTile(
      onTap: onTap,
      title: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 10, fontFamily: 'Tajawal')),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String value, String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
          const SizedBox(width: 15),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(color: Colors.grey, fontFamily: 'Tajawal')),
            ],
          ),
        ],
      ),
    );
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) Navigator.pushReplacementNamed(context, '/');
  }
}

