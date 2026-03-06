import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ConsumersPage extends StatefulWidget {
  const ConsumersPage({super.key});

  @override
  State<ConsumersPage> createState() => _ConsumersPageState();
}

class _ConsumersPageState extends State<ConsumersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        title: const Text("قاعدة بيانات المستهلكين", 
          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildConsumersList()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchText = value),
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          hintText: "...ابحث بالاسم أو رقم الهاتف",
          prefixIcon: const Icon(Icons.search, color: Color(0xFF1F2937)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          filled: true,
          fillColor: const Color(0xFFF2F4F8),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildConsumersList() {
    return StreamBuilder<QuerySnapshot>(
      // تم التعديل للمسار الصحيح 'consumers' بناءً على صورة الـ Firebase
      stream: FirebaseFirestore.instance.collection('consumers').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("حدث خطأ في جلب البيانات"));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF1F2937)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("لا توجد بيانات مستهلكين حالياً"));
        }

        // تصفية النتائج بناءً على البحث
        var docs = snapshot.data!.docs.where((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String name = (data['fullname'] ?? "").toString().toLowerCase();
          String phone = (data['phone'] ?? "").toString();
          return name.contains(_searchText.toLowerCase()) || phone.contains(_searchText);
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: docs.length,
          itemBuilder: (context, index) => _buildConsumerCard(docs[index]),
        );
      },
    );
  }

  Widget _buildConsumerCard(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // استخراج القيم مع حماية ضد الـ Null
    String name = data['fullname'] ?? "بدون اسم";
    String phone = data['phone'] ?? "لا يوجد هاتف";
    // دمج نقاط الولاء مع النقاط العادية كما تظهر في الـ Firebase عندك
    int points = (data['loyaltyPoints'] ?? 0) + (data['points'] ?? 0);
    double cashback = (data['cashbackBalance'] ?? 0).toDouble();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () => _showDetailsDialog(data),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              const Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Tajawal')),
                  const SizedBox(height: 4),
                  Text(phone, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildMiniTag("$points نقطة", Colors.orangeAccent),
                      const SizedBox(width: 8),
                      _buildMiniTag("$cashback ج.م", Colors.greenAccent),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 15),
              CircleAvatar(
                radius: 25,
                backgroundColor: const Color(0xFF1F2937).withOpacity(0.1),
                child: Text(name.isNotEmpty ? name[0] : "?", 
                  style: const TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: color.withAlpha(255), fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  void _showDetailsDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF1F2937),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Center(
                child: Text(data['fullname'] ?? "التفاصيل", 
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _detailRow(Icons.phone, "رقم الهاتف", data['phone']),
                  _detailRow(Icons.email, "البريد", data['email']),
                  _detailRow(Icons.location_on, "العنوان", data['address']),
                  _detailRow(Icons.star, "نقاط الولاء", data['loyaltyPoints']),
                  _detailRow(Icons.account_balance_wallet, "كاش باك", data['cashbackBalance']),
                  _detailRow(Icons.verified, "حالة التوثيق", data['isVerified'] == true ? "موثق" : "غير موثق"),
                  _detailRow(Icons.access_time, "تاريخ التسجيل", _formatTimestamp(data['createdAt'])),
                ],
              ),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إغلاق")),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Text(value?.toString() ?? "لا يوجد", 
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(width: 10),
          Icon(icon, size: 18, color: const Color(0xFF1F2937)),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "غير متوفر";
    if (timestamp is Timestamp) {
      return DateFormat('yyyy/MM/dd HH:mm').format(timestamp.toDate());
    }
    return timestamp.toString();
  }
}
