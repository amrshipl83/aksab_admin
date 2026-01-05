import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/product_selector_sheet.dart'; // استيراد المكون الجديد

class SellersPage extends StatefulWidget {
  const SellersPage({super.key});

  @override
  State<SellersPage> createState() => _SellersPageState();
}

class _SellersPageState extends State<SellersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _commissionController = TextEditingController();
  List<Map<String, dynamic>> _tempSelectedProducts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إدارة التجار", style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: "تحت المراجعة"), Tab(text: "المعتمدون")]),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSellersList("pendingSellers"),
          _buildSellersList("sellers"),
        ],
      ),
    );
  }

  Widget _buildSellersList(String collectionName) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collectionName).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;
            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                title: Text(data['fullname'] ?? "تاجر"),
                subtitle: Text(data['phone'] ?? ""),
                onTap: () => collectionName == "pendingSellers" 
                    ? _openReviewSheet(id, data) 
                    : _openEditDialog(id, data),
              ),
            );
          },
        );
      },
    );
  }

  void _openReviewSheet(String docId, Map<String, dynamic> data) {
    _tempSelectedProducts = [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("مراجعة: ${data['fullname']}"),
                TextField(controller: _commissionController, decoration: const InputDecoration(labelText: "العمولة %")),
                const Divider(),
                
                // استخدام المكون الذي فصلناه
                ProductSelectorSheet(onProductAdded: (product) {
                  setModalState(() => _tempSelectedProducts.add(product));
                }),
                
                const SizedBox(height: 10),
                const Text("المنتجات المضافة حالياً:"),
                ..._tempSelectedProducts.map((p) => ListTile(
                  title: Text(p['productName']),
                  trailing: Text("${p['price']} ج.م"),
                  leading: IconButton(icon: const Icon(Icons.delete, color: Colors.red), 
                  onPressed: () => setModalState(() => _tempSelectedProducts.remove(p))),
                )),

                ElevatedButton(
                  onPressed: _tempSelectedProducts.isEmpty ? null : () => _approveSeller(docId, data),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: const Text("اعتماد التاجر نهائياً"),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // منطق الحفظ (Batch Write) كما في الـ HTML
  Future<void> _approveSeller(String id, Map<String, dynamic> data) async {
    final batch = FirebaseFirestore.instance.batch();
    
    // 1. إضافة للتاجر المعتمد
    batch.set(FirebaseFirestore.instance.collection('sellers').doc(id), {
      ...data,
      'status': 'active',
      'commissionRate': double.tryParse(_commissionController.text) ?? 0,
      'approvedAt': FieldValue.serverTimestamp(),
    });

    // 2. إضافة العروض (Product Offers)
    for (var prod in _tempSelectedProducts) {
      final offerId = "${id}_${prod['productId']}";
      batch.set(FirebaseFirestore.instance.collection('productOffers').doc(offerId), {
        'sellerId': id,
        'sellerName': data['fullname'],
        'productId': prod['productId'],
        'productName': prod['productName'],
        'price': prod['price'],
        'stock': prod['stock'],
        'imageUrl': prod['imageUrl'],
        'status': 'active',
      });
    }

    // 3. حذف من قائمة الانتظار
    batch.delete(FirebaseFirestore.instance.collection('pendingSellers').doc(id));

    await batch.commit();
    Navigator.pop(context);
  }

  void _openEditDialog(String id, Map<String, dynamic> data) {
    // كود تعديل بيانات التاجر المعتمد...
  }
}

