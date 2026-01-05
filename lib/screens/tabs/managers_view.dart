import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagersView extends StatelessWidget {
  const ManagersView({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('managers').where('role', '==', 'sales_manager').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var manager = docs[index].data() as Map<String, dynamic>;
            var managerId = docs[index].id;

            return Card(
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFF1A2C3D), child: Icon(Icons.person, color: Colors.white)),
                title: Text(manager['fullname'] ?? ''),
                subtitle: Text("الهدف: ${manager['targetAmount'] ?? 0}"),
                trailing: const Icon(Icons.edit_note, color: Colors.orange),
                onTap: () => _showAssignmentDialog(context, db, managerId, manager['fullname']),
              ),
            );
          },
        );
      },
    );
  }

  void _showAssignmentDialog(BuildContext context, FirebaseFirestore db, String managerId, String name) async {
    var allSups = await db.collection('managers').where('role', '==', 'sales_supervisor').get();
    
    showDialog(
      context: context,
      builder: (context) {
        List<String> selectedIds = [];
        // تحديد من يتبع هذا المدير حالياً
        for (var doc in allSups.docs) {
          if (doc.data()['managerId'] == managerId) selectedIds.add(doc.id);
        }

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text("تعيين مشرفين لـ $name"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: allSups.docs.map((doc) {
                  return CheckboxListTile(
                    title: Text(doc.data()['fullname'] ?? ''),
                    value: selectedIds.contains(doc.id),
                    onChanged: (val) {
                      setState(() => val! ? selectedIds.add(doc.id) : selectedIds.remove(doc.id));
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  WriteBatch batch = db.batch();
                  for (var doc in allSups.docs) {
                    batch.update(doc.reference, {
                      'managerId': selectedIds.contains(doc.id) ? managerId : null
                    });
                  }
                  await batch.commit();
                  Navigator.pop(context);
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

