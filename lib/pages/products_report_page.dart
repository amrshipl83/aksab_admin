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
  Map<String, String> subCategoriesNames = {};

  @override
  void initState() {
    super.initState();
    _loadCategoryNames();
  }

  Future<void> _loadCategoryNames() async {
    final mainSnap = await FirebaseFirestore.instance.collection('mainCategory').get();
    final subSnap = await FirebaseFirestore.instance.collection('subCategory').get();
    setState(() {
      for (var doc in mainSnap.docs) mainCategoriesNames[doc.id] = doc['name'];
      for (var doc in subSnap.docs) subCategoriesNames[doc.id] = doc['name'];
    });
  }

  // --- وظيفة التصدير إلى إكسل ---
  Future<void> _exportToExcel(List<QueryDocumentSnapshot> docs) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Products Report'];

    sheetObject.appendRow(['اسم المنتج', 'القسم الرئيسي', 'الحالة', 'الترتيب']);

    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      sheetObject.appendRow([
        data['name'] ?? '',
        mainCategoriesNames[data['mainId']] ?? 'غير معروف',
        data['status'] == 'active' ? 'نشط' : 'غير نشط',
        data['order']?.toString() ?? '0',
      ]);
    }

    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/products_report.xlsx";
    final file = File(path);
    await file.writeAsBytes(excel.encode()!);

    await Share.shareXFiles([XFile(path)], text: 'تقرير المنتجات');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("كتالوج المنتجات"),
        backgroundColor: const Color(0xFF4361ee),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download, color: Colors.white),
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
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
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
              hintText: "بحث سريع بالاسم...",
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
          docs = docs.where((d) => d['name'].toString().toLowerCase().contains(_searchController.text.toLowerCase())).toList();
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;
            final imageUrl = (data['imageUrls'] as List).isNotEmpty ? data['imageUrls'][0] : '';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageUrl != '' 
                      ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                      : Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.image_not_supported)),
                ),
                title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${mainCategoriesNames[data['mainId']] ?? '...'} | ترتيب: ${data['order']}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editProduct(id, data)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteProduct(id, data['name'])),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- واجهة تعديل المنتج ---
  void _editProduct(String id, Map<String, dynamic> data) {
    final nameEdit = TextEditingController(text: data['name']);
    final orderEdit = TextEditingController(text: data['order'].toString());
    String currentStatus = data['status'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تعديل المنتج", textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameEdit, decoration: const InputDecoration(labelText: "اسم المنتج")),
              TextField(controller: orderEdit, decoration: const InputDecoration(labelText: "الترتيب"), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: currentStatus,
                items: const [
                  DropdownMenuItem(value: 'active', child: Text("نشط")),
                  DropdownMenuItem(value: 'inactive', child: Text("غير نشط")),
                ],
                onChanged: (v) => currentStatus = v!,
                decoration: const InputDecoration(labelText: "الحالة"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('products').doc(id).update({
                'name': nameEdit.text,
                'order': int.tryParse(orderEdit.text) ?? 0,
                'status': currentStatus,
              });
              Navigator.pop(ctx);
            },
            child: const Text("حفظ التعديلات"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(String id, String name) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: Text("هل تريد حذف المنتج $name نهائياً؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("تراجع")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("حذف", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm) await FirebaseFirestore.instance.collection('products').doc(id).delete();
  }
}

