import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// الربط بالصفحات
import '../pages/management_page.dart';
import '../pages/orders_report_page.dart';
import '../pages/buyers_page.dart'; 
import '../pages/sellers_page.dart';

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
  double _salesTotal = 0;
  int _ordersCount = 0;
  int _sellersCount = 0;
  int _buyersCount = 0;
  int _consumersCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final ordersSnapshot = await FirebaseFirestore.instance.collection("orders").get();
      final sellersSnapshot = await FirebaseFirestore.instance.collection("sellers").get();
      final buyersSnapshot = await FirebaseFirestore.instance.collection("buyers").get();
      final consumersSnapshot = await FirebaseFirestore.instance.collection("users").get();

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
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 800;
        return Scaffold(
          backgroundColor: const Color(0xFFF2F4F8),
          appBar: isMobile
              ? AppBar(
                  title: const Text("أكسب - الإدارة", style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
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
        const Text("مرحباً بك في نظام أكسب الذكي", style: TextStyle(fontSize: 14, color: Colors.grey, fontFamily: 'Tajawal')),
        Text(
          "لوحة التحكم (${widget.userRole})",
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937), fontFamily: 'Tajawal'),
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
        _buildStatusCard("$_ordersCount", "الطلبات", Icons.shopping_cart, Colors.orange),
        _buildStatusCard("$_sellersCount", "الموردين", Icons.store, Colors.purple),
        _buildStatusCard("$_consumersCount", "المستهلكين", Icons.person_pin, Colors.teal),
      ],
    );
  }

  Widget _buildSidebarContent(BuildContext context) {
    final role = widget.userRole.toLowerCase();
    bool isSuper = role == 'superadmin';
    bool isFinance = role == 'finance';
    bool isLogistics = role == 'logistics' || role == 'inventory';
    bool isMarketing = role == 'marketing';
    bool isHR = role == 'hr' || isSuper;
    bool isDelivery = role == 'delivery' || isSuper || isLogistics;

    return Container(
      color: const Color(0xFF1F2937),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 40),
          
          // 1. حسابي (لون لبني)
          _buildSidebarItem(Icons.person_outline, "حسابي", () {
            // سيتم ربط صفحة تعديل الحساب لاحقاً
          }, color: Colors.cyanAccent),
          
          const Divider(color: Colors.white10, indent: 15, endIndent: 15),

          // 2. إدارة الفريق (برتقالي - للسوبر أدمن فقط)
          if (isSuper)
            _buildSidebarItem(Icons.admin_panel_settings, "إدارة الفريق", () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TeamManagementScreen()));
            }, color: Colors.orangeAccent),

          // 3. المالية (أخضر زاهي)
          if (isSuper || isFinance)
            _buildSidebarItem(Icons.paid, "المالية", () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const FinancialDashboard()));
            }, color: Colors.greenAccent),

          // 4. الموارد البشرية (أزرق فاتح)
          if (isHR)
            _buildSidebarItem(Icons.badge, "الموظفين (HR)", () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const HRManagementScreen()));
            }, color: Colors.lightBlueAccent),

          // 5. المخازن والمنتجات (أبيض)
          if (isSuper || isLogistics) ...[
            _buildSidebarItem(Icons.add_box, "إضافة منتج", () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ManagementPage()));
            }),
            _buildSidebarItem(Icons.warehouse, "المخازن", () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const InventoryHub()));
            }),
          ],

          // 6. الطلبات والتجار والموردين (أبيض)
          _buildSidebarItem(Icons.inventory_2, "الطلبات", () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const OrdersReportPage()));
          }),
          _buildSidebarItem(Icons.group, "تجار التجزئة", () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const BuyersPage()));
          }),
          _buildSidebarItem(Icons.storefront, "الموردين", () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SellersPage()));
          }),

          // 7. المستهلكين (أصفر ذهبي مميز)
          _buildSidebarItem(Icons.people_alt, "المستهلكين", () {
             // سنقوم ببرمجتها الآن
          }, color: Colors.yellowAccent),

          // 8. إدارة الدليفري (أخضر ليموني)
          if (isDelivery)
            _buildSidebarItem(Icons.local_shipping, "الدليفري", () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const DeliveryManagementScreen()));
            }, color: Colors.limeAccent),

          // 9. التسويق (بنفسجي فاتح)
          if (isSuper || isMarketing)
            _buildSidebarItem(Icons.campaign, "التسويق", () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MarketingManagementScreen()));
            }, color: Colors.purpleAccent),

          const Divider(color: Colors.white10, indent: 15, endIndent: 15),
          _buildSidebarItem(Icons.logout, "خروج", () => _logout(context), color: Colors.redAccent),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, VoidCallback onTap, {Color color = Colors.white}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 5),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 5),
          Text(
            label, 
            textAlign: TextAlign.center, 
            style: TextStyle(color: color, fontSize: 10, fontFamily: 'Tajawal', fontWeight: FontWeight.w500)
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String value, String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis)),
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Tajawal')),
              ],
            ),
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

