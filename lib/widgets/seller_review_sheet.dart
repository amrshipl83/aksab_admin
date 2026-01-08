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
  final TextEditingController _commissionController = TextEditingController();
  List<Map<String, dynamic>> _tempProducts = [];
  bool _isProcessing = false;

  String _f(dynamic val) => (val == null || val.toString().isEmpty) ? "غير متوفر" : val.toString();

  Future<void> _approve() async {
    if (_commissionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى تحديد نسبة العمولة")));
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final sellerRef = FirebaseFirestore.instance.collection('sellers').doc(widget.docId);
      final pendingRef = FirebaseFirestore.instance.collection('pendingSellers').doc(widget.docId);

      // 1. نقل التاجر مع كافة الحقول الجديدة (مصدر الحقيقة)
      batch.set(sellerRef, {
        ...widget.data,
        'status': 'active',
        'commissionRate': double.tryParse(_commissionController.text) ?? 0,
        'approvedAt': FieldValue.serverTimestamp(),
        'isVerified': true,
      });

      // 2. تجميع العروض (Grouping)
      Map<String, Map<String, dynamic>> groupedOffers = {};
      for (var prod in _tempProducts) {
        String pId = prod['productId'];
        if (!groupedOffers.containsKey(pId)) {
          groupedOffers[pId] = {
            'sellerId': widget.docId,
            'sellerName': widget.data['merchantName'] ?? widget.data['fullname'],
            'productId': pId,
            'productName': prod['productName'],
            'mainCategoryId': prod['mainCategoryId'],
            'subCategoryId': prod['subCategoryId'],
            'imageUrl': prod['imageUrl'],
            'status': 'active',
            'units': []
          };
        }
        (groupedOffers[pId]!['units'] as List).add({
          'unitName': prod['unitName'],
          'price': prod['price'],
          'availableStock': prod['availableStock'],
        });
      }

      groupedOffers.forEach((pId, offerData) {
        final offerRef = FirebaseFirestore.instance.collection('productOffers').doc("${widget.docId}_$pId");
        batch.set(offerRef, offerData);
      });

      // 3. الحذف من قائمة الانتظار
      batch.delete(pendingRef);

      await batch.commit();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ تم اعتماد التاجر وتفعيل حسابه")));
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      debugPrint("Error approving seller: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("مراجعة بيانات الانضمام", style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.orange[800],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildCard("البيانات التجارية", [
              _row("الاسم التجاري", widget.data['merchantName']),
              _row("نوع النشاط", widget.data['businessType']),
              _row("اسم المسؤول", widget.data['fullname']),
            ]),
            _buildCard("بيانات التواصل", [
              _row("رقم الهاتف", widget.data['phone']),
              _row("هاتف إضافي", widget.data['additionalPhone']),
              _row("العنوان", widget.data['address']),
            ]),
            const SizedBox(height: 20),
            TextField(
              controller: _commissionController,
              decoration: const InputDecoration(
                labelText: "تحديد نسبة العمولة للنشاط %",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.percent),
              ),
              keyboardType: TextInputType.number,
            ),
            const Divider(height: 40),
            ProductSelectorSheet(onProductAdded: (p) => setState(() => _tempProducts.add(p))),
            const SizedBox(height: 10),
            ..._tempProducts.map((p) => ListTile(
              title: Text("${p['productName']} - ${p['unitName']}"),
              trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => setState(() => _tempProducts.remove(p))),
            )),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: _isProcessing ? null : _approve,
                child: _isProcessing 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("تفعيل الحساب ونقل البيانات", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, List<Widget> rows) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const Divider(),
            ...rows
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

