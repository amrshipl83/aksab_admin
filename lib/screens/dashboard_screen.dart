import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _salesTotal = 0;
  int _ordersCount = 0;
  int _sellersCount = 0;
  int _usersCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // جلب البيانات من المجموعات المختلفة (نفس منطق الـ JS الخاص بك)
  Future<void> _loadData() async {
    final orders = await FirebaseFirestore.instance.collection('orders').get();
    final sellers = await FirebaseFirestore.instance.collection('sellers').get();
    final users = await FirebaseFirestore.instance.collection('users').get();

    double total = 0;
    for (var doc in orders.docs) {
      total += (doc.data()['total'] ?? 0).toDouble();
    }

    if (mounted) {
      setState(() {
        _salesTotal = total.toInt();
        _ordersCount = orders.size;
        _sellersCount = sellers.size;
        _usersCount = users.size;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 1. الشريط الجانبي (Sidebar) - عرض 80 بكسل كما في الـ HTML
          Container(
            width: 90,
            color: const Color(0xFF1F2937),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildSidebarItem(Icons.add_box, "الأقسام", () {}),
                  _buildSidebarItem(Icons.shopping_bag, "الطلبات", () {}),
                  _buildSidebarItem(Icons.people, "العملاء", () {}),
                  _buildSidebarItem(Icons.store, "البائعين", () {}),
                  _buildSidebarItem(Icons.local_shipping, "الدليفري", () {}),
                  _buildSidebarItem(Icons.settings, "الإعدادات", () {}),
                  _buildSidebarItem(Icons.badge, "HR", () {}),
                  _buildSidebarItem(Icons.campaign, "التسويق", () {}),
                  _buildSidebarItem(Icons.warehouse, "المخازن", () {}),
                  _buildSidebarItem(Icons.monetization_on, "المالية", () {}, color: Colors.green),
                  _buildSidebarItem(Icons.logout, "خروج", () => _logout(context), color: Colors.redAccent),
                ],
              ),
            ),
          ),
          
          // 2. المحتوى الرئيسي (Main Content)
          Expanded(
            child: Container(
              color: const Color(0xFFF2F4F8),
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text("لوحة التحكم", 
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                  ),
                  const SizedBox(height: 30),
                  // شبكة البطاقات (Cards Grid)
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: 1.5,
                      children: [
                        _buildStatusCard("$_salesTotal ج.م", "إجمالي المبيعات"),
                        _buildStatusCard("$_ordersCount", "عدد الطلبات"),
                        _buildStatusCard("$_sellersCount", "عدد التجار"),
                        _buildStatusCard("$_usersCount", "عدد العملاء"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // تصميم عنصر القائمة الجانبية
  Widget _buildSidebarItem(IconData icon, String label, VoidCallback onTap, {Color color = Colors.white}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 5),
            Text(label, textAlign: TextAlign.center, 
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // تصميم بطاقة الإحصائيات
  Widget _buildStatusCard(String value, String title) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 16, color: Color(0xFF4B5563))),
        ],
      ),
    );
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) Navigator.pushReplacementNamed(context, '/');
  }
}

