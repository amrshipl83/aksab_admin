import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SellersPage extends StatefulWidget {
  const SellersPage({super.key});

  @override
  State<SellersPage> createState() => _SellersPageState();
}

class _SellersPageState extends State<SellersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = "";

  // متغيرات إدارة إضافة المنتجات (كما في الـ HTML)
  List<Map<String, dynamic>> _tempSelectedProducts = [];
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _commissionController = TextEditingController();
  
  // متغيرات المنسدلات
  String? _selectedMainCategory;
  String? _selectedSubCategory;
  String? _selectedProduct;

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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          tabs: const [
            Tab(text: "تحت المراجعة"),
            Tab(text: "المعتمدون"),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchField(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSellersList("pendingSellers"),
                _buildSellersList("sellers"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "بحث بالاسم أو الهاتف...",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        onChanged: (val) => setState(() => _searchTerm = val.toLowerCase()),
      ),
    );
  }

  Widget _buildSellersList(String collectionName) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collectionName).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("حدث خطأ في التحميل"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['fullname'] ?? "").toString().toLowerCase();
          return name.contains(_searchTerm);
        }).toList();

        if (docs.isEmpty) return const Center(child: Text("لا توجد بيانات"));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final String docId = docs[index].id;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                title: Text(data['fullname'] ?? "بدون اسم", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("الهاتف: ${data['phone'] ?? '-'}"),
                trailing: const Icon(Icons.edit_note, color: Color(0xFF1F2937)),
                onTap: () {
                  // تشغيل المنسدلة بناءً على نوع التبويب
                  if (collectionName == "pendingSellers") {
                    _openReviewBottomSheet(docId, data);
                  } else {
                    _openFinanceDialog(docId, data);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  // 1. منسدلة مراجعة التاجر (Pending)
  void _openReviewBottomSheet(String docId, Map<String, dynamic> data) {
    _tempSelectedProducts = []; // تصفير القائمة عند كل فتح جديد
    _commissionController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleInsets(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 20),
                Text("مراجعة: ${data['fullname']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                const Divider(),
                
                // الحقول المالية
                const Text("إعدادات العمولة:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TextField(
                  controller: _commissionController,
                  decoration: const InputDecoration(labelText: "نسبة العمولة %", border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                
                const SizedBox(height: 20),
                const Text("إضافة منتجات التاجر:", style: TextStyle(fontWeight: FontWeight.bold)),
                
                // محاكاة المنسدلات (Dropdowns)
                _buildProductSelector(setModalState),

                const SizedBox(height: 15),
                // قائمة المنتجات المضافة حالياً
                if (_tempSelectedProducts.isNotEmpty) ...[
                  const Text("المنتجات المختارة:", style: TextStyle(color: Colors.blueGrey, fontSize: 13)),
                  ..._tempSelectedProducts.map((p) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p['productName'], style: const TextStyle(fontSize: 14)),
                    subtitle: Text("السعر: ${p['price']} ج.م | المخزون: ${p['stock']}"),
                    trailing: IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => setModalState(() => _tempSelectedProducts.remove(p))),
                  )),
                ],

                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.all(15)),
                        onPressed: _tempSelectedProducts.isEmpty ? null : () => _handleApprove(docId, data),
                        child: const Text("موافقة وتفعيل التاجر", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () => _handleReject(docId),
                      child: const Text("رفض", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // واجهة اختيار المنتج داخل الـ BottomSheet
  Widget _buildProductSelector(StateSetter setModalState) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => _selectedProduct = v,
            decoration: const InputDecoration(hintText: "اسم المنتج (مثال: أرز)", isDense: true),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextField(controller: _priceController, decoration: const InputDecoration(hintText: "السعر", isDense: true), keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _stockController, decoration: const InputDecoration(hintText: "المخزون", isDense: true), keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {
              if (_selectedProduct != null && _priceController.text.isNotEmpty) {
                setModalState(() {
                  _tempSelectedProducts.add({
                    "productName": _selectedProduct,
                    "price": double.tryParse(_priceController.text) ?? 0,
                    "stock": int.tryParse(_stockController.text) ?? 0,
                  });
                  _priceController.clear();
                  _stockController.clear();
                });
              }
            },
            icon: const Icon(Icons.add),
            label: const Text("إضافة للقائمة"),
          )
        ],
      ),
    );
  }

  // 2. ديالوج تعديل الماليات (Approved)
  void _openFinanceDialog(String docId, Map<String, dynamic> data) {
    _commissionController.text = (data['commissionRate'] ?? 0).toString();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("تعديل: ${data['fullname']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _commissionController, decoration: const InputDecoration(labelText: "العمولة %"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('sellers').doc(docId).update({
                'commissionRate': double.tryParse(_commissionController.text) ?? 0,
              });
              Navigator.pop(context);
            },
            child: const Text("حفظ"),
          )
        ],
      ),
    );
  }

  // العمليات النهائية
  Future<void> _handleApprove(String id, Map<String, dynamic> data) async {
    final batch = FirebaseFirestore.instance.batch();
    
    // نقل للتاجر المعتمد
    batch.set(FirebaseFirestore.instance.collection('sellers').doc(id), {
      ...data,
      'status': 'active',
      'approvedAt': FieldValue.serverTimestamp(),
      'commissionRate': double.tryParse(_commissionController.text) ?? 0,
    });

    // إضافة عروض المنتجات
    for (var prod in _tempSelectedProducts) {
      final offerId = "${id}_${DateTime.now().microsecondsSinceEpoch}";
      batch.set(FirebaseFirestore.instance.collection('productOffers').doc(offerId), {
        'sellerId': id,
        'sellerName': data['fullname'],
        'productName': prod['productName'],
        'price': prod['price'],
        'stock': prod['stock'],
        'status': 'active',
      });
    }

    batch.delete(FirebaseFirestore.instance.collection('pendingSellers').doc(id));
    await batch.commit();
    Navigator.pop(context);
  }

  Future<void> _handleReject(String id) async {
    await FirebaseFirestore.instance.collection('pendingSellers').doc(id).delete();
    Navigator.pop(context);
  }
}

