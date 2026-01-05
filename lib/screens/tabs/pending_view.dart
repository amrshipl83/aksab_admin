import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart'; 

class PendingView extends StatelessWidget {
  const PendingView({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    return StreamBuilder<List<QuerySnapshot>>(
      stream: CombineLatestStream.list([
        // نجلب كل من في pendingManagers (مديرين ومشرفين)
        db.collection('pendingManagers').snapshots(),
        // نجلب من pendingReps بشرط أن يكون مندوب مبيعات فقط
        db.collection('pendingReps')
          .where('role', isEqualTo: 'sales_rep') // الفلترة المطلوبة
          .snapshots(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        // دمج النتائج في قائمة واحدة
        final allDocs = snapshot.data!.expand((snap) => snap.docs).toList();

        if (allDocs.isEmpty) {
          return const Center(
            child: Text("لا توجد طلبات مبيعات معلقة", style: TextStyle(fontFamily: 'Cairo')),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: allDocs.length,
          itemBuilder: (context, index) {
            final doc = allDocs[index];
            final user = doc.data() as Map<String, dynamic>;
            final String docId = doc.id;
            final String sourceCollection = doc.reference.parent.id;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getRoleColor(user['role']),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                title: Text(
                  user['fullname'] ?? 'بدون اسم',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                ),
                subtitle: Text(
                  "الدور: ${_getRoleArabicName(user['role'])}\n${user['email']}",
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _approveUser(context, db, docId, user, sourceCollection),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _rejectUser(context, db, docId, sourceCollection),
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

  Future<void> _approveUser(BuildContext context, FirebaseFirestore db, String docId, Map<String, dynamic> data, String sourceCol) async {
    try {
      // المناديب يذهبون لـ salesRep والباقي لـ managers
      String targetCol = (data['role'] == 'sales_rep') ? 'salesRep' : 'managers';
      
      // إنشاء كود المندوب
      String? repCode = (data['role'] == 'sales_rep') ? "REP-$docId" : null;

      await db.collection(targetCol).doc(docId).set({
        ...data,
        'repCode': repCode,
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      await db.collection(sourceCol).doc(docId).delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تمت الموافقة ونقل المندوب بنجاح")),
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _rejectUser(BuildContext context, FirebaseFirestore db, String docId, String sourceCol) async {
    await db.collection(sourceCol).doc(docId).delete();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الحذف")));
    }
  }

  String _getRoleArabicName(dynamic role) {
    if (role == 'sales_manager') return "مدير مبيعات";
    if (role == 'sales_supervisor') return "مشرف مبيعات";
    if (role == 'sales_rep') return "مندوب مبيعات";
    return role.toString();
  }

  Color _getRoleColor(dynamic role) {
    if (role == 'sales_manager') return Colors.blue;
    if (role == 'sales_supervisor') return Colors.orange;
    return Colors.green;
  }
}

