import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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

      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/products_report.xlsx";
      final file = File(path);
      await file.writeAsBytes(excel.encode()!);

      await Share.shareXFiles([XFile(path)], text: 'تقرير المنتجات');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ في التصدير: $e")),
      );
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
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('mainCategory').snapshots(),
                  builder: (context, snap) {
                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "القسم الرئيسي"),
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
                  decoration: const InputDecoration(labelText: "الحالة"),
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
            decoration: const InputDecoration(
              hintText: "بحث بالاسم...",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
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
            final imageUrl = (data['imageUrls'] as List).isNotEmpty ? data['imageUrls'][0] : '';

            return ListTile(
              leading: imageUrl != '' ? Image.network(imageUrl, width: 40) : const Icon(Icons.image),
              title: Text(data['name']),
              subtitle: Text(mainCategoriesNames[data['mainId']] ?? ''),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editProduct(id, data)),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteProduct(id, data['name'])),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _editProduct(String id, Map<String, dynamic> data) {
     final nameEdit = TextEditingController(text: data['name']);
     showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تعديل سريع"),
        content: TextField(controller: nameEdit, decoration: const InputDecoration(labelText: "اسم المنتج")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('products').doc(id).update({'name': nameEdit.text});
              Navigator.pop(ctx);
            },
            child: const Text("حفظ"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(String id, String name) async {
    await FirebaseFirestore.instance.collection('products').doc(id).delete();
  }
}

