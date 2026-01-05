import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RepsView extends StatelessWidget {
  const RepsView({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('salesRep').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var rep = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.person, color: Colors.blue),
                title: Text(rep['fullname'] ?? ''),
                subtitle: Text("كود المندوب: ${rep['repCode'] ?? 'غير معرف'}"),
                trailing: Text(rep['email'] ?? '', style: const TextStyle(fontSize: 10)),
              ),
            );
          },
        );
      },
    );
  }
}

