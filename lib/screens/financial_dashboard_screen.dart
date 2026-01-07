import 'package:flutter/material.dart';
import 'Financial/financial_summary_screen.dart'; // ✅ الاستيراد الصحيح للمسار الجديد

class FinancialDashboard extends StatelessWidget {
  const FinancialDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    // تحديد عدد الكروت بناءً على عرض الشاشة لضمان التوافق (Responsiveness)
    double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount;
    if (screenWidth > 1200) {
      crossAxisCount = 4; // شاشات الكمبيوتر الكبيرة
    } else if (screenWidth > 800) {
      crossAxisCount = 2; // التابلت والشاشات المتوسطة
    } else {
      crossAxisCount = 1; // الموبايل
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text(
          "نظام الإدارة المحاسبي",
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFB21F2D),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          children: [
            // بطاقة ترحيبية علوية (Header)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.account_balance_wallet, size: 60, color: Color(0xFFB21F2D)),
                  const SizedBox(height: 15),
                  const Text(
                    "لوحة التحكم المالية والمحاسبية",
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937)),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "قم بإدارة كافة العمليات المالية والتقارير المحاسبية من مكان واحد",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // شبكة الكروت (Grid of Cards)
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: screenWidth > 800 ? 1.3 : 2.0,
              children: [
                // ✅ ربط كرت الإيرادات بالصفحة الجديدة
                _buildMenuCard(
                  context, 
                  "إيرادات", 
                  Icons.monetization_on, 
                  const Color(0xFFF57C00),
                  onTap: () => Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const FinancialSummaryScreen())
                  ),
                ),
                _buildMenuCard(context, "فواتير", Icons.file_copy, const Color(0xFF1976D2)),
                _buildMenuCard(context, "الحركة المالية", Icons.analytics, const Color(0xFF388E3C)),
                _buildMenuCard(context, "الأرباح والخسائر", Icons.trending_up, const Color(0xFF7B1FA2)),
                _buildMenuCard(context, "إعدادات الحسابات", Icons.settings_applications, Colors.blueGrey),
                _buildMenuCard(context, "التقارير الضريبية", Icons.description, Colors.redAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ويدجت بناء الكرت الواحد مع إضافة خاصية الـ onTap اختيارياً
  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("جاري فتح $title...", style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: color,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
                color: Color(0xFF2D3436),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

