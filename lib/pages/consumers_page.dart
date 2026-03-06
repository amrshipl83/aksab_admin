import 'dart:io' show File; // استخدام مقيد لتجنب مشاكل الويب
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ConsumersPage extends StatefulWidget {
  const ConsumersPage({super.key});

  @override
  State<ConsumersPage> createState() => _ConsumersPageState();
}

class _ConsumersPageState extends State<ConsumersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";

  // 1. وظيفة تصدير البيانات للاكسيل (تدعم ويب وموبايل)
  Future<void> _exportToExcel() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      var query = await FirebaseFirestore.instance.collection('consumers').get();
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];

      // العناوين
      sheetObject.appendRow([
        TextCellValue("الاسم"),
        TextCellValue("الهاتف"),
        TextCellValue("البريد"),
        TextCellValue("نقاط الولاء"),
        TextCellValue("كاش باك"),
        TextCellValue("العنوان"),
        TextCellValue("تاريخ الانضمام"),
      ]);

      // تعبئة البيانات
      for (var doc in query.docs) {
        var data = doc.data();
        sheetObject.appendRow([
          TextCellValue(data['fullname']?.toString() ?? ""),
          TextCellValue(data['phone']?.toString() ?? ""),
          TextCellValue(data['email']?.toString() ?? ""),
          IntCellValue((data['loyaltyPoints'] ?? 0)),
          DoubleCellValue((data['cashbackBalance'] ?? 0).toDouble()),
          TextCellValue(data['address']?.toString() ?? ""),
          TextCellValue(data['createdAt'] != null 
              ? (data['createdAt'] as Timestamp).toDate().toString() 
              : ""),
        ]);
      }

      var fileBytes = excel.save();
      
      if (mounted) Navigator.pop(context); // إخفاء لودينج

      if (kIsWeb) {
        // للويب: تحميل مباشر من المتصفح
        excel.downloadExcel(fileName: "Aksab_Consumers.xlsx");
      } else {
        // للموبايل: حفظ ثم مشاركة
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/Aksab_Consumers.xlsx';
        final file = File(filePath);
        await file.writeAsBytes(fileBytes!);
        await Share.shareXFiles([XFile(filePath)], text: 'تقرير المستهلكين');
      }

    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ في التصدير: $e")));
    }
  }

  // 2. وظيفة الحذف الآمن
  Future<void> _handleDelete(String docId, String name) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("تأكيد الحذف", textAlign: TextAlign.right),
        content: Text("هل أنت متأكد من حذف ($name)؟", textAlign: TextAlign.right),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("حذف", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('consumers').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الحذف بنجاح")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        title: const Text("بيانات المستهلكين", 
          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined), 
            onPressed: _exportToExcel,
            tooltip: "تصدير Excel",
          ),
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

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchText = v),
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          hintText: "ابحث بالاسم أو الموبايل...",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: const Color(0xFFF2F4F8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildConsumersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('consumers').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("حدث خطأ"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        var docs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String name = (data['fullname'] ?? "").toString().toLowerCase();
          String phone = (data['phone'] ?? "").toString();
          return name.contains(_searchText.toLowerCase()) || phone.contains(_searchText);
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) => _buildConsumerCard(docs[index]),
        );
      },
    );
  }

  Widget _buildConsumerCard(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    String name = data['fullname'] ?? "بدون اسم";

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        onTap: () => _showDetailsDialog(data), 
        leading: IconButton(
          icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
          onPressed: () => _handleDelete(doc.id, name),
        ),
        title: Text(name, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(data['phone'] ?? "", textAlign: TextAlign.right),
        trailing: CircleAvatar(
          backgroundColor: Colors.blueGrey[50],
          child: Text(name.isNotEmpty ? name[0] : "?"),
        ),
      ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(child: Text(value?.toString() ?? "لا يوجد", textAlign: TextAlign.right)),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(width: 10),
          Icon(icon, size: 18, color: const Color(0xFF1F2937)),
        ],
      ),
    );
  }
}
