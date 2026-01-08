import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SellerDetailsPage extends StatelessWidget {
  final String sellerId;
  final Map<String, dynamic> sellerData;

  const SellerDetailsPage({super.key, required this.sellerId, required this.sellerData});

  // معالجة القيم الفارغة
  String _f(dynamic val) => (val == null || val.toString().isEmpty) ? "—" : val.toString();

  // دالة توليد الـ PDF الاحترافية
  Future<void> _generatePdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("Merchant Report: ${data['supermarketName']}", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text("Merchant ID: $sellerId"),
            pw.Text("Full Name: ${_f(data['fullname'])}"),
            pw.Text("Phone: ${_f(data['phone'])}"),
            pw.SizedBox(height: 20),
            pw.Text("Financial Summary", style: pw.TextStyle(fontSize: 18)),
            pw.Bullet(text: "Commission Rate: ${_f(data['commissionRate'])} %"),
            pw.Bullet(text: "Accrued Debt: ${_f(data['cashbackAccruedDebt'])} EGP"),
            pw.Bullet(text: "Realized Commission: ${_f(data['realizedCommission'])} EGP"),
            pw.SizedBox(height: 20),
            pw.Text("Banking Info", style: pw.TextStyle(fontSize: 18)),
            pw.Bullet(text: "Bank: ${_f(data['bankName'])}"),
            pw.Bullet(text: "IBAN: ${_f(data['iban'])}"),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    // تحديد عرض الشاشة لضبط التجاوب (Responsive)
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth > 900;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('sellers').doc(sellerId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.hasData ? snapshot.data!.data() as Map<String, dynamic> : sellerData;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: Text(_f(data['supermarketName']), style: const TextStyle(fontFamily: 'Cairo', fontSize: 18)),
            backgroundColor: const Color(0xFF1F2937),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: () => _generatePdf(data),
                tooltip: "تصدير التقرير",
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
                    
                    // استخدام الـ Grid في الشاشات الكبيرة والـ Column في الموبايل
                    isDesktop 
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildFinancialCard(data)),
                            const SizedBox(width: 20),
                            Expanded(child: _buildBankCard(data)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildFinancialCard(data),
                            const SizedBox(height: 16),
                            _buildBankCard(data),
                          ],
                        ),
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

  // --- Widgets البناء ---

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
            backgroundColor: Colors.blue.shade50,
            child: Icon(Icons.store, size: isDesktop ? 40 : 30, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_f(data['fullname']), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text("ID: $sellerId", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                const SizedBox(height: 8),
                _statusChip(_f(data['status'])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    bool active = status.toLowerCase() == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: active ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? "نشط" : "معطل",
        style: TextStyle(color: active ? Colors.green.shade700 : Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
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
    return _sectionCard("بيانات الهوية والنشاط", Icons.badge_outlined, Colors.orange, [
      _staticRow("رقم الهاتف", _f(data['phone'])),
      _staticRow("الرقم الضريبي", _f(data['taxNumber'])),
      _staticRow("العنوان", _f(data['address'])),
    ]);
  }

  Widget _sectionCard(String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold))]),
          const Divider(height: 24),
          ...children,
        ],
      ),
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

// ✅ ويدجت التعديل الذكية بداخل السطر (نفس الكلاس السابق مع تحسينات طفيفة)
class EditableInfoRow extends StatefulWidget {
  final String label;
  final String value;
  final String field;
  final String sellerId;
  final bool isNumber;
  final String suffix;

  const EditableInfoRow({super.key, required this.label, required this.value, required this.field, required this.sellerId, this.isNumber = false, this.suffix = ""});

  @override
  State<EditableInfoRow> createState() => _EditableInfoRowState();
}

class _EditableInfoRowState extends State<EditableInfoRow> {
  bool _editing = false;
  bool _loading = false;
  late TextEditingController _ctrl;

  @override
  void initState() { super.initState(); _ctrl = TextEditingController(text: widget.value == "—" ? "" : widget.value); }

  Future<void> _update() async {
    setState(() => _loading = true);
    try {
      dynamic v = _ctrl.text;
      if (widget.isNumber) v = double.tryParse(v) ?? 0.0;
      await FirebaseFirestore.instance.collection('sellers').doc(widget.sellerId).update({widget.field: v});
      setState(() { _editing = false; _loading = false; });
    } catch (e) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(widget.label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const Spacer(),
          _editing 
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 100, child: TextField(controller: _ctrl, style: const TextStyle(fontSize: 13), decoration: const InputDecoration(isDense: true))),
                IconButton(icon: const Icon(Icons.check, color: Colors.green, size: 18), onPressed: _update),
              ])
            : InkWell(
                onTap: () => setState(() => _editing = true),
                child: Row(children: [
                  _loading ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.edit_note, size: 18, color: Colors.blueGrey),
                  const SizedBox(width: 4),
                  Text("${widget.value}${widget.suffix}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
              ),
        ],
      ),
    );
  }
}

