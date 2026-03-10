import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MonthlyFinanceDetails extends StatelessWidget {
  final String selectedPeriod;

  const MonthlyFinanceDetails({super.key, required this.selectedPeriod});

  // --- دالة طباعة تقرير الشهر PDF ---
  Future<void> _generateMonthlyPdf(double sellers, double delivery, double subs, double expenses, double net) async {
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
              pw.Center(child: pw.Text("تقرير الأداء المالي الشهري - أكسب", style: pw.TextStyle(font: boldFont, fontSize: 24))),
              pw.SizedBox(height: 10),
              pw.Center(child: pw.Text("الفترة المعتمدة: $selectedPeriod", style: pw.TextStyle(font: font, fontSize: 16))),
              pw.Divider(),
              pw.SizedBox(height: 30),
              
              _pdfRow("إيرادات الموردين والمخازن", sellers, font),
              _pdfRow("إيرادات خدمات التوصيل", delivery, font),
              _pdfRow("إيرادات اشتراكات باقات أكسب", subs, font),
              pw.SizedBox(height: 10),
              _pdfRow("إجمالي المصاريف والتشغيل", expenses, font, isRed: true),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("${net.toStringAsFixed(2)} ج.م", style: pw.TextStyle(font: boldFont, fontSize: 20)),
                  pw.Text("صافي الربح النهائي:", style: pw.TextStyle(font: boldFont, fontSize: 20)),
                ],
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _pdfRow(String label, double val, pw.Font font, {bool isRed = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text("${val.toStringAsFixed(2)} ج.م", style: pw.TextStyle(font: font, fontSize: 14)),
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: Text("تحليل أداء $selectedPeriod", style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFB21F2D),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () {}, // سيتم تفعيله من داخل الـ StreamBuilder بالأسفل
            tooltip: "تصدير التقرير",
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('platform_ledger')
            .where('period', isEqualTo: selectedPeriod)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          double sellersRevenue = 0;
          double deliveryRevenue = 0;
          double subscriptionRevenue = 0; // المصدر الجديد ✅
          double totalExpenses = 0;

          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            double amount = (data['totalAmount'] ?? 0).toDouble();

            if (data['entryType'] == 'revenue') {
              if (data['source'] == 'sellers') sellersRevenue += amount;
              if (data['source'] == 'delivery') deliveryRevenue += amount;
              if (data['source'] == 'subscriptions') subscriptionRevenue += amount; // جلب بيانات الباقات ✅
            } else if (data['entryType'] == 'expense') {
              totalExpenses += amount;
            }
          }

          double netProfit = (sellersRevenue + deliveryRevenue + subscriptionRevenue) - totalExpenses;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSummaryCard(netProfit),
              const SizedBox(height: 30),
              
              const Text("تفاصيل بنود الدخل والخرج", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 15),
              
              _buildRowItem("إيرادات الموردين", sellersRevenue, Colors.green),
              _buildRowItem("إيرادات التوصيل", deliveryRevenue, Colors.blue),
              _buildRowItem("إيرادات الباقات (المحققة)", subscriptionRevenue, Colors.teal), // عرض بند الباقات ✅
              _buildRowItem("إجمالي المصاريف", totalExpenses, Colors.red),
              
              const Divider(height: 40, thickness: 2),
              
              _buildRowItem("الصافي النهائي للشهر", netProfit, Colors.black, isBold: true),
              
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () => _generateMonthlyPdf(sellersRevenue, deliveryRevenue, subscriptionRevenue, totalExpenses, netProfit),
                icon: const Icon(Icons.print),
                label: const Text("طباعة تقرير الشهر الرسمي (PDF)", style: TextStyle(fontFamily: 'Cairo')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB21F2D),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(double net) {
    bool isProfit = net >= 0;
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isProfit ? [Colors.green[700]!, Colors.green[900]!] : [Colors.red[700]!, Colors.red[900]!],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          const Text("صافي أرباح المنصة", style: TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 16)),
          const SizedBox(height: 10),
          Text("${net.toStringAsFixed(2)} ج.م", 
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRowItem(String title, double value, Color color, {bool isBold = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("${value.toStringAsFixed(2)} ج.م", 
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          Text(title, 
            style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

