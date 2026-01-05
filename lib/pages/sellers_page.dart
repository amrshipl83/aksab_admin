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
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _commissionController = TextEditingController();
  
  String _searchTerm = "";
  List<Map<String, dynamic>> _tempSelectedProducts = [];
  String? _selectedProductName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
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
          hintText: "بحث بالاسم...",
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
        if (snapshot.hasError) return const Center(child: Text("خطأ في الاتصال"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['fullname'] ?? "").toString().toLowerCase();
          return name.contains(_searchTerm);
        }).toList();

        if (docs.isEmpty) return const Center(child: Text("لا توجد سجلات"));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final String docId = docs[index].id;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text(data['fullname'] ?? "تاجر جديد"),
                subtitle: Text(data['phone'] ?? ""),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => collectionName == "pendingSellers" 
                    ? _openReviewBottomSheet(docId, data) 
                    : _openFinanceDialog(docId, data),
              ),
            );
          },
        );
      },
    );
  }

  void _openReviewBottomSheet(String docId, Map<String, dynamic> data) {
    _tempSelectedProducts = [];
    _commissionController.clear();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("تفعيل التاجر: ${data['fullname']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const Divider(),
                TextField(controller: _commissionController, decoration: const InputDecoration(labelText: "العمولة %"), keyboardType: TextInputType.number),
                const SizedBox(height: 15),
                const Text("إضافة منتجات التاجر:", style: TextStyle(color: Colors.blueGrey)),
                TextField(onChanged: (v) => _selectedProductName = v, decoration: const InputDecoration(hintText: "اسم المنتج")),
                Row(children: [
                  Expanded(child: TextField(controller: _priceController, decoration: const InputDecoration(hintText: "السعر"), keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _stockController, decoration: const InputDecoration(hintText: "الكمية"), keyboardType: TextInputType.number)),
                ]),
                ElevatedButton.icon(
                  onPressed: () {
                    if (_selectedProductName != null && _priceController.text.isNotEmpty) {
                      setModalState(() {
                        _tempSelectedProducts.add({
                          "productName": _selectedProductName,
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
                ),
                ..._tempSelectedProducts.map((p) => ListTile(title: Text(p['productName']), subtitle: Text("${p['price']} ج.م"))),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: _tempSelectedProducts.isEmpty ? null : () => _handleApprove(docId, data),
                    child: const Text("موافقة نهائية وتفعيل"),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openFinanceDialog(String docId, Map<String, dynamic> data) {
    _commissionController.text = (data['commissionRate'] ?? 0).toString();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تعديل البيانات المالية"),
        content: TextField(controller: _commissionController, decoration: const InputDecoration(labelText: "العمولة %"), keyboardType: TextInputType.number),
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
          ),
        ],
      ),
    );
  }

  Future<void> _handleApprove(String id, Map<String, dynamic> data) async {
    final batch = FirebaseFirestore.instance.batch();
    
    // 1. إضافة لجدول المعتمدين
    batch.set(FirebaseFirestore.instance.collection('sellers').doc(id), {
      ...data,
      'status': 'active',
      'approvedAt': FieldValue.serverTimestamp(),
      'commissionRate': double.tryParse(_commissionController.text) ?? 0,
    });

    // 2. إضافة المنتجات
    for (var prod in _tempSelectedProducts) {
      final offerRef = FirebaseFirestore.instance.collection('productOffers').doc();
      batch.set(offerRef, {
        'sellerId': id,
        'productName': prod['productName'],
        'price': prod['price'],
        'stock': prod['stock'],
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // 3. حذف من قائمة الانتظار
    batch.delete(FirebaseFirestore.instance.collection('pendingSellers').doc(id));

    await batch.commit();
    Navigator.pop(context); // إغلاق الـ BottomSheet
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تفعيل التاجر ونقل بياناته بنجاح")));
  }
}

