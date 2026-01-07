import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// الربط بالصفحات
import '../pages/management_page.dart';
import '../pages/orders_report_page.dart';
import '../pages/buyers_page.dart';
import '../pages/sellers_page.dart';

// استيراد الشاشات الجديدة
import '../screens/delivery_management_screen.dart';
import '../screens/hr_management_screen.dart';
import '../screens/marketing/marketing_management_screen.dart';
import '../screens/inventory/inventory_hub.dart';
import '../screens/financial_dashboard_screen.dart'; // ✅ إضافة استيراد الإدارة المالية

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double _salesTotal = 0;
  int _ordersCount = 0;
  int _sellersCount = 0;
  int _usersCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final ordersSnapshot = await FirebaseFirestore.instance.collection("orders").get();
      final sellersSnapshot = await FirebaseFirestore.instance.collection("sellers").get();
      final buyersSnapshot = await FirebaseFirestore.instance.collection("users").get();

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
          _usersCount = buyersSnapshot.size;
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: isMobile
          ? AppBar(
              title: const Text("لوحة التحكم",
                  style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF1F2937),
              foregroundColor: Colors.white,
            )
          : null,
      drawer: isMobile ? Drawer(child: _buildSidebarContent(context)) : null,
      body: Row(
        children: [
          if (!isMobile)
            Container(
              width: 90,
              color: const Color(0xFF1F2937),
              child: _buildSidebarContent(context),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 15 : 30),
              child: Column(
                children: [
                  Text(
                    "لوحة التحكم",
                    style: TextStyle(
                      fontSize: isMobile ? 24 : 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2937),
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 25),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: isMobile ? 1 : (MediaQuery.of(context).size.width > 1100 ? 4 : 2),
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: isMobile ? 2.5 : 1.5,
                    children: [
                      _buildStatusCard("${_salesTotal.toStringAsFixed(2)} ج.م", "إجمالي المبيعات"),
                      _buildStatusCard("$_ordersCount", "عدد الطلبات"),
                      _buildStatusCard("$_sellersCount", "عدد التجار"),
                      _buildStatusCard("$_usersCount", "عدد العملاء"),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent(BuildContext context) {
    return Container(
      color: const Color(0xFF1F2937),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildSidebarItem(Icons.add_box, "إضافة الأقسام والمنتجات", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ManagementPage()),
              );
            }),
            _buildSidebarItem(Icons.inventory_2, "الطلبات", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OrdersReportPage()),
              );
            }),
            _buildSidebarItem(Icons.group, "العملاء", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BuyersPage()),
              );
            }),
            _buildSidebarItem(Icons.storefront, "البائعين", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SellersPage()),
              );
            }),
            _buildSidebarItem(Icons.local_shipping, "إدارة الدليفري", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DeliveryManagementScreen()),
              );
            }),
            _buildSidebarItem(Icons.settings, "الإعدادات", () {}),
            _buildSidebarItem(Icons.assignment_ind, "الموارد البشرية", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HRManagementScreen()),
              );
            }),
            _buildSidebarItem(Icons.add_photo_alternate, "ادارة التسويق", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MarketingManagementScreen()),
              );
            }),
            _buildSidebarItem(Icons.warehouse, "ادارة المخازن والمشتريات", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InventoryHub()),
              );
            }),
            // ✅ تم ربط الإدارة المالية بالصفحة الجديدة هنا
            _buildSidebarItem(Icons.paid, "الإدارة المالية", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FinancialDashboard()),
              );
            }, color: const Color(0xFF10B981)),
            _buildSidebarItem(Icons.security, "الاستخدام والخصوصية", () {}),
            const Divider(color: Colors.white24),
            _buildSidebarItem(Icons.logout, "خروج", () => _logout(context), color: Colors.redAccent),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, VoidCallback onTap, {Color color = Colors.white}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 10, fontFamily: 'Tajawal'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String value, String title) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 18, color: Color(0xFF4B5563), fontFamily: 'Tajawal'),
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

