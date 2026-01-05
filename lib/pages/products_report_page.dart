import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // للتمييز بين الويب والموبايل

// هذا الجزء يحل مشكلة الـ Build للويب
import 'dart:io' if (dart.library.html) 'dart:ui_web'; 

class ProductsReportPage extends StatefulWidget {
  const ProductsReportPage({super.key});

  @override
  State<ProductsReportPage> createState() => _ProductsReportPageState();
}

class _ProductsReportPageState extends State<ProductsReportPage> {
  String? selectedMainId;
  String? selectedStatus;
  final TextEditingController _searchController = TextEditingController();
  Map<String, String> mainCategoriesNames = {};

  @override
  void initState() {
    super.initState();
    _loadCategoryNames();
  }

  Future<void> _loadCategoryNames() async {
    final mainSnap = await FirebaseFirestore.instance.collection('mainCategory').get();
    setState(() {
      for (var doc in mainSnap.docs) {
        mainCategoriesNames[doc.id] = doc['name'];
      }
    });
  }

  // وظيفة التصدير المحسنة للويب والموبايل
  Future<void> _exportToExcel(List<QueryDocumentSnapshot> docs) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Products'];
      sheetObject.appendRow(['اسم المنتج', 'القسم الرئيسي', 'الحالة']);

      for (var doc in docs) {
        var data = doc.data() as Map<String, dynamic>;
        sheetObject.appendRow([
          data['name'] ?? '',
          mainCategoriesNames[data['mainId']] ?? 'غير معروف',
          data['status'] == 'active' ? 'نشط' : 'غير نشط',
        ]);
      }

      // حفظ الملف بطريقة تناسب المتصفح والموبايل
      if (kIsWeb) {
        // في الويب يتم التحميل مباشرة
        excel.save(fileName: "products_report.xlsx");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("جاري تحميل ملف الإكسل...")));
      } else {
        // للموبايل فقط نستخدم هذه الطريقة (سيتم تجاهلها في الويب)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("هذه الميزة تعمل في نسخة الويب حالياً")));
      }
    } catch (e) {
      debugPrint("Excel Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("كتالوج المنتجات"),
        backgroundColor: const Color(0xFF4361ee),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () async {
              final snap = await FirebaseFirestore.instance.collection('products').get();
              _exportToExcel(snap.docs);
            },
          )
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(child: _buildProductsList()),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('mainCategory').snapshots(),
                  builder: (context, snap) {
                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "القسم الرئيسي", border: OutlineInputBorder()),
                      value: selectedMainId,
                      items: snap.data?.docs.map((d) => DropdownMenuItem(value: d.id, child: Text(d['name']))).toList(),
                      onChanged: (v) => setState(() => selectedMainId = v),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "الحالة", border: OutlineInputBorder()),
                  value: selectedStatus,
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text("نشط")),
                    DropdownMenuItem(value: 'inactive', child: Text("غير نشط")),
                  ],
                  onChanged: (v) => setState(() => selectedStatus = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: "بحث بالاسم...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (v) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    Query query = FirebaseFirestore.instance.collection('products');
    if (selectedMainId != null) query = query.where('mainId', isEqualTo: selectedMainId);
    if (selectedStatus != null) query = query.where('status', isEqualTo: selectedStatus);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;
        if (_searchController.text.isNotEmpty) {
          docs = docs.where((d) => d['name'].toString().contains(_searchController.text)).toList();
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;
            final imageUrl = (data['imageUrls'] != null && (data['imageUrls'] as List).isNotEmpty) ? data['imageUrls'][0] : '';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: imageUrl != '' ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover) : const Icon(Icons.image),
                title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(mainCategoriesNames[data['mainId']] ?? 'تحميل...'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editProduct(id, data)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteProduct(id)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _editProduct(String id, Map<String, dynamic> data) {
    // واجهة تعديل مبسطة
    final nameController = TextEditingController(text: data['name']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تعديل اسم المنتج"),
        content: TextField(controller: nameController, textAlign: TextAlign.right),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('products').doc(id).update({'name': nameController.text});
              Navigator.pop(context);
            },
            child: const Text("حفظ"),
          )
        ],
      ),
    );
  }

  Future<void> _deleteProduct(String id) async {
    await FirebaseFirestore.instance.collection('products').doc(id).delete();
  }
}

