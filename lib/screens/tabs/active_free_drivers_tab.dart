import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ActiveFreeDriversTab extends StatelessWidget {
  const ActiveFreeDriversTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('freeDrivers').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("خطأ في جلب البيانات"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("لا يوجد مناديب أحرار معتمدين حالياً", style: TextStyle(fontFamily: 'Cairo')));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            return _buildDriverCard(context, doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildDriverCard(BuildContext context, String uid, Map<String, dynamic> data) {
    // تنسيق عرض الرصيد
    double balance = (data['walletBalance'] ?? 0).toDouble();
    String vehicle = data['vehicleConfig'] == 'motorcycleConfig' ? "موتوسيكل" : (data['vehicleConfig'] == 'pickupConfig' ? "بيك أب" : "جامبو");
    bool isOnline = data['isOnline'] ?? false;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        leading: Stack(
          alignment: Alignment.bottomRight,
          children: [
            const CircleAvatar(backgroundColor: Color(0xFF1A2C3D), child: Icon(Icons.person, color: Colors.white)),
            CircleAvatar(radius: 6, backgroundColor: isOnline ? Colors.green : Colors.grey),
          ],
        ),
        title: Text(data['fullname'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        subtitle: Text("الرصيد: $balance ج.م | $vehicle", 
          style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: balance < 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildInfoRow(Icons.phone, "رقم الهاتف", data['phone'] ?? ''),
                _buildInfoRow(Icons.email, "البريد الذكي", data['email'] ?? ''),
                _buildInfoRow(Icons.location_on, "العنوان", data['address'] ?? ''),
                _buildInfoRow(Icons.credit_card, "حد الائتمان الحالي", data['creditLimit']?.toString() ?? "الافتراضي (50)"),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // زر تعديل الائتمان
                    ElevatedButton.icon(
                      onPressed: () => _editCreditLimit(context, uid, data['creditLimit']),
                      icon: const Icon(Icons.edit_road, size: 18),
                      label: const Text("تعديل الائتمان", style: TextStyle(fontFamily: 'Cairo')),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
                    ),
                    // زر إيقاف/تفعيل الحساب
                    ElevatedButton.icon(
                      onPressed: () => _toggleAccountStatus(context, uid, data['status']),
                      icon: Icon(data['status'] == 'approved' ? Icons.block : Icons.check_circle, size: 18),
                      label: Text(data['status'] == 'approved' ? "إيقاف الحساب" : "تفعيل الحساب", style: const TextStyle(fontFamily: 'Cairo')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: data['status'] == 'approved' ? Colors.red.shade700 : Colors.green.shade700,
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Text("$label: ", style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  // دالة تعديل حد الائتمان
  void _editCreditLimit(BuildContext context, String uid, dynamic currentLimit) {
    final controller = TextEditingController(text: currentLimit?.toString() ?? "");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تعديل حد الائتمان", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: "مثال: 100 (اتركه فارغاً للافتراضي)", hintStyle: TextStyle(fontSize: 12)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () async {
              dynamic newLimit = controller.text.isEmpty ? null : double.tryParse(controller.text);
              await FirebaseFirestore.instance.collection('freeDrivers').doc(uid).update({'creditLimit': newLimit});
              Navigator.pop(ctx);
            },
            child: const Text("حفظ التعديل"),
          )
        ],
      ),
    );
  }

  // دالة إيقاف أو تفعيل الحساب
  void _toggleAccountStatus(BuildContext context, String uid, String currentStatus) async {
    String newStatus = (currentStatus == 'approved') ? 'suspended' : 'approved';
    String msg = (newStatus == 'suspended') ? "هل أنت متأكد من إيقاف حساب المندوب؟" : "هل تريد إعادة تفعيل الحساب؟";
    
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo'), textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("تراجع")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("تأكيد")),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('freeDrivers').doc(uid).update({'status': newStatus});
    }
  }
}

