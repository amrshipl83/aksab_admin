import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // متغيرات البيانات
  double _salesTotal = 0;
  int _ordersCount = 0;
  int _sellersCount = 0;
  int _usersCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // جلب البيانات مع مراعاة أسماء المجموعات والحقول التي حددناها سابقاً
    final orders = await FirebaseFirestore.instance.collection('orders').get();
    final sellers = await FirebaseFirestore.instance.collection('sellers').get();
    final users = await FirebaseFirestore.instance.collection('users').get();

    double total = 0;
    for (var doc in orders.docs) {
      total += (doc.data()['total'] ?? 0).toDouble();
    }

    if (mounted) {
      setState(() {
        _salesTotal = total;
        _ordersCount = orders.size;
        _sellersCount = sellers.size;
        _usersCount = users.size;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // تحديد نوع الجهاز بناءً على العرض
    bool isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      appBar: isMobile ? AppBar(
        title: const Text("لوحة التحكم", style: TextStyle(fontFamily: 'Tajawal')),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
      ) : null,
      
      // القائمة الجانبية: تظهر كـ Drawer في الموبايل و كـ Sidebar ثابت في الكمبيوتر
      drawer: isMobile ? Drawer(child: _buildSidebarContent()) : null,
      
      body: Row(
        children: [
          // لو كمبيوتر، اعرض الـ Sidebar ثابت
          if (!isMobile) Container(
            width: 100,
            color: const Color(0xFF1F2937),
            child: _buildSidebarContent(),
          ),
          
          // المحتوى الرئيسي
          Expanded(
            child: Container(
              color: const Color(0xFFF2F4F8),
              padding: EdgeInsets.all(isMobile ? 15 : 30),
              child: Column(
                children: [
                  if (!isMobile) const Padding(
                    padding: EdgeInsets.only(bottom: 30),
                    child: Text("لوحة التحكم الإدارية", 
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                  ),
                  
                  // شبكة البطاقات: عمود واحد للموبايل، 4 أعمدة للكمبيوتر
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: isMobile ? 1 : 4, 
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: isMobile ? 2.5 : 1.3,
                      children: [
                        _buildStatusCard("${_salesTotal.toStringAsFixed(2)} ج.م", "إجمالي المبيعات", Colors.blue),
                        _buildStatusCard("$_ordersCount", "عدد الطلبات", Colors.orange),
                        _buildStatusCard("$_sellersCount", "عدد التجار", Colors.green),
                        _buildStatusCard("$_usersCount", "عدد العملاء", Colors.purple),
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

  // محتوى القائمة الجانبية (مفصول ليعمل في الـ Drawer والـ Sidebar)
  Widget _buildSidebarContent() {
    return Container(
      color: const Color(0xFF1F2937),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 50),
            _buildSidebarItem(Icons.dashboard, "الرئيسية", () {}),
            _buildSidebarItem(Icons.add_box, "الأقسام", () {}),
            _buildSidebarItem(Icons.shopping_bag, "الطلبات", () {}),
            _buildSidebarItem(Icons.people, "العملاء", () {}),
            _buildSidebarItem(Icons.store, "البائعين", () {}),
            _buildSidebarItem(Icons.monetization_on, "المالية", () {}, color: Colors.greenAccent),
            _buildSidebarItem(Icons.logout, "خروج", () => _logout(context), color: Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, VoidCallback onTap, {Color color = Colors.white}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      title: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildStatusCard(String value, String title, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border(right: BorderSide(color: accentColor, width: 5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
        ],
      ),
    );
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) Navigator.pushReplacementNamed(context, '/');
  }
}

