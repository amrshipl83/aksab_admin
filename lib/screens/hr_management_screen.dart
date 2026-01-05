import 'package:flutter/material.dart';

class HRManagementScreen extends StatelessWidget {
  const HRManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F5),
      appBar: AppBar(
        title: const Text("الموارد البشرية", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A2C3D),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "مرحباً بك في لوحة تحكم الإدارة",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333D47)),
            ),
            const SizedBox(height: 10),
            const Text("اختر القسم الذي تود إدارته من الأسفل:"),
            const SizedBox(height: 30),
            
            // شبكة الكروت
            Expanded(
              child: GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 800 ? 3 : 1, // 3 كروت في الويب و 1 في الموبايل
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.5,
                children: [
                  _buildHRCard(
                    context,
                    title: "الإداريين",
                    subtitle: "إدارة المديرين والمشرفين",
                    icon: Icons.admin_panel_settings,
                    color: Colors.blue,
                    onTap: () => Navigator.pushNamed(context, '/add-employ'),
                  ),
                  _buildHRCard(
                    context,
                    title: "قسم المبيعات",
                    subtitle: "إدارة مناديب المبيعات والتارجت",
                    icon: Icons.trending_up,
                    color: Colors.orange,
                    onTap: () => Navigator.pushNamed(context, '/human-sales'),
                  ),
                  _buildHRCard(
                    context,
                    title: "التحصيل والدليفري",
                    subtitle: "إدارة المحصلين وسائقي التوصيل",
                    icon: Icons.local_shipping,
                    color: Colors.green,
                    onTap: () => Navigator.pushNamed(context, '/human-delivery'),
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
      {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
          ],
          border: Border(top: BorderSide(color: color, width: 5)), // شريط علوي ملون يعطي لمسة جمالية
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 50, color: color),
              const SizedBox(height: 15),
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              const SizedBox(height: 15),
              const Icon(Icons.arrow_circle_left_outlined, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

