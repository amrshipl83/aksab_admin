import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminListTab extends StatelessWidget {
  const AdminListTab({super.key});

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
            return _buildEmployeeCard(context, doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildEmployeeCard(BuildContext context, String id, Map<String, dynamic> data) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.admin_panel_settings)),
        title: Text(data['fullname'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        subtitle: Text("${data['jobTitle'] ?? ''} - ${data['department'] ?? ''}", style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
        trailing: const Icon(Icons.edit_note, color: Colors.orange),
        // تم تغيير onPressed إلى onTap هنا
        onTap: () => _showRawDataEditor(context, id, data),
      ),
    );
  }

  void _showRawDataEditor(BuildContext context, String id, Map<String, dynamic> data) {
    final baseSalaryCont = TextEditingController(text: data['baseSalary']?.toString() ?? "0");
    final allowancesCont = TextEditingController(text: data['allowances']?.toString() ?? "0");
    final insuranceCont = TextEditingController(text: data['insurance']?.toString() ?? "0");
    final taxesCont = TextEditingController(text: data['taxes']?.toString() ?? "0");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 20, left: 20, right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("تعديل المدخلات الخام (Raw Data)", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            const Text("ملاحظة: اللمدا ستقوم بحساب الراتب النهائي بناءً على هذه القيم", style: TextStyle(fontSize: 10, color: Colors.grey)),
            TextField(controller: baseSalaryCont, decoration: const InputDecoration(labelText: "الراتب الأساسي"), keyboardType: TextInputType.number),
            TextField(controller: allowancesCont, decoration: const InputDecoration(labelText: "إجمالي البدلات"), keyboardType: TextInputType.number),
            TextField(controller: insuranceCont, decoration: const InputDecoration(labelText: "خصم التأمينات"), keyboardType: TextInputType.number),
            TextField(controller: taxesCont, decoration: const InputDecoration(labelText: "خصم الضرائب"), keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('administrativeEmployees').doc(id).update({
                  'baseSalary': double.tryParse(baseSalaryCont.text) ?? 0,
                  'allowances': double.tryParse(allowancesCont.text) ?? 0,
                  'insurance': double.tryParse(insuranceCont.text) ?? 0,
                  'taxes': double.tryParse(taxesCont.text) ?? 0,
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A2C3D), foregroundColor: Colors.white),
              child: const Text("تحديث البيانات الخام"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

