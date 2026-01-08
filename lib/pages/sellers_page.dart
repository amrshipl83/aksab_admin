// lib/pages/sellers_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/seller_review_sheet.dart'; 
import 'seller_details_page.dart';

class SellersPage extends StatefulWidget {
  const SellersPage({super.key});

  @override
  State<SellersPage> createState() => _SellersPageState();
}

class _SellersPageState extends State<SellersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getBusinessName(Map<String, dynamic> data) {
    return data['merchantName'] ?? data['supermarketName'] ?? data['fullname'] ?? "تاجر جديد";
  }

  // دالة لتغيير الحالة في قاعدة البيانات
  Future<void> _toggleSellerStatus(String id, String currentStatus) async {
    String newStatus = (currentStatus == 'active') ? 'inactive' : 'active';
    await FirebaseFirestore.instance.collection('sellers').doc(id).update({
      'status': newStatus,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text("إدارة التجار المركزية",
            style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
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
            
            // قراءة حالة التاجر (نشط أو غير نشط)
            String currentStatus = data['status'] ?? 'active';
            bool isActive = currentStatus == 'active';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isPending ? Colors.orange : (isActive ? Colors.green : Colors.grey),
                  backgroundImage: data['merchantLogoUrl'] != null || data['logoUrl'] != null
                      ? NetworkImage(data['merchantLogoUrl'] ?? data['logoUrl'])
                      : null,
                  child: (data['merchantLogoUrl'] == null && data['logoUrl'] == null)
                      ? Icon(isPending ? Icons.hourglass_top : (isActive ? Icons.verified : Icons.block), color: Colors.white)
                      : null,
                ),
                title: Text(_getBusinessName(data),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14)),
                subtitle: Text("${data['businessType'] ?? 'نشاط تجاري'} | ${data['phone'] ?? 'بدون هاتف'}",
                    style: const TextStyle(fontSize: 12)),
                
                // --- التعديل هنا: إضافة زر التحكم في الحالة للمعتمدين فقط ---
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isPending) // يظهر فقط في تبويب المعتمدين
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: isActive,
                              activeColor: Colors.green,
                              onChanged: (value) => _toggleSellerStatus(id, currentStatus),
                            ),
                          ),
                          Text(isActive ? "نشط" : "متوقف", 
                            style: TextStyle(fontSize: 9, color: isActive ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
                onTap: () {
                  if (isPending) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SellerReviewSheet(docId: id, data: data),
                        fullscreenDialog: true,
                      ),
                    );
                  } else {
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
}

