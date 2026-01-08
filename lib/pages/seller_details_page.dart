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

  // دالة تصدير PDF
  Future<void> _exportToPdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    
    // ملاحظة: لتحسين اللغة العربية في PDF يفضل تحميل خط عربي، هنا نستخدم التنسيق الأساسي
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Seller Report: ${data['merchantName'] ?? data['fullname']}", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.Text("Phone: ${data['phone']}"),
              pw.Text("Address: ${data['address']}"),
              pw.Text("Commission Rate: ${data['commissionRate']}%"),
              pw.Text("Fixed Commission: ${data['fixedCommission']} EGP"),
              pw.Text("Cashback Debt: ${data['cashbackAccruedDebt']} EGP"),
              pw.Text("Min Order: ${data['minOrderTotal']} EGP"),
              pw.SizedBox(height: 20),
              pw.Text("Generated on: ${DateTime.now().toString()}"),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

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
            title: Text(_f(data['merchantName'] ?? data['fullname']),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 18)),
            backgroundColor: const Color(0xFF1F2937),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                onPressed: () => _exportToPdf(data),
                tooltip: "تصدير PDF",
              ),
            ],
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
                    
                    _buildFinancialSummaryCard(data), // الكرت الجديد للحسابات المالية
                    const SizedBox(height: 16),
                    
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildOperationsCard(data)),
                          const SizedBox(width: 20),
                          Expanded(child: _buildCommissionCard(data)),
                        ],
                      )
                    else ...[
                      _buildOperationsCard(data),
                      const SizedBox(height: 16),
                      _buildCommissionCard(data),
                    ],
                    
                    const SizedBox(height: 16),
                    _buildDocumentsCard(context, data),
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

  // كرت الحسابات المالية الجديد
  Widget _buildFinancialSummaryCard(Map<String, dynamic> data) {
    return _sectionCard("المؤشرات المالية المتقدمة", Icons.account_balance_wallet_outlined, Colors.blueGrey, [
      Row(
        children: [
          Expanded(child: _staticRow("عمولة محققة", "${_f(data['realizedCommission'])} ج.م")),
          const SizedBox(width: 10),
          Expanded(child: _staticRow("عمولة معلقة", "${_f(data['unrealizedCommission'])} ج.م")),
        ],
      ),
      const Divider(),
      EditableInfoRow(label: "دين الكاش باك", value: _f(data['cashbackAccruedDebt']), field: "cashbackAccruedDebt", sellerId: sellerId, isNumber: true, suffix: " ج.م"),
      EditableInfoRow(label: "رصيد المنصة", value: _f(data['cashbackPlatformCredit']), field: "cashbackPlatformCredit", sellerId: sellerId, isNumber: true, suffix: " ج.م"),
    ]);
  }

  Widget _buildOperationsCard(Map<String, dynamic> data) {
    return _sectionCard("التشغيل والتوصيل", Icons.local_shipping_outlined, Colors.purple, [
      EditableInfoRow(label: "رسوم التوصيل", value: _f(data['deliveryFee']), field: "deliveryFee", sellerId: sellerId, isNumber: true, suffix: " ج.م"),
      EditableInfoRow(label: "أقل طلب", value: _f(data['minOrderTotal']), field: "minOrderTotal", sellerId: sellerId, isNumber: true, suffix: " ج.م"),
      const Divider(),
      _staticRow("مناطق التوصيل", _f(data['deliveryAreas'])), // عرض مناطق التوصيل
    ]);
  }

  // (بقية الدوال المساعدة _buildHeader, _buildCommissionCard, _buildDocumentsCard, _buildIdentityCard تبقى كما هي مع التأكد من استخدام الأسماء الصحيحة)

  Widget _buildHeader(Map<String, dynamic> data, bool isDesktop) {
    String? logo = data['logoUrl'] ?? data['merchantLogoUrl'];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          CircleAvatar(
            radius: isDesktop ? 40 : 30,
            backgroundImage: logo != null ? NetworkImage(logo) : null,
            child: logo == null ? const Icon(Icons.store, size: 30) : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_f(data['merchantName']), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text("المسؤول: ${_f(data['fullname'])}", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                _buildStatusChip(data['status']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionCard(Map<String, dynamic> data) {
    return _sectionCard("إعدادات العمولة", Icons.percent, Colors.green, [
      _staticRow("النوع", _translateCommissionType(data['commissionType'])),
      EditableInfoRow(label: "النسبة", value: _f(data['commissionRate']), field: "commissionRate", sellerId: sellerId, isNumber: true, suffix: " %"),
      EditableInfoRow(label: "المبلغ الثابت", value: _f(data['fixedCommission']), field: "fixedCommission", sellerId: sellerId, isNumber: true, suffix: " ج.م"),
    ]);
  }

  Widget _buildDocumentsCard(BuildContext context, Map<String, dynamic> data) {
    return _sectionCard("المستندات", Icons.folder_shared_outlined, Colors.redAccent, [
      _imageRow(context, "السجل التجاري", data['crUrl']),
      _imageRow(context, "البطاقة الضريبية", data['tcUrl']),
    ]);
  }

  Widget _buildIdentityCard(Map<String, dynamic> data) {
    return _sectionCard("بيانات التواصل", Icons.contact_phone_outlined, Colors.orange, [
      _staticRow("رقم الهاتف", _f(data['phone'])),
      _staticRow("هاتف إضافي", _f(data['additionalPhone'])),
      _staticRow("العنوان", _f(data['address'])),
    ]);
  }

  // الدوال المساعدة للرسم (UI Helpers)
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
        const SizedBox(width: 10),
        Expanded(child: Text(value, textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
      ]),
    );
  }

  Widget _imageRow(BuildContext context, String label, String? url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          url != null && url.isNotEmpty
              ? IconButton(icon: const Icon(Icons.remove_red_eye, color: Colors.blue), onPressed: () => _showFullImage(context, url))
              : const Text("غير مرفق", style: TextStyle(color: Colors.red, fontSize: 12)),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(context: context, builder: (_) => Dialog(child: Image.network(url)));
  }

  String _translateCommissionType(dynamic type) {
    if (type == "percentage") return "نسبة مئوية";
    if (type == "fixed") return "مبلغ ثابت";
    if (type == "both") return "نسبة + ثابت";
    return "غير محدد";
  }

  Widget _buildStatusChip(String? status) {
    bool isActive = status == 'active';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: isActive ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(isActive ? "نشط" : "قيد المراجعة", style: TextStyle(color: isActive ? Colors.green : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

// كلاس التعديل السريع (Inline Edit)
class EditableInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final String field;
  final String sellerId;
  final bool isNumber;
  final String suffix;

  const EditableInfoRow({super.key, required this.label, required this.value, required this.field, required this.sellerId, this.isNumber = false, this.suffix = ""});

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
        title: Text("تعديل $label"),
        content: TextField(
          controller: controller,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
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

