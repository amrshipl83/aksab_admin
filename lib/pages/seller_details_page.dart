import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data'; // ضروري للـ Bytes

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
            title: Text(_f(data['merchantName'] ?? data['supermarketName']), 
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 18)),
            backgroundColor: const Color(0xFF1F2937),
          ),
          body: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: isDesktop ? 1000 : double.infinity),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildHeader(data, isDesktop),
                    const SizedBox(height: 20),
                    if (isDesktop) 
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildFinancialCard(data)),
                          const SizedBox(width: 20),
                          Expanded(child: _buildOperationsCard(data)),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
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
                Text(_f(data['merchantName'] ?? data['supermarketName']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text("المسؤول: ${_f(data['fullname'])} | النشاط: ${_f(data['businessType'])}", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialCard(Map<String, dynamic> data) {
    return _sectionCard("المؤشرات المالية", Icons.analytics_outlined, Colors.green, [
      EditableInfoRow(label: "نسبة العمولة", value: _f(data['commissionRate']), field: "commissionRate", sellerId: sellerId, isNumber: true, suffix: " %"),
      EditableInfoRow(label: "مديونية الكاش باك", value: _f(data['cashbackAccruedDebt']), field: "cashbackAccruedDebt", sellerId: sellerId, isNumber: true, suffix: " ج.م"),
    ]);
  }

  Widget _buildOperationsCard(Map<String, dynamic> data) {
    return _sectionCard("التشغيل والتوصيل", Icons.local_shipping_outlined, Colors.purple, [
      EditableInfoRow(label: "رسوم التوصيل", value: _f(data['deliveryFee']), field: "deliveryFee", sellerId: sellerId, isNumber: true, suffix: " ج.م"),
      EditableInfoRow(label: "أقل طلب", value: _f(data['minOrderTotal']), field: "minOrderTotal", sellerId: sellerId, isNumber: true, suffix: " ج.م"),
    ]);
  }

  Widget _buildBankCard(Map<String, dynamic> data) {
    return _sectionCard("بيانات البنك", Icons.account_balance_outlined, Colors.blue, [
      EditableInfoRow(label: "اسم البنك", value: _f(data['bankName']), field: "bankName", sellerId: sellerId),
      EditableInfoRow(label: "رقم الحساب", value: _f(data['bankAccountNumber']), field: "bankAccountNumber", sellerId: sellerId),
      EditableInfoRow(label: "IBAN", value: _f(data['iban']), field: "iban", sellerId: sellerId),
    ]);
  }

  Widget _buildIdentityCard(Map<String, dynamic> data) {
    return _sectionCard("الهوية", Icons.badge_outlined, Colors.orange, [
      _staticRow("رقم الهاتف", _f(data['phone'])),
      _staticRow("العنوان", _f(data['address'])),
    ]);
  }

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
}

// --- الـ Widget المفقود الذي سبب الخطأ تم تعريفه هنا ---

class EditableInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final String field;
  final String sellerId;
  final bool isNumber;
  final String suffix;

  const EditableInfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.field,
    required this.sellerId,
    this.isNumber = false,
    this.suffix = "",
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          InkWell(
            onTap: () => _showEditDialog(context),
            child: Row(
              children: [
                Text("$value$suffix", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                const SizedBox(width: 4),
                const Icon(Icons.edit, size: 14, color: Colors.blue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: value == "—" ? "" : value);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("تعديل $label", style: const TextStyle(fontFamily: 'Cairo', fontSize: 16)),
        content: TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(hintText: "أدخل القيمة الجديدة", suffixText: suffix),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () async {
              dynamic newValue = controller.text;
              if (isNumber) newValue = double.tryParse(controller.text) ?? 0.0;
              
              await FirebaseFirestore.instance.collection('sellers').doc(sellerId).update({field: newValue});
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text("حفظ"),
          ),
        ],
      ),
    );
  }
}

