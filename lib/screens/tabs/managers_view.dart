import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagersView extends StatelessWidget {
  const ManagersView({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot>(
      // التصحيح الأول: تعديل الـ where لتستخدم المعامل المسمى isEqualTo
      stream: db
          .collection('managers')
          .where('role', isEqualTo: 'sales_manager')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;

        if (docs.isEmpty) return const Center(child: Text("لا يوجد مديرو مبيعات حالياً"));

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var manager = docs[index].data() as Map<String, dynamic>;
            var managerId = docs[index].id;

            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF1A2C3D),
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(manager['fullname'] ?? 'بدون اسم'),
                subtitle: Text("الهدف: ${manager['targetAmount'] ?? 0}"),
                trailing: const Icon(Icons.edit_note, color: Colors.orange),
                onTap: () => _showAssignmentDialog(context, db, managerId, manager['fullname'] ?? ''),
              ),
            );
          },
        );
      },
    );
  }

  void _showAssignmentDialog(BuildContext context, FirebaseFirestore db, String managerId, String name) async {
    // التصحيح الثاني: تعديل الـ where هنا أيضاً لجلب المشرفين بشكل صحيح
    var allSups = await db
        .collection('managers')
        .where('role', isEqualTo: 'sales_supervisor')
        .get();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        List<String> selectedIds = [];
        // تحديد من يتبع هذا المدير حالياً بناءً على الحقل المرجعي managerId
        for (var doc in allSups.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['managerId'] == managerId) {
            selectedIds.add(doc.id);
          }
        }

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text("تعيين مشرفين لـ $name", style: const TextStyle(fontFamily: 'Cairo')),
            content: SizedBox(
              width: double.maxFinite,
              child: allSups.docs.isEmpty
                  ? const Text("لا يوجد مشرفون متاحون حالياً")
                  : ListView(
                      shrinkWrap: true,
                      children: allSups.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return CheckboxListTile(
                          title: Text(data['fullname'] ?? 'بدون اسم'),
                          value: selectedIds.contains(doc.id),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                selectedIds.add(doc.id);
                              } else {
                                selectedIds.remove(doc.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("إلغاء"),
              ),
              ElevatedButton(
                onPressed: () async {
                  WriteBatch batch = db.batch();
                  // تحديث حقل managerId في مستندات المشرفين بناءً على الاختيار
                  for (var doc in allSups.docs) {
                    batch.update(doc.reference, {
                      'managerId': selectedIds.contains(doc.id) ? managerId : null
                    });
                  }
                  await batch.commit();
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text("حفظ التغييرات"),
              )
            ],
          ),
        );
      },
    );
  }
}

