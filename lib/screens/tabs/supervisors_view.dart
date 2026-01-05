import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SupervisorsView extends StatelessWidget {
  const SupervisorsView({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('managers').where('role', '==', 'sales_supervisor').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var sup = snapshot.data!.docs[index];
            return Card(
              child: ListTile(
                title: Text(sup['fullname'] ?? ''),
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
    var allReps = await db.collection('salesRep').get();
    showDialog(
      context: context,
      builder: (context) {
        List<String> selectedIds = allReps.docs
            .where((doc) => doc.data()['supervisorId'] == supId)
            .map((doc) => doc.id).toList();

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text("تعيين مناديب لـ $name"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: allReps.docs.map((doc) {
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
                  for (var doc in allReps.docs) {
                    batch.update(doc.reference, {
                      'supervisorId': selectedIds.contains(doc.id) ? supId : null
                    });
                  }
                  await batch.commit();
                  Navigator.pop(context);
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

