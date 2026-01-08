import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/product_selector_sheet.dart';
import 'seller_details_page.dart'; // ✅ تأكد من إنشاء هذا الملف كما في الرد السابق

class SellersPage extends StatefulWidget {
  const SellersPage({super.key});

  @override
  State<SellersPage> createState() => _SellersPageState();
}

class _SellersPageState extends State<SellersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _commissionController = TextEditingController();
  
  // قائمة المنتجات المؤقتة ستحتوي على الوحدات المختارة
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
        title: const Text("إدارة التجار المركزية", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
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
            
            bool isPending = collectionName == "pendingSellers";

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              elevation: 1,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isPending ? Colors.orange : Colors.green,
                  child: Icon(isPending ? Icons.hourglass_top : Icons.verified, color: Colors.white),
                ),
                title: Text(data['supermarketName'] ?? data['fullname'] ?? "تاجر جديد", 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                subtitle: Text(data['phone'] ?? "بدون رقم هاتف"),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  if (isPending) {
                    // فتح ورقة المراجعة والاعتماد للتجار الجدد
                    _openReviewSheet(id, data);
                  } else {
                    // ✅ الانتقال لصفحة التفاصيل الشاملة للتجار المعتمدين
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SellerDetailsPage(sellerId: id, sellerData: data),
                      ),
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  // --- منطق اعتماد التاجر الجديد ---
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
                Text("تفعيل التاجر: ${data['fullname']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                const SizedBox(height: 15),
                TextField(
                  controller: _commissionController,
                  decoration: const InputDecoration(labelText: "العمولة %", border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const Divider(height: 30),
                ProductSelectorSheet(onProductAdded: (product) {
                  setModalState(() => _tempSelectedProducts.add(product));
                }),
                const SizedBox(height: 15),
                if (_tempSelectedProducts.isNotEmpty) ...[
                  const Align(alignment: Alignment.centerRight, child: Text("المنتجات والوحدات المضافة:", style: TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      children: _tempSelectedProducts.map((p) => ListTile(
                        dense: true,
                        title: Text("${p['productName']} (${p['unitName']})"),
                        subtitle: Text("السعر: ${p['price']} ج.م | الكمية: ${p['availableStock']}"),
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

  Future<void> _approveSeller(String id, Map<String, dynamic> data) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. إضافة التاجر لجدول المعتمدين
      batch.set(FirebaseFirestore.instance.collection('sellers').doc(id), {
        ...data,
        'status': 'active',
        'commissionRate': double.tryParse(_commissionController.text) ?? 0,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // 2. منطق التجميع (Grouping) للعروض
      Map<String, Map<String, dynamic>> groupedOffers = {};
      for (var prod in _tempSelectedProducts) {
        String pId = prod['productId'];
        if (!groupedOffers.containsKey(pId)) {
          groupedOffers[pId] = {
            'sellerId': id,
            'sellerName': data['fullname'],
            'productId': pId,
            'productName': prod['productName'],
            'mainCategoryId': prod['mainCategoryId'],
            'subCategoryId': prod['subCategoryId'],
            'imageUrl': prod['imageUrl'],
            'status': 'active',
            'updatedAt': FieldValue.serverTimestamp(),
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
        final offerRef = FirebaseFirestore.instance.collection('productOffers').doc("${id}_$pId");
        batch.set(offerRef, offerData);
      });

      // 3. الحذف من قائمة الانتظار
      batch.delete(FirebaseFirestore.instance.collection('pendingSellers').doc(id));

      await batch.commit();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم اعتماد التاجر وتجميع منتجاته بنجاح")));
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }
}

