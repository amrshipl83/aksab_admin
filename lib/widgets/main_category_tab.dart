import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MainCategoryTab extends StatefulWidget {
  const MainCategoryTab({super.key});

  @override
  State<MainCategoryTab> createState() => _MainCategoryTabState();
}

class _MainCategoryTabState extends State<MainCategoryTab> {
  // استخدام نفس أسماء الكولكشنز من كود الـ HTML
  final String collectionName = "mainCategory"; 

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // زر للإضافة (يمكنك ربطه بـ Dialog لاحقاً)
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () => _showAddDialog(),
            icon: const Icon(Icons.add),
            label: const Text("إضافة قسم رئيسي جديد"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4361ee),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
        
        const Divider(),
        
        // عرض البيانات القديمة الموجودة في Firestore
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(collectionName)
                .orderBy('order') // الترتيب كما في كود الـ JS
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text("خطأ في تحميل البيانات"));
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text("لا توجد أقسام رئيسية حالياً"));

              return ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(10),
                      // عرض الصورة من Cloudinary كما في كود الـ HTML
                      leading: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          image: DecorationImage(
                            image: NetworkImage(data['imageUrl'] ?? 'https://via.placeholder.com/150'),
                            fit: cover,
                          ),
                        ),
                      ),
                      title: Text(
                        data['name'] ?? 'بدون اسم',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("الترتيب: ${data['order']}"),
                          Text(
                            data['status'] == 'active' ? "نشط" : "غير نشط",
                            style: TextStyle(color: data['status'] == 'active' ? Colors.green : Colors.red),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            onPressed: () => _showEditDialog(docs[index]),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteCategory(docs[index].id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // دالة الحذف (تنبيه: يجب الحذف بحذر كما في كود الـ JS)
  Future<void> _deleteCategory(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: const Text("سيؤدي حذف القسم لحذف الأقسام الفرعية والمنتجات المرتبطة به. هل أنت متأكد؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("حذف", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection(collectionName).doc(id).delete();
    }
  }

  // يمكننا لاحقاً إضافة الـ Dialogs الخاصة بالإضافة والتعديل
  void _showAddDialog() { /* سأزودك بكود فورم الإضافة عند الطلب */ }
  void _showEditDialog(DocumentSnapshot doc) { /* سأزودك بكود التعديل */ }
}

