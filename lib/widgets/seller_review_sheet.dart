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

  /// دالة الموافقة المطابقة لمنطق الويب
  Future<void> _approve() async {
    setState(() => _isProcessing = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final String sellerId = widget.docId;

      // مراجع المستندات
      final sellerRef = FirebaseFirestore.instance.collection('sellers').doc(sellerId);
      final pendingRef = FirebaseFirestore.instance.collection('pendingSellers').doc(sellerId);
      final notificationRef = FirebaseFirestore.instance.collection('notifications').doc();

      // تجهيز بيانات العمولة والرسوم (باستخدام نفس مسميات كود الويب)
      double rate = double.tryParse(_commissionRateController.text) ?? 0;
      double monthlyFee = double.tryParse(_fixedCommissionController.text) ?? 0;

      // 1. نقل التاجر إلى مجموعة المعتمدين 'sellers'
      batch.set(sellerRef, {
        ...widget.data,
        'status': 'active',
        'commissionType': _commissionType,
        'commissionRate': rate,      // مطابق للويب
        'monthlyFee': monthlyFee,    // مطابق للويب
        'approvedAt': FieldValue.serverTimestamp(),
        'isVerified': true,
      });

      // 2. توزيع العروض على مجموعة 'productOffers' (نفس منطق الويب)
      for (var offer in _tempProducts) {
        // معرف العرض: sellerId_productId لضمان عدم التكرار
        final String offerId = "${sellerId}_${offer['productId']}";
        final offerRef = FirebaseFirestore.instance.collection('productOffers').doc(offerId);

        batch.set(offerRef, {
          'sellerId': sellerId,
          'sellerName': widget.data['merchantName'] ?? widget.data['fullname'] ?? "تاجر",
          'productId': offer['productId'],
          'productName': offer['productName'],
          'mainCategoryId': offer['mainCategoryId'],
          'mainCategoryName': offer['mainCategoryName'],
          'subCategoryId': offer['subCategoryId'],
          'subCategoryName': offer['subCategoryName'],
          'status': 'active',
          'updatedAt': FieldValue.serverTimestamp(),
          'units': offer['units'], // مصفوفة الوحدات والأسعار والكميات
          'imageUrl': offer['imageUrl'] ?? '',
        });
      }

      // 3. إضافة إشعار ترحيبي للتاجر
      batch.set(notificationRef, {
        'userId': sellerId,
        'title': 'تم تفعيل حسابك بنجاح',
        'message': 'مبروك! يمكنك الآن استقبال الطلبات وإدارة عروضك من خلال التطبيق.',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'activation'
      });

      // 4. حذف طلب التسجيل من مجموعة 'pendingSellers'
      batch.delete(pendingRef);

      // تنفيذ جميع العمليات معاً
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تفعيل الحساب ونشر العروض بنجاح')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء التفعيل: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("مراجعة واعتماد المورد", style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. عرض الشعار
            if (widget.data['logoUrl'] != null || widget.data['merchantLogoUrl'] != null)
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(widget.data['logoUrl'] ?? widget.data['merchantLogoUrl']),
                ),
              ),
            const SizedBox(height: 20),

            // 2. البيانات الأساسية
            _buildCard("البيانات الأساسية", [
              _row("الاسم التجاري", widget.data['merchantName']),
              _row("نوع النشاط", widget.data['businessType']),
              _row("اسم المسؤول", widget.data['fullname']),
              _row("رقم الهاتف", widget.data['phone']),
              _row("العنوان", widget.data['address'] ?? widget.data['fullAddress']),
            ]),

            // 3. الوثائق
            _buildCard("الوثائق والمستندات", [
              _buildImagePreview("السجل التجاري", widget.data['crUrl']),
              _buildImagePreview("البطاقة الضريبية", widget.data['tcUrl']),
            ]),

            // 4. إعدادات العمولة
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
                  decoration: const InputDecoration(labelText: "المبلغ الثابت / الرسوم (جنيه)", border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
            ]),

            const Divider(height: 40),

            // 5. منسدلة العروض والمنتجات
            _buildCard("إضافة العروض الأولية", [
              ProductSelectorSheet(onProductAdded: (p) => setState(() => _tempProducts.add(p))),
              if (_tempProducts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text("تم اختيار ${_tempProducts.length} عرض", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ),
            ]),

            const SizedBox(height: 20),

            // زر التفعيل النهائي
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: _isProcessing ? null : _approve,
                child: Text(
                  _isProcessing ? "جاري المعالجة..." : "تفعيل الحساب ونقل البيانات",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- الودجت المساعدة (Helper Widgets) ---

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 15)),
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
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Text(_f(val), style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

