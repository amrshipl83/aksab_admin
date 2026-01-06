import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyRepsTab extends StatelessWidget {
  const CompanyRepsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // جلب كافة المناديب من مجموعة deliveryReps
      stream: FirebaseFirestore.instance.collection('deliveryReps').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("خطأ في جلب البيانات"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("لا يوجد مناديب شركة حالياً", style: TextStyle(fontFamily: 'Cairo')));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            return _buildRepCard(context, doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildRepCard(BuildContext context, String uid, Map<String, dynamic> data) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.shade800,
          child: const Icon(Icons.badge, color: Colors.white),
        ),
        title: Text(data['fullname'] ?? 'بدون اسم', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        subtitle: Text("كود: ${data['repCode'] ?? '---'} | راتب: ${data['baseSalary'] ?? 0} ج.م", 
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _infoRow(Icons.phone, "الهاتف", data['phone'] ?? '---'),
                _infoRow(Icons.percent, "العمولة", "${data['commissionRate'] ?? 0} %"),
                _infoRow(Icons.supervisor_account, "المشرف المسؤول", data['supervisorId'] ?? 'غير مرتبط بمشرف'),
                _infoRow(Icons.location_on, "العنوان", data['address'] ?? 'غير مسجل'),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // زر التعديل الوظيفي
                    ElevatedButton.icon(
                      onPressed: () => _showEditRepDialog(context, uid, data),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text("تعديل البيانات", style: TextStyle(fontFamily: 'Cairo')),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A2C3D), foregroundColor: Colors.white),
                    ),
                    // زر الحالة
                    ElevatedButton.icon(
                      onPressed: () => _toggleRepStatus(context, uid, data['status']),
                      icon: Icon((data['status'] == 'active' || data['status'] == 'approved') ? Icons.block : Icons.check_circle, size: 18),
                      label: Text((data['status'] == 'active' || data['status'] == 'approved') ? "إيقاف" : "تفعيل", style: const TextStyle(fontFamily: 'Cairo')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (data['status'] == 'active' || data['status'] == 'approved') ? Colors.red : Colors.green,
                        foregroundColor: Colors.white
                      ),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 10),
          Text("$label: ", style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  void _showEditRepDialog(BuildContext context, String uid, Map<String, dynamic> data) {
    final salaryCont = TextEditingController(text: data['baseSalary']?.toString() ?? "4000");
    final commCont = TextEditingController(text: data['commissionRate']?.toString() ?? "0");
    String? selectedSupId = data['supervisorId'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("تعديل بيانات المندوب", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: salaryCont, decoration: const InputDecoration(labelText: "الراتب الأساسي"), keyboardType: TextInputType.number),
                TextField(controller: commCont, decoration: const InputDecoration(labelText: "نسبة العمولة %"), keyboardType: TextInputType.number),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text("المشرف المسؤول (من طاقم الإشراف):", style: TextStyle(fontSize: 12, fontFamily: 'Cairo', color: Colors.blueGrey))
                ),
                
                // القائمة المنسدلة للمشرفين فقط
                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance.collection('managers')
                      .where('role', isEqualTo: 'delivery_supervisor').get(),
                  builder: (context, supSnap) {
                    if (supSnap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                    if (!supSnap.hasData || supSnap.data!.docs.isEmpty) {
                      return const Text("لا يوجد مشرفين حالياً", style: TextStyle(color: Colors.red, fontSize: 12));
                    }
                    
                    return DropdownButton<String>(
                      isExpanded: true,
                      value: selectedSupId,
                      hint: const Text("اختر من القائمة"),
                      items: supSnap.data!.docs.map((supDoc) {
                        var supData = supDoc.data() as Map<String, dynamic>;
                        return DropdownMenuItem<String>(
                          value: supDoc.id,
                          child: Text(supData['fullname'] ?? supDoc.id, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() => selectedSupId = val);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('deliveryReps').doc(uid).update({
                  'baseSalary': double.tryParse(salaryCont.text) ?? 0,
                  'commissionRate': double.tryParse(commCont.text) ?? 0,
                  'supervisorId': selectedSupId,
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("حفظ التعديلات", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  void _toggleRepStatus(BuildContext context, String uid, String? currentStatus) async {
    String nextStatus = (currentStatus == 'active' || currentStatus == 'approved') ? 'suspended' : 'active';
    await FirebaseFirestore.instance.collection('deliveryReps').doc(uid).update({'status': nextStatus});
  }
}

