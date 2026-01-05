import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductsReportPage extends StatefulWidget {
  const ProductsReportPage({super.key});

  @override
  State<ProductsReportPage> createState() => _ProductsReportPageState();
}

class _ProductsReportPageState extends State<ProductsReportPage> {
  // متغيرات الفلترة
  String? selectedMainId;
  String? selectedSubId;
  String? selectedStatus;
  final TextEditingController _searchController = TextEditingController();

  // جلب أسماء الأقسام لعرضها بدلاً من الـ ID
  Map<String, String> mainCategoriesNames = {};
  Map<String, String> subCategoriesNames = {};

  @override
  void initState() {
    super.initState();
    _loadCategoryNames();
  }

  // تحميل أسماء الأقسام مرة واحدة لتحسين الأداء
  Future<void> _loadCategoryNames() async {
    final mainSnap = await FirebaseFirestore.instance.collection('mainCategory').get();
    final subSnap = await FirebaseFirestore.instance.collection('subCategory').get();
    
    setState(() {
      for (var doc in mainSnap.docs) {
        mainCategoriesNames[doc.id] = doc['name'];
      }
      for (var doc in subSnap.docs) {
        subCategoriesNames[doc.id] = doc['name'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("تقرير كتالوج المنتجات"),
        backgroundColor: const Color(0xFF4361ee),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(child: _buildProductsList()),
        ],
      ),
    );
  }

  // منطقة الفلاتر (مثل الـ HTML تماماً)
  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[100],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('mainCategory').snapshots(),
                  builder: (context, snap) {
                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "القسم الرئيسي", filled: true, fillColor: Colors.white),
                      value: selectedMainId,
                      items: snap.data?.docs.map((d) => DropdownMenuItem(value: d.id, child: Text(d['name']))).toList(),
                      onChanged: (v) => setState(() { selectedMainId = v; selectedSubId = null; }),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "الحالة", filled: true, fillColor: Colors.white),
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
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: "بحث باسم المنتج...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (v) => setState(() {}),
          ),
        ],
      ),
    );
  }

  // عرض قائمة المنتجات
  Widget _buildProductsList() {
    Query query = FirebaseFirestore.instance.collection('products');

    // تطبيق الفلاتر برمجياً
    if (selectedMainId != null) query = query.where('mainId', isEqualTo: selectedMainId);
    if (selectedStatus != null) query = query.where('status', isEqualTo: selectedStatus);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("حدث خطأ ما"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        var docs = snapshot.data!.docs;

        // فلترة البحث يدوياً (Client-side) لأن Firestore لا يدعم البحث الجزئي بسهولة
        if (_searchController.text.isNotEmpty) {
          docs = docs.where((d) => d['name'].toString().contains(_searchController.text)).toList();
        }

        if (docs.isEmpty) return const Center(child: Text("لا توجد منتجات مطابقة"));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;
            final imageUrl = (data['imageUrls'] as List).isNotEmpty ? data['imageUrls'][0] : '';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: imageUrl != '' 
                    ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                    : const Icon(Icons.image_not_supported),
                title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${mainCategoriesNames[data['mainId']] ?? ''} - ${data['status'] == 'active' ? 'نشط' : 'غير نشط'}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editProduct(id, data),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteProduct(id, data['name']),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // منطق الحذف
  Future<void> _deleteProduct(String id, String name) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: Text("هل أنت متأكد من حذف $name؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("حذف", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm) {
      await FirebaseFirestore.instance.collection('products').doc(id).delete();
    }
  }

  // سيتم إضافة واجهة التعديل هنا لاحقاً لضمان عدم تعقيد الكود الآن
  void _editProduct(String id, Map<String, dynamic> data) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("خاصية التعديل قيد البرمجة...")));
  }
}

