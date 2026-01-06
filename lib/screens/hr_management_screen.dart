import 'package:flutter/material.dart';
import 'sales_management_screen.dart'; // استيراد صفحة المبيعات
import 'staff_management_delivery.dart'; // استيراد صفحة التحصيل والدليفري

class HRManagementScreen extends StatelessWidget {
  const HRManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // تحديد عرض الشاشة لضبط التصميم
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 800;

    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F5),
      appBar: AppBar(
        title: const Text(
          "الموارد البشرية",
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A2C3D),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 15.0 : 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "مرحباً بك في لوحة تحكم الإدارة",
              style: TextStyle(
                fontSize: isMobile ? 18 : 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF333D47),
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "اختر القسم الذي تود إدارته من الأسفل:",
              style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
            ),
            const SizedBox(height: 30),
            
            // شبكة الكروت المتوافقة مع الشاشات
            Expanded(
              child: GridView.count(
                // 3 أعمدة للويب و 1 للموبايل
                crossAxisCount: isMobile ? 1 : 3,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: isMobile ? 2.0 : 1.3,
                children: [
                  _buildHRCard(
                    context,
                    title: "الإداريين",
                    subtitle: "إدارة المديرين والمشرفين",
                    icon: Icons.admin_panel_settings,
                    color: Colors.blue,
                    onTap: () {
                      // سيتم ربطها لاحقاً
                    },
                  ),
                  _buildHRCard(
                    context,
                    title: "قسم المبيعات",
                    subtitle: "إدارة مناديب المبيعات والتارجت",
                    icon: Icons.trending_up,
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SalesManagementScreen()),
                      );
                    },
                  ),
                  _buildHRCard(
                    context,
                    title: "التحصيل والدليفري",
                    subtitle: "إدارة المحصلين وسائقي التوصيل",
                    icon: Icons.local_shipping,
                    color: Colors.green,
                    onTap: () {
                      // تم إزالة const هنا لإصلاح خطأ البناء
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const StaffManagementDelivery()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHRCard(BuildContext context,
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border(top: BorderSide(color: color, width: 5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 50, color: color),
              const SizedBox(height: 15),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 15),
              Icon(Icons.arrow_circle_left_outlined, color: color.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

