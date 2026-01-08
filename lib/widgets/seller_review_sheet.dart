// lib/widgets/seller_review_sheet.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'product_selector_sheet.dart';

class SellerReviewSheet extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const SellerReviewSheet({super.key, required this.docId, required this.data});

  @override
  State<SellerReviewSheet> createState() => _SellerReviewSheetState();
}

class _SellerReviewSheetState extends State<SellerReviewSheet> {
  final TextEditingController _commissionRateController = TextEditingController();
  final TextEditingController _fixedCommissionController = TextEditingController();
  
  String _commissionType = "percentage"; // percentage, fixed, or both
  List<Map<String, dynamic>> _tempProducts = [];
  bool _isProcessing = false;

  String _f(dynamic val) => (val == null || val.toString().isEmpty) ? "غير متوفر" : val.toString();

  Future<void> _approve() async {
    setState(() => _isProcessing = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final sellerRef = FirebaseFirestore.instance.collection('sellers').doc(widget.docId);
      final pendingRef = FirebaseFirestore.instance.collection('pendingSellers').doc(widget.docId);

      // تجهيز بيانات العمولة
      double rate = double.tryParse(_commissionRateController.text) ?? 0;
      double fixed = double.tryParse(_fixedCommissionController.text) ?? 0;

      batch.set(sellerRef, {
        ...widget.data,
        'status': 'active',
        'commissionType': _commissionType,
        'commissionRate': rate,
        'fixedCommission': fixed,
        'approvedAt': FieldValue.serverTimestamp(),
        'isVerified': true,
      });

      // (منطق تجميع العروض يبقى كما هو في كودك الأصلي...)
      // ... (Grouping Logic) ...

      batch.delete(pendingRef);
      await batch.commit();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("مراجعة واعتماد المورد", style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.orange[800],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. عرض الشعار في الأعلى إذا وجد
            if (widget.data['logoUrl'] != null)
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(widget.data['logoUrl']),
                ),
              ),
            const SizedBox(height: 20),

            _buildCard("البيانات الأساسية", [
              _row("الاسم التجاري", widget.data['merchantName']),
              _row("نوع النشاط", widget.data['businessType']),
              _row("اسم المسؤول", widget.data['fullname']),
              _row("رقم الهاتف", widget.data['phone']),
              _row("العنوان", widget.data['address']),
            ]),

            // 2. قسم الوثائق الرسمية (الصور)
            _buildCard("الوثائق والمستندات", [
              _buildImagePreview("السجل التجاري", widget.data['crUrl']),
              _buildImagePreview("البطاقة الضريبية", widget.data['tcUrl']),
            ]),

            // 3. قسم إعدادات العمولة المطور
            _buildCard("إعدادات العمولة", [
              DropdownButtonFormField<String>(
                value: _commissionType,
                decoration: const InputDecoration(labelText: "نوع العمولة"),
                items: const [
                  DropdownMenuItem(value: "percentage", child: Text("نسبة مئوية فقط")),
                  DropdownMenuItem(value: "fixed", child: Text("مبلغ ثابت فقط")),
                  DropdownMenuItem(value: "both", child: Text("نسبة + مبلغ ثابت")),
                ],
                onChanged: (val) => setState(() => _commissionType = val!),
              ),
              const SizedBox(height: 15),
              if (_commissionType == "percentage" || _commissionType == "both")
                TextField(
                  controller: _commissionRateController,
                  decoration: const InputDecoration(labelText: "نسبة العمولة %", border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
              if (_commissionType == "both") const SizedBox(height: 10),
              if (_commissionType == "fixed" || _commissionType == "both")
                TextField(
                  controller: _fixedCommissionController,
                  decoration: const InputDecoration(labelText: "المبلغ الثابت (جنيه)", border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
            ]),

            const Divider(height: 40),
            ProductSelectorSheet(onProductAdded: (p) => setState(() => _tempProducts.add(p))),
            
            // زر التفعيل
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: _isProcessing ? null : _approve,
                child: Text(_isProcessing ? "جاري المعالجة..." : "تفعيل الحساب ونقل البيانات"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ودجت لعرض الصور مع إمكانية التكبير
  Widget _buildImagePreview(String label, String? url) {
    if (url == null || url.isEmpty) return _row(label, "غير متوفر");
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label:", style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          GestureDetector(
            onTap: () => _showFullScreenImage(url),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(url, height: 150, width: double.infinity, fit: BoxFit.cover),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(String url) {
    showDialog(context: context, builder: (_) => Dialog(child: Image.network(url)));
  }

  Widget _buildCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const Divider(),
            ...children
          ],
        ),
      ),
    );
  }

  Widget _row(String label, dynamic val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Expanded(child: Text(_f(val), style: const TextStyle(fontSize: 13))),
      ]),
    );
  }
}

