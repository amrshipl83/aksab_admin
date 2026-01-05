import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:rxdart/rxdart.dart'; // سنحتاج لمكتبة rxdart لدمج الـ Streams بسهولة

class PendingView extends StatelessWidget {
  const PendingView({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    // دمج Stream الخاص بالمديرين مع Stream الخاص بالمناديب كما في الـ HTML
    return StreamBuilder<List<QuerySnapshot>>(
      stream: CombineLatestStream.list([
        db.collection('pendingManagers').snapshots(),
        db.collection('pendingReps').snapshots(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        // تجميع كل المستندات من الكولكشنين في قائمة واحدة
        final allDocs = snapshot.data!.expand((snap) => snap.docs).toList();

        if (allDocs.isEmpty) {
          return const Center(
            child: Text("لا توجد طلبات معلقة حالياً", style: TextStyle(fontFamily: 'Cairo')),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: allDocs.length,
          itemBuilder: (context, index) {
            final doc = allDocs[index];
            final user = doc.data() as Map<String, dynamic>;
            final String docId = doc.id;
            final String sourceCollection = doc.reference.parent.id; // معرفة المصدر (pendingManagers أم pendingReps)

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

  // دالة الموافقة المطابقة للمنطق في HTML
  Future<void> _approveUser(BuildContext context, FirebaseFirestore db, String docId, Map<String, dynamic> data, String sourceCol) async {
    try {
      // تحديد الكولكشن المستهدف بناءً على الدور
      String targetCol = (data['role'] == 'sales_rep') ? 'salesRep' : 'managers';
      
      // توليد الـ repCode للمناديب فقط (سواء مبيعات أو دليفري) كما في الـ HTML
      String? repCode;
      if (data['role'] == 'sales_rep' || data['role'] == 'delivery_rep') {
        String prefix = (data['role'] == 'sales_rep') ? 'REP-' : 'DEL-';
        repCode = prefix + docId;
      }

      await db.collection(targetCol).doc(docId).set({
        ...data,
        'repCode': repCode,
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // حذف من الكولكشن الأصلي (الذي جاء منه الطلب)
      await db.collection(sourceCol).doc(docId).delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تمت الموافقة بنجاح ونقل البيانات")),
        );
      }
    } catch (e) {
      debugPrint("Error approving user: $e");
    }
  }

  Future<void> _rejectUser(BuildContext context, FirebaseFirestore db, String docId, String sourceCol) async {
    await db.collection(sourceCol).doc(docId).delete();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الرفض والحذف")));
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

