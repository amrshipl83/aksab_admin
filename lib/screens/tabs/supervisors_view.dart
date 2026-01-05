import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SupervisorsView extends StatelessWidget {
  const SupervisorsView({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot>(
      // التصحيح هنا: استخدام isEqualTo بدلاً من الفواصل العادية
      stream: db
          .collection('managers')
          .where('role', isEqualTo: 'sales_supervisor')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        var docs = snapshot.data!.docs;
        
        if (docs.isEmpty) {
          return const Center(child: Text("لا يوجد مشرفون مسجلون حالياً"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var sup = docs[index];
            return Card(
              child: ListTile(
                title: Text(sup['fullname'] ?? 'بدون اسم'),
                subtitle: const Text("اضغط لتعيين المناديب"),
                trailing: const Icon(Icons.handshake),
                onTap: () => _showRepsDialog(context, db, sup.id, sup['fullname']),
              ),
            );
          },
        );
      },
    );
  }

  void _showRepsDialog(BuildContext context, FirebaseFirestore db, String supId, String name) async {
    // جلب قائمة المناديب
    var allReps = await db.collection('salesRep').get();
    
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        // تحديد المناديب التابعين لهذا المشرف حالياً بناءً على حقل supervisorId
        List<String> selectedIds = allReps.docs
            .where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['supervisorId'] == supId;
            })
            .map((doc) => doc.id)
            .toList();

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text("تعيين مناديب لـ $name", style: const TextStyle(fontFamily: 'Cairo')),
            content: SizedBox(
              width: double.maxFinite,
              child: allReps.docs.isEmpty 
                ? const Text("لا يوجد مناديب متاحين")
                : ListView(
                    shrinkWrap: true,
                    children: allReps.docs.map((doc) {
                      var repData = doc.data() as Map<String, dynamic>;
                      return CheckboxListTile(
                        title: Text(repData['fullname'] ?? 'بدون اسم'),
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
                  // تحديث حقل supervisorId لكل المندوبين
                  for (var doc in allReps.docs) {
                    batch.update(doc.reference, {
                      'supervisorId': selectedIds.contains(doc.id) ? supId : null
                    });
                  }
                  await batch.commit();
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text("حفظ"),
              )
            ],
          ),
        );
      },
    );
  }
}

