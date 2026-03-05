import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // لتنسيق التاريخ

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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("قاعدة بيانات المستهلكين", style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundColor: Colors.yellowAccent,
              child: const Icon(Icons.people, color: Colors.black),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildConsumersList()),
        ],
      ),
    );
  }

  // شريط البحث
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchText = value),
        decoration: InputDecoration(
          hintText: "ابحث باسم المستهلك أو رقم الهاتف...",
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[100],
        ),
      ),
    );
  }

  // جلب البيانات من فايربيز
  Widget _buildConsumersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'consumer').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("حدث خطأ ما"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        var docs = snapshot.data!.docs.where((doc) {
          String name = doc['fullname'].toString().toLowerCase();
          String phone = doc['phone'].toString();
          return name.contains(_searchText.toLowerCase()) || phone.contains(_searchText);
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: docs.length,
          itemBuilder: (context, index) => _buildConsumerCard(docs[index]),
        );
      },
    );
  }

  // تصميم الكارت
  Widget _buildConsumerCard(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    bool isVerified = data['isVerified'] ?? false;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Colors.blueGrey[50],
          child: Text(data['fullname'][0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        title: Row(
          children: [
            Text(data['fullname'], style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
            const SizedBox(width: 8),
            if (isVerified) const Icon(Icons.verified, color: Colors.blue, size: 16),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['phone'] ?? "بدون رقم", style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 5),
            Wrap(
              spacing: 5,
              children: [
                _buildSmallBadge("${data['loyaltyPoints'] ?? 0} نقطة", Colors.orange),
                _buildSmallBadge("${data['cashbackBalance'] ?? 0} ج.م", Colors.green),
              ],
            )
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _showDetailsDialog(data),
      ),
    );
  }

  Widget _buildSmallBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  // نافذة التفاصيل المنبثقة
  void _showDetailsDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(child: Text(data['fullname'], style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold))),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoTile(Icons.email, "البريد الإلكتروني", data['email']),
              _infoTile(Icons.location_on, "العنوان", data['address']),
              _infoTile(Icons.calendar_today, "تاريخ الانضمام", _formatTimestamp(data['createdAt'])),
              _infoTile(Icons.map, "الإحداثيات", "${data['location']?['lat']}, ${data['location']?['lng']}"),
              _infoTile(Icons.card_giftcard, "هدية الترحيب", data['hasClaimedWelcomeGift'] == true ? "تم الاستلام" : "لم تستلم"),
              _infoTile(Icons.verified_user, "الحالة", data['status'] ?? "نشط"),
              const Divider(),
              const Text("تفاصيل المحفظة:", style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("نقاط الولاء: ${data['loyaltyPoints']}"),
                  Text("كاش باك: ${data['cashbackBalance'] ?? 0}"),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إغلاق")),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value?.toString() ?? "غير متوفر", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "غير معروف";
    DateTime date = (timestamp as Timestamp).toDate();
    return DateFormat('yyyy-MM-dd').format(date);
  }
}

