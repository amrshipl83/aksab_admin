import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PendingView extends StatelessWidget {
  const PendingView({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot>(
      // جلب البيانات من pendingManagers و pendingReps
      stream: db.collection('pendingManagers').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;

        if (docs.isEmpty) return const Center(child: Text("لا توجد طلبات معلقة"));

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var user = docs[index].data() as Map<String, dynamic>;
            var docId = docs[index].id;
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Text(user['fullname'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("الدور: ${user['role']}\n${user['email']}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _approveUser(context, db, docId, user),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _rejectUser(context, db, docId),
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

  Future<void> _approveUser(BuildContext context, FirebaseFirestore db, String docId, Map<String, dynamic> data) async {
    String targetCol = (data['role'] == 'sales_rep') ? 'salesRep' : 'managers';
    String? repCode = (data['role'] == 'sales_rep') ? "REP-$docId" : null;

    await db.collection(targetCol).doc(docId).set({
      ...data,
      'repCode': repCode,
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
    });
    await db.collection('pendingManagers').doc(docId).delete();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تمت الموافقة بنجاح")));
  }

  Future<void> _rejectUser(BuildContext context, FirebaseFirestore db, String docId) async {
    await db.collection('pendingManagers').doc(docId).delete();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الرفض والحذف")));
  }
}

