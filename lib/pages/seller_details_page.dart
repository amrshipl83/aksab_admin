import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SellerDetailsPage extends StatelessWidget {
  final String sellerId;
  final Map<String, dynamic> sellerData;

  const SellerDetailsPage({super.key, required this.sellerId, required this.sellerData});

  String _f(dynamic val) => (val == null || val.toString().isEmpty) ? "—" : val.toString();

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth > 900;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('sellers').doc(sellerId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.hasData ? snapshot.data!.data() as Map<String, dynamic> : sellerData;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            // الاعتماد الأساسي هنا على الاسم التجاري (Merchant Name / Supermarket Name)
            title: Text(_f(data['merchantName'] ?? data['supermarketName']), 
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 18)),
            backgroundColor: const Color(0xFF1F2937),
            actions: [
              IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () {}),
            ],
          ),
          body: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: isDesktop ? 1000 : double.infinity),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildHeader(data, isDesktop), // يحتوي على اسم الشخص والنشاط
                    const SizedBox(height: 20),
                    
                    if (isDesktop) 
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildFinancialCard(data)),
                          const SizedBox(width: 20),
                          Expanded(child: _buildOperationsCard(data)), // قسم التشغيل الجديد
                        ],
                      )
                    else ...[
                      _buildFinancialCard(data),
                      const SizedBox(height: 16),
                      _buildOperationsCard(data),
                    ],
                    
                    const SizedBox(height: 16),
                    _buildBankCard(data),
                    const SizedBox(height: 16),
                    _buildIdentityCard(data),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(Map<String, dynamic> data, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: isDesktop ? 40 : 30,
            backgroundImage: data['merchantLogoUrl'] != null ? NetworkImage(data['merchantLogoUrl']) : null,
            child: data['merchantLogoUrl'] == null ? const Icon(Icons.store) : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الاسم التجاري هو العنوان الكبير
                Text(_f(data['merchantName'] ?? data['supermarketName']), 
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                // اسم صاحب النشاط ونوع النشاط
                Text("المسؤول: ${_f(data['fullname'])} | النشاط: ${_f(data['businessType'])}", 
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                const SizedBox(height: 8),
                _statusChip(_f(data['status'])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // قسم التشغيل ومناطق التوصيل (جديد)
  Widget _buildOperationsCard(Map<String, dynamic> data) {
    return _sectionCard("بيانات التشغيل والتوصيل", Icons.local_shipping_outlined, Colors.purple, [
      EditableInfoRow(label: "رسوم التوصيل", value: _f(data['deliveryFee']), field: "deliveryFee", sellerId: sellerId, isNumber: true, suffix: " ج.م"),
      EditableInfoRow(label: "أقل قيمة للطلب", value: _f(data['minOrderTotal']), field: "minOrderTotal", sellerId: sellerId, isNumber: true, suffix: " ج.م"),
      const SizedBox(height: 8),
      const Text("مناطق التوصيل المدعومة:", style: TextStyle(color: Colors.grey, fontSize: 12)),
      const SizedBox(height: 4),
      // عرض مناطق التوصيل كـ Tags أو نص مجمع
      Wrap(
        spacing: 6,
        children: (data['deliveryAreas'] as List? ?? []).map((area) => Chip(
          label: Text(area.toString(), style: const TextStyle(fontSize: 11)),
          backgroundColor: Colors.purple.shade50,
          visualDensity: VisualDensity.compact,
        )).toList(),
      ),
    ]);
  }

  Widget _buildFinancialCard(Map<String, dynamic> data) {
    return _sectionCard("المؤشرات المالية (AWS Live)", Icons.analytics_outlined, Colors.green, [
      EditableInfoRow(label: "نسبة العمولة", value: _f(data['commissionRate']), field: "commissionRate", sellerId: sellerId, isNumber: true, suffix: " %"),
      EditableInfoRow(label: "مديونية الكاش باك", value: _f(data['cashbackAccruedDebt']), field: "cashbackAccruedDebt", sellerId: sellerId, isNumber: true, suffix: " ج.م"),
      _staticRow("العمولة المحققة", "${_f(data['realizedCommission'])} ج.م"),
    ]);
  }

  Widget _buildBankCard(Map<String, dynamic> data) {
    return _sectionCard("بيانات التحويل البنكي", Icons.account_balance_outlined, Colors.blue, [
      EditableInfoRow(label: "اسم البنك", value: _f(data['bankName']), field: "bankName", sellerId: sellerId),
      EditableInfoRow(label: "رقم الحساب", value: _f(data['bankAccountNumber']), field: "bankAccountNumber", sellerId: sellerId),
      EditableInfoRow(label: "رقم الـ IBAN", value: _f(data['iban']), field: "iban", sellerId: sellerId),
    ]);
  }

  Widget _buildIdentityCard(Map<String, dynamic> data) {
    return _sectionCard("بيانات الهوية والتوثيق", Icons.badge_outlined, Colors.orange, [
      _staticRow("رقم الهاتف", _f(data['phone'])),
      _staticRow("الرقم الضريبي", _f(data['taxNumber'])),
      _staticRow("السجل التجاري", _f(data['commercialRegistrationNumber'])),
      _staticRow("العنوان", _f(data['address'])),
    ]);
  }

  // --- دوال البناء المساعدة تظل كما هي ---
  Widget _sectionCard(String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold))]),
        const Divider(height: 24),
        ...children,
      ]),
    );
  }

  Widget _staticRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }

  Widget _statusChip(String status) {
    bool active = status.toLowerCase() == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: active ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(20)),
      child: Text(active ? "نشط" : "معطل", style: TextStyle(color: active ? Colors.green.shade700 : Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

