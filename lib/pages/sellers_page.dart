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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إدارة التجار", style: TextStyle(fontFamily: 'Tajawal')),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
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
        if (snapshot.hasError) return Center(child: Text("خطأ: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        // فلترة البيانات بأمان
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['fullname'] ?? "").toString().toLowerCase();
          final phone = (data['phone'] ?? "").toString();
          return name.contains(_searchTerm) || phone.contains(_searchTerm);
        }).toList();

        if (docs.isEmpty) return const Center(child: Text("لا توجد بيانات حالياً"));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final String docId = docs[index].id;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFF1F2937), child: Icon(Icons.store, color: Colors.white)),
                title: Text(data['fullname'] ?? "تاجر غير مسمى"),
                subtitle: Text("هاتف: ${data['phone'] ?? '-'}"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // هنا نفتح الـ Modals التي صممناها سابقاً
                },
              ),
            );
          },
        );
      },
    );
  }
}

