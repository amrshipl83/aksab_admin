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

  // متغيرات لاختيار المنتجات في الـ Modal
  List<Map<String, dynamic>> selectedProducts = [];
  String? selectedMainCatId, selectedSubCatId, selectedProductId, selectedUnit;
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _commissionController = TextEditingController();
  final TextEditingController _monthlyFeeController = TextEditingController();

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
          tabs: const [
            Tab(text: "تحت المراجعة"),
            Tab(text: "المعتمدون"),
          ],
          labelStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
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
          hintText: "بحث باسم التاجر أو الهاتف...",
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onChanged: (val) => setState(() => _searchTerm = val.toLowerCase()),
      ),
    );
  }

  Widget _buildSellersList(String collectionName) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collectionName).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("حدث خطأ ما"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        var docs = snapshot.data!.docs.where((doc) {
          String name = (doc['fullname'] ?? "").toString().toLowerCase();
          return name.contains(_searchTerm);
        }).toList();

        if (docs.isEmpty) return const Center(child: Text("لا يوجد تجار"));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String docId = docs[index].id;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text(data['fullname'] ?? "بدون اسم", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("الهاتف: ${data['phone'] ?? '-'}"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => collectionName == "pendingSellers" 
                    ? _showReviewModal(docId, data) 
                    : _showFinanceModal(docId, data),
              ),
            );
          },
        );
      },
    );
  }

  // --- شاشة مراجعة التاجر وإضافة المنتجات (Pending) ---
  void _showReviewModal(String id, Map<String, dynamic> data) {
    selectedProducts = [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleInsets(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("مراجعة التاجر وإضافة المنتجات", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(),
                Text("التاجر: ${data['fullname']}"),
                const SizedBox(height: 15),
                // قسم الإعدادات المالية
                TextField(
                  controller: _commissionController,
                  decoration: const InputDecoration(labelText: "نسبة العمولة (%)", border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                // محاكي اختيار المنتجات (مبسط للموبايل)
                const Text("إضافة منتج مبدئي:", style: TextStyle(fontWeight: FontWeight.bold)),
                _buildSimpleProductForm(setModalState),
                
                const Divider(),
                const Text("المنتجات المختارة:"),
                ...selectedProducts.map((p) => ListTile(
                  title: Text(p['productName']),
                  subtitle: Text("السعر: ${p['price']} - الكمية: ${p['stock']}"),
                  trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), 
                  onPressed: () => setModalState(() => selectedProducts.remove(p))),
                )),
                
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        onPressed: selectedProducts.isEmpty ? null : () => _approveSeller(id, data),
                        child: const Text("موافقة وتفعيل"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _rejectSeller(id),
                        child: const Text("رفض التاجر"),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleProductForm(StateSetter setModalState) {
    // ملاحظة: هنا يجب استدعاء بيانات المجموعات من Firestore، سنضع حقول نصية للتبسيط
    return Column(
      children: [
        const SizedBox(height: 8),
        TextField(
          onChanged: (v) => selectedProductId = v,
          decoration: const InputDecoration(hintText: "اسم المنتج", isDense: true),
        ),
        Row(
          children: [
            Expanded(child: TextField(controller: _priceController, decoration: const InputDecoration(hintText: "السعر"), keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _stockController, decoration: const InputDecoration(hintText: "الكمية"), keyboardType: TextInputType.number)),
          ],
        ),
        ElevatedButton(
          onPressed: () {
            if (selectedProductId != null && _priceController.text.isNotEmpty) {
              setModalState(() {
                selectedProducts.add({
                  "productName": selectedProductId,
                  "price": double.tryParse(_priceController.text) ?? 0,
                  "stock": int.tryParse(_stockController.text) ?? 0,
                });
                _priceController.clear();
                _stockController.clear();
              });
            }
          }, 
          child: const Text("إضافة للقائمة")
        ),
      ],
    );
  }

  // --- شاشة تعديل ماليات التاجر (Approved) لتجنب الشاشة الرمادية ---
  void _showFinanceModal(String id, Map<String, dynamic> data) {
    _commissionController.text = (data['commissionRate'] ?? 0).toString();
    _monthlyFeeController.text = (data['monthlyFee'] ?? 0).toString();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("تعديل ماليات ${data['fullname']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _commissionController, decoration: const InputDecoration(labelText: "العمولة (%)"), keyboardType: TextInputType.number),
            TextField(controller: _monthlyFeeController, decoration: const InputDecoration(labelText: "الرسوم الشهرية"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('sellers').doc(id).update({
                'commissionRate': double.tryParse(_commissionController.text) ?? 0,
                'monthlyFee': double.tryParse(_monthlyFeeController.text) ?? 0,
              });
              Navigator.pop(context);
            }, 
            child: const Text("حفظ")
          ),
        ],
      ),
    );
  }

  // --- العمليات (Approve / Reject) ---
  Future<void> _approveSeller(String id, Map<String, dynamic> data) async {
    final batch = FirebaseFirestore.instance.batch();
    
    // 1. نقل للـ sellers
    batch.set(FirebaseFirestore.instance.collection('sellers').doc(id), {
      ...data,
      'status': 'active',
      'approvedAt': FieldValue.serverTimestamp(),
      'commissionRate': double.tryParse(_commissionController.text) ?? 0,
    });

    // 2. إضافة عروض المنتجات (Product Offers)
    for (var p in selectedProducts) {
      batch.set(FirebaseFirestore.instance.collection('productOffers').doc("${id}_${DateTime.now().millisecond}"), {
        'sellerId': id,
        'productName': p['productName'],
        'price': p['price'],
        'stock': p['stock'],
        'status': 'active',
      });
    }

    // 3. حذف من الانتظار
    batch.delete(FirebaseFirestore.instance.collection('pendingSellers').doc(id));

    await batch.commit();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تفعيل التاجر بنجاح")));
  }

  Future<void> _rejectSeller(String id) async {
    await FirebaseFirestore.instance.collection('pendingSellers').doc(id).delete();
    Navigator.pop(context);
  }
}

