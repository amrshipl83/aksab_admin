import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class FinancialSummaryScreen extends StatefulWidget {
  const FinancialSummaryScreen({super.key});

  @override
  State<FinancialSummaryScreen> createState() => _FinancialSummaryScreenState();
}

class _FinancialSummaryScreenState extends State<FinancialSummaryScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // تنسيق العملة المصرية
  String formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'ar_EG', symbol: 'ج.م', decimalDigits: 2).format(amount);
  }

  // دالة لحساب الاشتراكات غير المحققة (الالتزامات)
  Future<double> _fetchUnearnedSubscriptions() async {
    double totalUnearned = 0;
    final snapshot = await _db.collection('active_subscriptions')
        .where('status', '==', 'active')
        .get();

    for (var doc in snapshot.docs) {
      final d = doc.data();
      double dailyRate = (d['dailyRate'] ?? 0).toDouble();
      int remainingDays = (d['remainingDays'] ?? 0).toInt();
      totalUnearned += (dailyRate * remainingDays);
    }
    return totalUnearned;
  }

  // --- ميزة طباعة التقرير PDF ---
  Future<void> _generatePdfReport(Map<String, dynamic> merchantData, Map<String, dynamic> deliveryData, double unearnedSubs) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text("تقرير الأرصدة المالي للمنصة - رابية أحلى", style: pw.TextStyle(font: boldFont, fontSize: 22)),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text("تاريخ التقرير: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}", style: pw.TextStyle(font: font, fontSize: 14)),
              ),
              pw.Divider(),
              pw.SizedBox(height: 20),
              
              // قسم التجار
              pw.Text("1. حسابات التجار والعمولات:", style: pw.TextStyle(font: boldFont, fontSize: 18)),
              pw.Bullet(text: "عمولات محققة: ${formatCurrency(merchantData['realized'])}", style: pw.TextStyle(font: font)),
              pw.Bullet(text: "دين كاش باك: ${formatCurrency(merchantData['cbDebt'])}", style: pw.TextStyle(font: font)),
              
              pw.SizedBox(height: 20),
              
              // قسم التوصيل
              pw.Text("2. حصالة التوصيل (الشهر الحالي):", style: pw.TextStyle(font: boldFont, fontSize: 18)),
              pw.Bullet(text: "عمولات كاش: ${formatCurrency(deliveryData['walletRevenue'])}", style: pw.TextStyle(font: font)),
              pw.Bullet(text: "عمولات آجل: ${formatCurrency(deliveryData['creditRevenue'])}", style: pw.TextStyle(font: font)),
              pw.Bullet(text: "إجمالي طلبات الشهر: ${deliveryData['totalOrders']}", style: pw.TextStyle(font: font)),
              
              pw.SizedBox(height: 20),

              // قسم الباقات
              pw.Text("3. حسابات الباقات والاشتراكات:", style: pw.TextStyle(font: boldFont, fontSize: 18)),
              pw.Bullet(text: "إيراد باقات محقق (هذا الشهر): ${formatCurrency(deliveryData['subscriptionRevenue'] ?? 0)}", style: pw.TextStyle(font: font)),
              pw.Bullet(text: "أرصدة باقات غير محققة (التزام مستقبلي): ${formatCurrency(unearnedSubs)}", style: pw.TextStyle(font: font)),
              
              pw.Spacer(),
              pw.Divider(),
              pw.Center(child: pw.Text("نظام إدارة رابية أحلى المحاسبي", style: pw.TextStyle(font: font, fontSize: 10))),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text("ملخص أرصدة المنصة التراكمي", style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: const Color(0xFFB21F2D),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: () async {
              // جلب البيانات الحالية للطباعة
              final merchantData = await _fetchMerchantFinancialData();
              final deliveryDoc = await _db.collection('platform_stats').doc('delivery_monthly_accumulator').get();
              final deliveryData = deliveryDoc.data() ?? {};
              final unearned = await _fetchUnearnedSubscriptions();
              _generatePdfReport(merchantData, deliveryData, unearned);
            },
            tooltip: "تحميل تقرير PDF",
          ),
          TextButton.icon(
            onPressed: () => _showVehicleSettingsSheet(context),
            icon: const Icon(Icons.settings_suggest, color: Colors.white),
            label: const Text("إعدادات التوصيل",
                style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- القسم الأول: العمولات والديون (التجار) ---
            const Text("📊 نظرة عامة على العمولات والديون (التجار)",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            const SizedBox(height: 15),
            FutureBuilder<Map<String, dynamic>>(
              future: _fetchMerchantFinancialData(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final data = snapshot.data!;
                return _buildGrid([
                  _buildFinanceCard("عمولات محققة", data['realized'], Icons.check_circle, Colors.green),
                  _buildFinanceCard("عمولات قيد التجميع", data['unrealized'], Icons.hourglass_bottom, Colors.orange),
                  _buildFinanceCard("دين كاش باك", data['cbDebt'], Icons.trending_down, Colors.red),
                  _buildFinanceCard("إيراد رسوم شهري", data['monthlyFees'], Icons.event_note, Colors.teal),
                ]);
              },
            ),

            const SizedBox(height: 30),
            const Divider(thickness: 2),
            const SizedBox(height: 15),

            // --- القسم الثاني: حصالة التوصيل (لايف) ---
            const Text("🚚 إيرادات التوصيل (الشهر الحالي)",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Color(0xFFB21F2D))),
            const SizedBox(height: 15),
            StreamBuilder<DocumentSnapshot>(
              stream: _db.collection('platform_stats').doc('delivery_monthly_accumulator').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
                final delData = snapshot.data!.data() as Map<String, dynamic>;
                return _buildGrid([
                  _buildFinanceCard("عمولات كاش", (delData['walletRevenue'] ?? 0).toDouble(), Icons.payments, Colors.deepPurple),
                  _buildFinanceCard("عمولات آجل", (delData['creditRevenue'] ?? 0).toDouble(), Icons.history, Colors.indigo),
                  _buildFinanceCard("دخل الطيارين", (delData['totalDriversEarnings'] ?? 0).toDouble(), Icons.moped, Colors.orange[800]!),
                  _buildFinanceCard("عدد الطلبات", (delData['totalOrders'] ?? 0).toDouble(), Icons.shopping_bag, Colors.brown, isCurrency: false),
                ]);
              },
            ),

            const SizedBox(height: 30),
            const Divider(thickness: 2),
            const SizedBox(height: 15),

            // --- القسم الثالث: محاسبة الباقات (الحل الجديد) ---
            const Text("💳 محاسبة اشتراكات رابية",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.teal)),
            const SizedBox(height: 15),
            FutureBuilder<double>(
              future: _fetchUnearnedSubscriptions(),
              builder: (context, unearnedSnapshot) {
                return StreamBuilder<DocumentSnapshot>(
                  stream: _db.collection('platform_stats').doc('delivery_monthly_accumulator').snapshots(),
                  builder: (context, statsSnapshot) {
                    if (!statsSnapshot.hasData) return const SizedBox();
                    final statsData = statsSnapshot.data!.data() as Map<String, dynamic>;
                    return _buildGrid([
                      _buildFinanceCard(
                        "إيراد باقات (محقق)", 
                        (statsData['subscriptionRevenue'] ?? 0).toDouble(), 
                        Icons.check_box, 
                        Colors.teal
                      ),
                      _buildFinanceCard(
                        "أرصدة باقات (غير محققة)", 
                        unearnedSnapshot.data ?? 0, 
                        Icons.pending, 
                        Colors.blueGrey
                      ),
                    ]);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<Widget> children) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 1,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: children,
    );
  }

  // --- دوال المساعدة والبناء (Build Helpers) ---
  
  Future<Map<String, dynamic>> _fetchMerchantFinancialData() async {
    double totalRealized = 0;
    double totalUnrealized = 0;
    double totalCbDebt = 0;
    double totalCbCredit = 0;
    double totalMonthlyFees = 0;

    final sellersSnapshot = await _db.collection('sellers').get();
    for (var doc in sellersSnapshot.docs) {
      final d = doc.data();
      totalRealized += (d['realizedCommission'] ?? 0).toDouble();
      totalUnrealized += (d['unrealizedCommission'] ?? 0).toDouble();
      totalCbDebt += (d['cashbackAccruedDebt'] ?? 0).toDouble();
      totalCbCredit += (d['cashbackPlatformCredit'] ?? 0).toDouble();
      totalMonthlyFees += (d['monthlyFee'] ?? 0).toDouble();
    }
    final invoicesSnapshot = await _db.collection('invoices').where('status', isEqualTo: 'pending').get();
    return {
      'realized': totalRealized,
      'unrealized': totalUnrealized,
      'cbDebt': totalCbDebt,
      'cbCredit': totalCbCredit,
      'monthlyFees': totalMonthlyFees,
      'pendingInvoices': invoicesSnapshot.size,
    };
  }

  Widget _buildFinanceCard(String title, double value, IconData icon, Color color, {bool isCurrency = true}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(right: BorderSide(color: color, width: 6)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Cairo')),
                const SizedBox(height: 5),
                Text(
                  isCurrency ? formatCurrency(value) : value.toInt().toString(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showVehicleSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFFF4F7FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: const VehicleSettingsPanel(),
      ),
    );
  }
}

// الكلاسات الفرعية للإعدادات (VehicleSettingsPanel, VehicleConfigCard) تبقى كما هي في الكود الأصلي الخاص بك.

