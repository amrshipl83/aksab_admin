import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class InvoiceDetailsScreen extends StatelessWidget {
  final String invoiceId;
  const InvoiceDetailsScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("فاتورة رقم: ${invoiceId.substring(0, 8)}",
            style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: const Color(0xFFB30000),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              // يمكن لاحقاً إضافة وظيفة الطباعة هنا
            },
          )
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('invoices').doc(invoiceId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("الفاتورة غير موجودة"));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          return _buildInvoiceBody(context, data);
        },
      ),
    );
  }

  Widget _buildInvoiceBody(BuildContext context, Map<String, dynamic> data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          // الإصلاح الجوهري هنا: استخدام BoxConstraints بدلاً من maxWidth المباشرة
          constraints: const BoxConstraints(maxWidth: 800),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: Column(
            children: [
              // الهيدر الملون
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFB30000),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("فاتورة ضريبية (أكسب)",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo')),
                    const Icon(Icons.receipt_long, color: Colors.white, size: 40),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderInfo(data),
                    const Divider(height: 40),
                    
                    _buildSectionTitle("بيانات المحرك المالي (اللمدا)"),
                    _buildDetailRow("العمولة المحققة (realizedCommission)", data['realizedCommission']),
                    _buildDetailRow("الاشتراك الشهري الثابت (monthlyFee)", data['monthlyFee']),
                    _buildDetailRow("ضريبة القيمة المضافة (vatAmount)", data['vatAmount']),
                    
                    const SizedBox(height: 20),
                    _buildSectionTitle("تسويات الكاش باك والديون"),
                    _buildDetailRow("ديون كاش باك (accruedDebt)", data['cashbackAccruedDebt'], isDebt: true),
                    _buildDetailRow("رصيد مستحق للمورد (platformCredit)", data['cashbackPlatformCredit'], isCredit: true),
                    
                    const SizedBox(height: 30),
                    _buildTotalSection(data['finalAmount']),
                    
                    const SizedBox(height: 40),
                    const Center(
                      child: Text("شكراً لتعاملكم مع منصة أكسب",
                          style: TextStyle(fontFamily: 'Cairo', color: Colors.grey, fontSize: 12)),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(Map<String, dynamic> data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("معرف التاجر: ${data['sellerId']}", style: const TextStyle(fontWeight: FontWeight.bold)),
            Text("تاريخ الإصدار: ${data['creationDate']?.toString().split('T')[0] ?? ''}"),
          ],
        ),
        Chip(
          label: Text(data['status'] == 'paid' ? "تم السداد" : "مستحقة للدفع",
              style: const TextStyle(color: Colors.white, fontFamily: 'Cairo')),
          backgroundColor: data['status'] == 'paid' ? Colors.green : Colors.orange,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFFB30000),
              fontFamily: 'Cairo')),
    );
  }

  Widget _buildDetailRow(String label, dynamic value, {bool isDebt = false, bool isCredit = false}) {
    double amount = double.tryParse(value?.toString() ?? '0') ?? 0;
    Color textColor = Colors.black87;
    if (isDebt && amount > 0) textColor = Colors.red;
    if (isCredit && amount > 0) textColor = Colors.green;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontSize: 13))),
          Text("${amount.toStringAsFixed(2)} ج.م",
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildTotalSection(dynamic finalAmount) {
    double amount = double.tryParse(finalAmount?.toString() ?? '0') ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB30000), width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("صافي المبلغ المطلوب:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          Text("${amount.toStringAsFixed(2)} ج.م",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFB30000))),
        ],
      ),
    );
  }
}

