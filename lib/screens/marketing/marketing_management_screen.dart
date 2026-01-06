import 'package:flutter/material.dart';

class MarketingManagementScreen extends StatelessWidget {
  const MarketingManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // قياس عرض الشاشة لتحديد التصميم المتوافق
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 800;

    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F5),
      appBar: AppBar(
        title: const Text(
          "إدارة التسويق والعروض",
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
            const Text(
              "أدوات التحكم في العروض والولاء",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333D47),
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                // يتغير عدد الأعمدة: 1 للموبايل، 3 للشاشات الكبيرة
                crossAxisCount: isMobile ? 1 : 3,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: isMobile ? 2.2 : 1.4,
                children: [
                  _buildMarketingCard(
                    context,
                    title: "الكاش باك",
                    subtitle: "إدارة نسب استرداد الأموال",
                    icon: Icons.percent,
                    color: Colors.redAccent,
                    onTap: () {
                      // Navigator.push... لصفحة الكاش باك
                    },
                  ),
                  _buildMarketingCard(
                    context,
                    title: "البانرات الإعلانية",
                    subtitle: "تغيير صور العروض الرئيسية",
                    icon: Icons.view_carousel,
                    color: Colors.blueAccent,
                    onTap: () {},
                  ),
                  _buildMarketingCard(
                    context,
                    title: "نظام النقاط",
                    subtitle: "إدارة نقاط المكافآت واستبدالها",
                    icon: Icons.monetization_on,
                    color: Colors.amber,
                    onTap: () {},
                  ),
                  _buildMarketingCard(
                    context,
                    title: "الإشعارات الترويجية",
                    subtitle: "إرسال رسائل تنبيهية للعملاء",
                    icon: Icons.notification_important,
                    color: Colors.deepPurple,
                    onTap: () {},
                  ),
                  _buildMarketingCard(
                    context,
                    title: "المساعد الذكي",
                    subtitle: "تغذية بيانات الذكاء الاصطناعي",
                    icon: Icons.psychology,
                    color: Colors.teal,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketingCard(BuildContext context,
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
          border: Border(right: BorderSide(color: color, width: 6)), // تمييز جانبي باللون
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, size: 30, color: color),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo')),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'Cairo',
                            color: Colors.grey)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

