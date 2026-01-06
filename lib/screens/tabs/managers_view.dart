import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../salary_detail_screen.dart'; // استيراد شاشة الرواتب المعتمدة

class ManagersView extends StatelessWidget {
  const ManagersView({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore db = FirebaseFirestore.instance;
    // الحصول على الشهر الحالي للمقارنة (مثلاً 2026-01)
    String currentMonth = DateTime.now().toString().substring(0, 7);

    return StreamBuilder<QuerySnapshot>(
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
            
            // التحقق هل تم اعتماد راتب هذا الشهر؟
            bool isSettled = manager['lastSettledMonth'] == currentMonth;

            return Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: Stack(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFF1A2C3D),
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    // نقطة التنبيه إذا لم يتم الاعتماد
                    if (!isSettled)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                        ),
                      ),
                  ],
                ),
                title: InkWell(
                  onTap: () => _navigateToSalary(context, managerId, 'manager'),
                  child: Text(
                    manager['fullname'] ?? 'بدون اسم',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("الهدف: ${manager['targetAmount'] ?? 0}"),
                    // الليبل التوضيحي
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSettled ? Colors.green[100] : Colors.orange[100],
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        isSettled ? "تم اعتماد الراتب ✅" : "بإنتظار الاعتماد ⏳",
                        style: TextStyle(
                          fontSize: 10,
                          color: isSettled ? Colors.green[800] : Colors.orange[900],
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ),
                // زر التعيين (الموجود سابقاً) نتركه في الـ Trailing
                trailing: IconButton(
                  icon: const Icon(Icons.group_add, color: Colors.orange),
                  onPressed: () => _showAssignmentDialog(context, db, managerId, manager['fullname'] ?? ''),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // دالة الانتقال لشاشة الرواتب
  void _navigateToSalary(BuildContext context, String id, String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SalaryDetailScreen(
          employeeId: id,
          employeeType: type,
        ),
      ),
    );
  }

  // ... دالة _showAssignmentDialog تبقى كما هي بدون تغيير ...
  void _showAssignmentDialog(BuildContext context, FirebaseFirestore db, String managerId, String name) async {
    var allSups = await db.collection('managers').where('role', isEqualTo: 'sales_supervisor').get();
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        List<String> selectedIds = [];
        for (var doc in allSups.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['managerId'] == managerId) selectedIds.add(doc.id);
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
                              if (val == true) selectedIds.add(doc.id);
                              else selectedIds.remove(doc.id);
                            });
                          },
                        );
                      }).toList(),
                    ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
              ElevatedButton(
                onPressed: () async {
                  WriteBatch batch = db.batch();
                  for (var doc in allSups.docs) {
                    batch.update(doc.reference, {'managerId': selectedIds.contains(doc.id) ? managerId : null});
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

