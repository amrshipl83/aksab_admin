import 'dart:io';
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

  // 1. وظيفة تصدير البيانات للاكسيل
  Future<void> _exportToExcel() async {
    try {
      // إظهار مؤشر تحميل
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

      // إضافة البيانات
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

      // حفظ ومشاركة
      var fileBytes = excel.save();
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/Aksab_Consumers.xlsx')
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes!);

      if (mounted) Navigator.pop(context); // إخفاء التحميل

      await Share.shareXFiles([XFile(file.path)], text: 'تقرير المستهلكين - تطبيق أكسب');

    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ في التصدير: $e")));
    }
  }

  // 2. وظيفة الحذف الآمن (طلب جوجل بلاي)
  Future<void> _handleDelete(String docId, String name) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد الحذف", textAlign: TextAlign.right),
        content: Text("هل أنت متأكد من حذف بيانات المستهلك ($name) نهائياً؟", textAlign: TextAlign.right),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("إلغاء")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("حذف الآن", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('consumers').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حذف البيانات بنجاح")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        title: const Text("قاعدة بيانات المستهلكين", style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
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
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
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
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        var filteredDocs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String name = (data['fullname'] ?? "").toString().toLowerCase();
          String phone = (data['phone'] ?? "").toString();
          return name.contains(_searchText.toLowerCase()) || phone.contains(_searchText);
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) => _buildConsumerCard(filteredDocs[index]),
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
        contentPadding: const EdgeInsets.all(10),
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

  // --- الديالوج بتاع التفاصيل (تكملة الكود) ---
  void _showDetailsDialog(Map<String, dynamic> data) {
    // كود الديالوج اللي عملناه سابقاً
  }
}
