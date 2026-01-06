import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PendingStaffTab extends StatelessWidget {
  const PendingStaffTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QueryDocumentSnapshot>>(
      // دمج تيار البيانات من المجموعتين
      stream: _getCombinedPendingStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("خطأ في الاتصال"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("لا توجد طلبات توظيف معلقة", style: TextStyle(fontFamily: 'Cairo')));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data![index];
            var data = doc.data() as Map<String, dynamic>;
            bool isManager = doc.reference.path.contains('pendingManagers');
            
            return _buildStaffRequestCard(context, doc.id, data, isManager);
          },
        );
      },
    );
  }

  // دالة لدمج مجموعتي الانتظار (Reps & Managers)
  Stream<List<QueryDocumentSnapshot>> _getCombinedPendingStream() {
    var reps = FirebaseFirestore.instance.collection('pendingReps').snapshots();
    var mgrs = FirebaseFirestore.instance.collection('pendingManagers').snapshots();
    
    // ملاحظة: للتبسيط في العرض نستخدم StreamZip أو ندمج يدوياً
    // هنا سنستخدم دمج بسيط للمجموعات (بافتراض التحديث التلقائي)
    return FirebaseFirestore.instance.collection('pendingReps').snapshots().map((repsSnap) => repsSnap.docs)
        .asyncMap((repsDocs) async {
          var mgrsSnap = await FirebaseFirestore.instance.collection('pendingManagers').get();
          return [...repsDocs, ...mgrsSnap.docs];
        });
  }

  Widget _buildStaffRequestCard(BuildContext context, String uid, Map<String, dynamic> data, bool isManager) {
    String roleLabel = isManager ? "إدارة / إشراف" : "مندوب تحصيل";
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isManager ? Colors.green.shade100 : Colors.orange.shade100,
          child: Icon(isManager ? Icons.admin_panel_settings : Icons.badge, 
               color: isManager ? Colors.green : Colors.orange),
        ),
        title: Text(data['fullname'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        subtitle: Text("$roleLabel | ${data['phone']}", style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
        trailing: ElevatedButton(
          onPressed: () => _openActivationDialog(context, uid, data, isManager),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A2C3D)),
          child: const Text("تفعيل", style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
        ),
      ),
    );
  }

  // نافذة التفعيل (بديل الـ Modal في HTML)
  void _openActivationDialog(BuildContext context, String uid, Map<String, dynamic> data, bool isManager) {
    final TextEditingController codeController = TextEditingController(text: "${isManager ? 'MGR' : 'REP'}-${data['phone']}");
    final TextEditingController salaryController = TextEditingController(text: "4000");
    final TextEditingController commController = TextEditingController(text: "0");
    final TextEditingController supIdController = TextEditingController(text: "91nXwJXt3LzH09Ox46La");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تفعيل واعتماد بيانات الموظف", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: codeController, decoration: const InputDecoration(labelText: "كود التعريف (Code)")),
              Row(
                children: [
                  Expanded(child: TextField(controller: salaryController, decoration: const InputDecoration(labelText: "الراتب"), keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: commController, decoration: const InputDecoration(labelText: "العمولة %"), keyboardType: TextInputType.number)),
                ],
              ),
              if (!isManager) TextField(controller: supIdController, decoration: const InputDecoration(labelText: "معرف المشرف المسؤول")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () => _executeActivation(context, uid, data, isManager, {
              'code': codeController.text,
              'salary': double.tryParse(salaryController.text) ?? 0,
              'comm': double.tryParse(commController.text) ?? 0,
              'supId': supIdController.text,
            }),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("تأكيد التفعيل", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeActivation(BuildContext context, String uid, Map<String, dynamic> data, bool isManager, Map<String, dynamic> inputs) async {
    try {
      String targetCol = isManager ? "managers" : "deliveryReps";
      String sourceCol = isManager ? "pendingManagers" : "pendingReps";

      final payload = {
        ...data,
        'repCode': inputs['code'],
        'baseSalary': inputs['salary'],
        'commissionRate': inputs['comm'],
        'status': "approved",
        'approvedAt': FieldValue.serverTimestamp(),
        'uid': uid,
      };

      if (!isManager) {
        payload['supervisorId'] = inputs['supId'];
        payload['walletBalance'] = 0;
      }

      await FirebaseFirestore.instance.collection(targetCol).doc(uid).set(payload);
      await FirebaseFirestore.instance.collection(sourceCol).doc(uid).delete();

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم نقل ${data['fullname']} إلى $targetCol")));
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }
}

