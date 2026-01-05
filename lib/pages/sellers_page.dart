import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/product_selector_sheet.dart'; // تأكد من وجود الملف في هذا المسار

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
  void dispose() {
    _tabController.dispose();
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
        if (snapshot.hasError) return const Center(child: Text("حدث خطأ في التحميل"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("لا توجد بيانات حالياً"));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: collectionName == "pendingSellers" ? Colors.orange : Colors.green,
                  child: Icon(collectionName == "pendingSellers" ? Icons.hourglass_empty : Icons.check, color: Colors.white),
                ),
                title: Text(data['fullname'] ?? "تاجر جديد", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(data['phone'] ?? ""),
                trailing: const Icon(Icons.chevron_right),
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

  // --- نافذة اعتماد التاجر الجديد ---
  void _openReviewSheet(String docId, Map<String, dynamic> data) {
    _tempSelectedProducts = [];
    _commissionController.clear();
    
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
                Text("تفعيل التاجر: ${data['fullname']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                TextField(
                  controller: _commissionController,
                  decoration: const InputDecoration(labelText: "العمولة %", border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const Divider(height: 30),
                
                // المكون المنفصل لاختيار المنتجات
                ProductSelectorSheet(onProductAdded: (product) {
                  setModalState(() => _tempSelectedProducts.add(product));
                }),
                
                const SizedBox(height: 15),
                if (_tempSelectedProducts.isNotEmpty) ...[
                  const Align(alignment: Alignment.centerRight, child: Text("قائمة المنتجات المضافة:", style: TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      children: _tempSelectedProducts.map((p) => ListTile(
                        dense: true,
                        title: Text(p['productName']),
                        subtitle: Text("السعر: ${p['price']} ج.م"),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => setModalState(() => _tempSelectedProducts.remove(p)),
                        ),
                      )).toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _tempSelectedProducts.isEmpty ? null : () => _approveSeller(docId, data),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    child: const Text("موافقة نهائية وتفعيل الحساب"),
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

  // --- نافذة إدارة التاجر المعتمد (كما في HTML) ---
  void _openEditDialog(String id, Map<String, dynamic> data) {
    _commissionController.text = (data['commissionRate'] ?? 0).toString();
    String currentStatus = data['status'] ?? 'active';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("إدارة: ${data['fullname']}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _commissionController,
                decoration: const InputDecoration(labelText: "تعديل العمولة %", border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: currentStatus,
                decoration: const InputDecoration(labelText: "حالة الحساب", border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text("نشط")),
                  DropdownMenuItem(value: 'inactive', child: Text("غير نشط (إيقاف)")),
                ],
                onChanged: (val) => setDialogState(() => currentStatus = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: () async {
                final batch = FirebaseFirestore.instance.batch();
                final sellerRef = FirebaseFirestore.instance.collection('sellers').doc(id);

                // 1. تحديث بيانات التاجر
                batch.update(sellerRef, {
                  'commissionRate': double.tryParse(_commissionController.text) ?? 0,
                  'status': currentStatus,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                // 2. مزامنة الحالة مع المنتجات
                final offers = await FirebaseFirestore.instance.collection('productOffers').where('sellerId', isEqualTo: id).get();
                for (var doc in offers.docs) { batch.update(doc.reference, {'status': currentStatus}); }

                await batch.commit();
                if (mounted) Navigator.pop(context);
              },
              child: const Text("حفظ التغييرات"),
            ),
          ],
        ),
      ),
    );
  }

  // --- منطق الحفظ النهائي للاعتماد ---
  Future<void> _approveSeller(String id, Map<String, dynamic> data) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // 1. إضافة لجدول المعتمدين
      batch.set(FirebaseFirestore.instance.collection('sellers').doc(id), {
        ...data,
        'status': 'active',
        'commissionRate': double.tryParse(_commissionController.text) ?? 0,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // 2. إضافة عروض المنتجات المختارة
      for (var prod in _tempSelectedProducts) {
        final offerRef = FirebaseFirestore.instance.collection('productOffers').doc("${id}_${prod['productId']}");
        batch.set(offerRef, {
          'sellerId': id,
          'sellerName': data['fullname'],
          'productId': prod['productId'],
          'productName': prod['productName'],
          'price': prod['price'],
          'stock': prod['stock'],
          'imageUrl': prod['imageUrl'] ?? '',
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 3. الحذف من قائمة الانتظار
      batch.delete(FirebaseFirestore.instance.collection('pendingSellers').doc(id));

      await batch.commit();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم اعتماد التاجر وتفعيل منتجاته")));
      }
    } catch (e) {
      print("Error: $e");
    }
  }
}

