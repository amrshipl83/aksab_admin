import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/seller_review_sheet.dart'; // المنبثقة الجديدة
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

  // دالة ذكية لإحضار الاسم (التجاري أولاً)
  String _getBusinessName(Map<String, dynamic> data) {
    return data['merchantName'] ?? data['supermarketName'] ?? data['fullname'] ?? "تاجر جديد";
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

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isPending ? Colors.orange : Colors.green,
                  backgroundImage: data['merchantLogoUrl'] != null || data['logoUrl'] != null 
                      ? NetworkImage(data['merchantLogoUrl'] ?? data['logoUrl']) 
                      : null,
                  child: (data['merchantLogoUrl'] == null && data['logoUrl'] == null)
                      ? Icon(isPending ? Icons.hourglass_top : Icons.verified, color: Colors.white)
                      : null,
                ),
                title: Text(_getBusinessName(data),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14)),
                subtitle: Text("${data['businessType'] ?? 'نشاط تجاري'} | ${data['phone'] ?? 'بدون هاتف'}",
                    style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  if (isPending) {
                    // فتح صفحة المراجعة والاعتماد (الملف المنفصل)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SellerReviewSheet(docId: id, data: data),
                        fullscreenDialog: true,
                      ),
                    );
                  } else {
                    // الانتقال لصفحة التفاصيل الشاملة للمعتمدين
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

