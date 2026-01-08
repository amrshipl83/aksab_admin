import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;

class SellerDetailsPage extends StatelessWidget {
  final String sellerId;
  final Map<String, dynamic> sellerData;

  const SellerDetailsPage({super.key, required this.sellerId, required this.sellerData});

  String _f(dynamic val) => (val == null || val.toString().isEmpty) ? "—" : val.toString();

  // --- دالة تصدير PDF احترافية ---
  Future<void> _exportToPdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    
    // تحميل الخط العربي لدعم الكتابة بشكل صحيح
    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        textDirection: pw.TextDirection.rtl, // دعم العربية من اليمين لليسار
        build: (pw.Context context) => [
          // رأس الصفحة (Header)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("منصة أكسب - تقرير مورد", style: pw.TextStyle(fontSize: 24, color: PdfColors.blue900, fontWeight: pw.FontWeight.bold)),
                  pw.Text("تاريخ التقرير: ${intl.DateFormat('yyyy-MM-dd').format(DateTime.now())}"),
                ],
              ),
              pw.Container(
                height: 60,
                width: 60,
                decoration: const pw.BoxDecoration(color: PdfColors.amber, shape: pw.BoxShape.circle),
                child: pw.Center(child: pw.Text("AK", style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold))),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Divider(thickness: 2, color: PdfColors.blueGrey),
          pw.SizedBox(height: 20),

          // قسم البيانات الأساسية (جدول)
          _pdfSectionTitle("البيانات الأساسية التجارية", boldFont),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            data: [
              ['الحقل', 'القيمة'],
              ['اسم المتجر/المورد', _f(data['merchantName'])],
              ['اسم المسؤول', _f(data['fullname'])],
              ['نوع النشاط', _f(data['businessType'])],
              ['رقم الهاتف', _f(data['phone'])],
              ['العنوان', _f(data['address'])],
            ],
          ),
          pw.SizedBox(height: 20),

          // قسم البيانات المالية
          _pdfSectionTitle("المؤشرات المالية وإعدادات العمولة", boldFont),
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
            data: [
              ['الحقل', 'القيمة'],
              ['نوع العمولة', _translateCommissionType(data['commissionType'])],
              ['نسبة العمولة', "${_f(data['commissionRate'])} %"],
              ['العمولة الثابتة', "${_f(data['fixedCommission'])} ج.م"],
              ['دين الكاش باك المستحق', "${_f(data['cashbackAccruedDebt'])} ج.م"],
              ['رصيد المنصة الحالي', "${_f(data['cashbackPlatformCredit'])} ج.م"],
            ],
          ),
          pw.SizedBox(height: 20),

          // تذييل الصفحة
          pw.Divider(),
          pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text("توقيع الإدارة المختصة: ________________", style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  pw.Widget _pdfSectionTitle(String title, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(title, style: pw.TextStyle(font: font, fontSize: 16, color: PdfColors.blue900)),
    );
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
          backgroundColor: const Color(0xFFF3F4F6),
          appBar: AppBar(
            title: Text(_f(data['merchantName'] ?? data['fullname']), style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: const Color(0xFF1F2937),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.orange),
                onPressed: () => _exportToPdf(data),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildHeader(data, isDesktop),
                const SizedBox(height: 20),
                _buildFinancialSummaryCard(data),
                const SizedBox(height: 16),
                _buildOperationsCard(data),
                const SizedBox(height: 16),
                _buildCommissionCard(data),
                const SizedBox(height: 16),
                _buildDocumentsCard(context, data),
                const SizedBox(height: 16),
                _buildIdentityCard(data),
              ],
            ),
          ),
        );
      },
    );
  }

  // (باقي دوال الـ UI: _buildHeader, _buildFinancialSummaryCard إلخ، بنفس المنطق السابق المعتمد)
  // ... [يتم استخدام نفس الدوال من الكود السابق لضمان الثبات]
  
  Widget _buildFinancialSummaryCard(Map<String, dynamic> data) {
    return _sectionCard("المؤشرات المالية المتقدمة", Icons.analytics, Colors.blueGrey, [
      Row(children: [
        Expanded(child: _staticRow("عمولة محققة", "${_f(data['realizedCommission'])} ج.م")),
        const SizedBox(width: 10),
        Expanded(child: _staticRow("عمولة معلقة", "${_f(data['unrealizedCommission'])} ج.م")),
      ]),
      const Divider(),
      EditableInfoRow(label: "دين الكاش باك", value: _f(data['cashbackAccruedDebt']), field: "cashbackAccruedDebt", sellerId: sellerId, isNumber: true, suffix: " ج.م"),
      EditableInfoRow(label: "رصيد المنصة", value: _f(data['cashbackPlatformCredit']), field: "cashbackPlatformCredit", sellerId: sellerId, isNumber: true, suffix: " ج.م"),
    ]);
  }

  Widget _buildOperationsCard(Map<String, dynamic> data) {
    return _sectionCard("التشغيل والتوصيل", Icons.local_shipping, Colors.deepPurple, [
      EditableInfoRow(label: "رسوم التوصيل", value: _f(data['deliveryFee']), field: "deliveryFee", sellerId: sellerId, isNumber: true, suffix: " ج.م"),
      EditableInfoRow(label: "أقل طلب", value: _f(data['minOrderTotal']), field: "minOrderTotal", sellerId: sellerId, isNumber: true, suffix: " ج.م"),
      _staticRow("مناطق التوصيل", _f(data['deliveryAreas'])),
    ]);
  }

  Widget _buildHeader(Map<String, dynamic> data, bool isDesktop) {
    String? logo = data['logoUrl'] ?? data['merchantLogoUrl'];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Row(children: [
        CircleAvatar(radius: 35, backgroundImage: logo != null ? NetworkImage(logo) : null, child: logo == null ? const Icon(Icons.store) : null),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_f(data['merchantName']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text("معرف المورد: $sellerId", style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ])),
      ]),
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
    return _sectionCard("المستندات", Icons.folder, Colors.red, [
      _imageRow(context, "السجل التجاري", data['crUrl']),
      _imageRow(context, "البطاقة الضريبية", data['tcUrl']),
    ]);
  }

  Widget _buildIdentityCard(Map<String, dynamic> data) {
    return _sectionCard("الهوية", Icons.person, Colors.orange, [
      _staticRow("المسؤول", _f(data['fullname'])),
      _staticRow("الهاتف", _f(data['phone'])),
      _staticRow("العنوان", _f(data['address'])),
    ]);
  }

  Widget _sectionCard(String title, IconData icon, Color color, List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(padding: const EdgeInsets.all(15), child: Column(children: [
        Row(children: [Icon(icon, color: color), const SizedBox(width: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.bold))]),
        const Divider(),
        ...children
      ])),
    );
  }

  Widget _staticRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    ]));
  }

  Widget _imageRow(BuildContext context, String label, String? url) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label),
      url != null ? IconButton(icon: const Icon(Icons.visibility, color: Colors.blue), onPressed: () => showDialog(context: context, builder: (_) => Dialog(child: Image.network(url)))) : const Text("لا يوجد"),
    ]);
  }

  String _translateCommissionType(dynamic type) {
    if (type == "percentage") return "نسبة مئوية";
    if (type == "fixed") return "مبلغ ثابت";
    if (type == "both") return "نسبة + ثابت";
    return "غير محدد";
  }
}

class EditableInfoRow extends StatelessWidget {
  final String label, value, field, sellerId, suffix;
  final bool isNumber;
  const EditableInfoRow({super.key, required this.label, required this.value, required this.field, required this.sellerId, this.isNumber = false, this.suffix = ""});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        InkWell(
          onTap: () {
            final ctrl = TextEditingController(text: value == "—" ? "" : value);
            showDialog(context: context, builder: (ctx) => AlertDialog(
              title: Text("تعديل $label"),
              content: TextField(controller: ctrl, keyboardType: isNumber ? TextInputType.number : TextInputType.text),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
                ElevatedButton(onPressed: () async {
                  await FirebaseFirestore.instance.collection('sellers').doc(sellerId).update({field: isNumber ? (double.tryParse(ctrl.text) ?? 0.0) : ctrl.text});
                  Navigator.pop(ctx);
                }, child: const Text("حفظ")),
              ],
            ));
          },
          child: Text("$value$suffix", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

