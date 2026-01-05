import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SellersPage extends StatefulWidget {
  const SellersPage({super.key});

  @override
  State<SellersPage> createState() => _SellersPageState();
}

class _SellersPageState extends State<SellersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchPending = "";
  String _searchApproved = "";

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
            Tab(text: "تحت المراجعة", icon: Icon(Icons.hourglass_empty)),
            Tab(text: "المعتمدون", icon: Icon(Icons.verified_user)),
          ],
          indicatorColor: Colors.orange,
          labelStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          _buildApprovedTab(),
        ],
      ),
    );
  }

  // --- تبويب التجار تحت المراجعة ---
  Widget _buildPendingTab() {
    return Column(
      children: [
        _buildSearchBox((val) => setState(() => _searchPending = val), "بحث في الانتظار..."),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection("pendingSellers").snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              final docs = snapshot.data!.docs.where((doc) {
                final name = (doc['fullname'] ?? "").toString().toLowerCase();
                return name.contains(_searchPending.toLowerCase());
              }).toList();

              if (docs.isEmpty) return const Center(child: Text("لا توجد طلبات انضمام"));

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) => _buildSellerCard(docs[index], isPending: true),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- تبويب التجار المعتمدين ---
  Widget _buildApprovedTab() {
    return Column(
      children: [
        _buildSearchBox((val) => setState(() => _searchApproved = val), "بحث في المعتمدين..."),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection("sellers").snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              final docs = snapshot.data!.docs.where((doc) {
                final name = (doc['fullname'] ?? "").toString().toLowerCase();
                return name.contains(_searchApproved.toLowerCase());
              }).toList();

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) => _buildSellerCard(docs[index], isPending: false),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- تصميم الكارت الموحد للتاجر ---
  Widget _buildSellerCard(DocumentSnapshot doc, {required bool isPending}) {
    final data = doc.data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListTile(
        title: Text(data['fullname'] ?? "بدون اسم", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${data['phone']}\n${data['businessType'] ?? ''}"),
        isThreeLine: true,
        trailing: isPending 
          ? ElevatedButton(
              onPressed: () => _showReviewDialog(doc),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              child: const Text("مراجعة"),
            )
          : IconButton(
              icon: const Icon(Icons.settings, color: Colors.orange),
              onPressed: () => _showFinanceDialog(doc),
            ),
      ),
    );
  }

  // --- ديالوج مراجعة وقبول التاجر ---
  void _showReviewDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final commissionController = TextEditingController();
    final feeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("قبول التاجر: ${data['fullname']}"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow("النشاط:", data['businessType']),
              _buildDetailRow("السجل:", data['commercialRegistrationNumber']),
              const Divider(),
              TextField(
                controller: commissionController,
                decoration: const InputDecoration(labelText: "نسبة العمولة (%)", hintText: "مثال: 10"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: feeController,
                decoration: const InputDecoration(labelText: "رسوم شهرية (EGP)", hintText: "مثال: 100"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () => _approveSeller(doc, commissionController.text, feeController.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("موافقة وقبول"),
          ),
        ],
      ),
    );
  }

  // --- ديالوج تعديل الماليات للتجار المعتمدين ---
  void _showFinanceDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final commissionController = TextEditingController(text: data['commissionRate'].toString());
    final feeController = TextEditingController(text: data['monthlyFee'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تعديل البيانات المالية"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: commissionController, decoration: const InputDecoration(labelText: "العمولة (%)"), keyboardType: TextInputType.number),
            TextField(controller: feeController, decoration: const InputDecoration(labelText: "الرسوم الشهرية"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection("sellers").doc(doc.id).update({
                'commissionRate': double.tryParse(commissionController.text) ?? 0,
                'monthlyFee': double.tryParse(feeController.text) ?? 0,
              });
              Navigator.pop(context);
            },
            child: const Text("حفظ التعديلات"),
          ),
        ],
      ),
    );
  }

  // --- منطق نقل التاجر من الانتظار للمعتمدين ---
  Future<void> _approveSeller(DocumentSnapshot doc, String commission, String fee) async {
    final data = doc.data() as Map<String, dynamic>;
    final batch = FirebaseFirestore.instance.batch();

    final sellerRef = FirebaseFirestore.instance.collection("sellers").doc(doc.id);
    final pendingRef = FirebaseFirestore.instance.collection("pendingSellers").doc(doc.id);

    batch.set(sellerRef, {
      ...data,
      'status': 'active',
      'approvedAt': FieldValue.serverTimestamp(),
      'commissionRate': double.tryParse(commission) ?? 0,
      'monthlyFee': double.tryParse(fee) ?? 0,
    });

    batch.delete(pendingRef);

    await batch.commit();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم قبول التاجر بنجاح")));
  }

  // مكونات مساعدة للواجهة
  Widget _buildSearchBox(Function(String) onChanged, String hint) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value?.toString() ?? "غير متوفر")),
        ],
      ),
    );
  }
}

