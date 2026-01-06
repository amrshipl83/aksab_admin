import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminBranchesTab extends StatelessWidget {
  const AdminBranchesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('administrativeEmployees').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            List branches = data['allowedBranches'] ?? [];

            return Card(
              // تم التصحيح هنا من EdgeInsets.bottom إلى EdgeInsets.only(bottom: 10)
              margin: const EdgeInsets.only(bottom: 10), 
              child: ListTile(
                leading: const Icon(Icons.location_on, color: Colors.red),
                title: Text(data['fullname'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                subtitle: Text("عدد الفروع المسموحة: ${branches.length}"),
                trailing: ElevatedButton(
                  onPressed: () => _manageBranches(context, doc.id, data['fullname'], branches),
                  child: const Text("إدارة المواقع"),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _manageBranches(BuildContext context, String docId, String name, List currentBranches) {
    final nameCont = TextEditingController();
    final latCont = TextEditingController();
    final lngCont = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text("فروع الموظف: $name", style: const TextStyle(fontFamily: 'Cairo', fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...currentBranches.map((b) => ListTile(
                      title: Text(b['name'] ?? ''),
                      subtitle: Text("${b['lat']}, ${b['lng']}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          currentBranches.remove(b);
                          setState(() {});
                        },
                      ),
                    )),
                const Divider(),
                const Text("إضافة فرع جديد", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                TextField(controller: nameCont, decoration: const InputDecoration(labelText: "اسم الفرع")),
                TextField(controller: latCont, decoration: const InputDecoration(labelText: "Latitude"), keyboardType: TextInputType.number),
                TextField(controller: lngCont, decoration: const InputDecoration(labelText: "Longitude"), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: () {
                if (nameCont.text.isNotEmpty && latCont.text.isNotEmpty) {
                  currentBranches.add({
                    'name': nameCont.text,
                    'lat': double.tryParse(latCont.text) ?? 0.0,
                    'lng': double.tryParse(lngCont.text) ?? 0.0,
                  });
                  FirebaseFirestore.instance.collection('administrativeEmployees').doc(docId).update({
                    'allowedBranches': currentBranches
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text("حفظ التغييرات"),
            ),
          ],
        ),
      ),
    );
  }
}

