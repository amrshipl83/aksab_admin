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
        db.collection('pendingManagers').snapshots(),
        db.collection('pendingReps')
            .where('role', isEqualTo: 'sales_rep')
            .snapshots(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

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
                      onPressed: () {
                        if (user['role'] == 'sales_rep') {
                          _showApproveDialog(context, db, docId, user, sourceCollection);
                        } else {
                          _approveUser(context, db, docId, user, sourceCollection, null);
                        }
                      },
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

  // نافذة طلب نسبة العمولة للمناديب
  Future<void> _showApproveDialog(BuildContext context, FirebaseFirestore db, String docId, Map<String, dynamic> data, String sourceCol) async {
    final TextEditingController commissionController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text("الموافقة على الطلب", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("نوع الحساب: مندوب مبيعات", style: TextStyle(fontFamily: 'Cairo', color: Colors.blueGrey)),
              const SizedBox(height: 15),
              const Text("نسبة العمولة (اختياري):", style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: commissionController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: "اتركها فارغة للموظف الثابت",
                  border: OutlineInputBorder(),
                  suffixText: "%",
                ),
              ),
              const SizedBox(height: 10),
              const Text(" * اتركها فارغة إذا كان المندوب موظفاً براتب ثابت.", 
                style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.redAccent)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                double? commission = double.tryParse(commissionController.text);
                Navigator.pop(context);
                _approveUser(context, db, docId, data, sourceCol, commission);
              },
              child: const Text("تأكيد الموافقة", style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveUser(BuildContext context, FirebaseFirestore db, String docId, Map<String, dynamic> data, String sourceCol, double? commissionRate) async {
    try {
      bool isRep = (data['role'] == 'sales_rep');
      String targetCol = isRep ? 'salesRep' : 'managers';
      
      Map<String, dynamic> finalData = {
        ...data,
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      };

      if (isRep) {
        finalData['repCode'] = "REP-${docId.substring(0, 5).toUpperCase()}";
        if (commissionRate != null) {
          finalData['commissionRate'] = commissionRate;
          finalData['employmentType'] = 'freelancer';
        } else {
          finalData['employmentType'] = 'employee';
        }
      }

      await db.collection(targetCol).doc(docId).set(finalData);
      await db.collection(sourceCol).doc(docId).delete();

      if (context.mounted) {
        String msg = (isRep && commissionRate != null) 
            ? "تمت الموافقة كمندوب حر بنسبة $commissionRate%" 
            : "تمت الموافقة بنجاح";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Cairo'))));
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _rejectUser(BuildContext context, FirebaseFirestore db, String docId, String sourceCol) async {
    await db.collection(sourceCol).doc(docId).delete();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حذف الطلب")));
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

