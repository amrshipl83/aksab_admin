import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PendingFreeDriversTab extends StatelessWidget {
  const PendingFreeDriversTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('pendingFreeDrivers').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("حدث خطأ في جلب البيانات"));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("لا توجد طلبات انتظار حالياً", style: TextStyle(fontFamily: 'Cairo')));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            return _buildDriverRequestCard(context, doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildDriverRequestCard(BuildContext context, String uid, Map<String, dynamic> data) {
    String vehicleName = data['vehicleConfig'] == 'motorcycleConfig'
        ? "موتوسيكل"
        : (data['vehicleConfig'] == 'pickupConfig' ? "بيك أب" : "جامبو");

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF43B97F),
          child: Icon(Icons.motorcycle, color: Colors.white),
        ),
        title: Text(data['fullname'] ?? 'بدون اسم',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        subtitle: Text("مركبة: $vehicleName | هاتف: ${data['phone']}",
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.location_on, "العنوان: ${data['address']}"),
                _infoRow(Icons.email, "الإيميل: ${data['email']}"),
                const Divider(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _rejectDriver(context, uid),
                      child: const Text("رفض الطلب", style: TextStyle(color: Colors.red, fontFamily: 'Cairo')),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _approveDriver(context, uid, data),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF43B97F),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("تفعيل الحساب", style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
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

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13))),
        ],
      ),
    );
  }

  // منطق الرفض
  void _rejectDriver(BuildContext context, String uid) async {
    bool? confirm = await _showDialog(context, "حذف الطلب نهائياً؟");
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('pendingFreeDrivers').doc(uid).delete();
    }
  }

  // منطق القبول المحدث (بدون ثوابت صلبة)
  void _approveDriver(BuildContext context, String uid, Map<String, dynamic> data) async {
    // كونتولر للتحكم في القيمة يدوياً من قبل الأدمن
    final TextEditingController limitController = TextEditingController(text: "50");

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تفعيل حساب مندوب", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("حدد حد المديونية المسموح به لهذا المندوب:", 
              textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
            const SizedBox(height: 20),
            TextField(
              controller: limitController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              decoration: InputDecoration(
                suffixText: "ج.م",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF43B97F)),
            child: const Text("تأكيد التفعيل", style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      double finalLimit = double.tryParse(limitController.text) ?? 50.0;

      try {
        await FirebaseFirestore.instance.collection('freeDrivers').doc(uid).set({
          ...data,
          'status': "approved",
          'walletBalance': 0.0,      // تهيئة المحفظة بصفر كاش فعلي
          'creditLimit': finalLimit, // القيمة الديناميكية التي أدخلها الأدمن
          'approvedAt': FieldValue.serverTimestamp(),
          'totalOrders': 0,
          'isOnline': false,
        });

        // حذف من قائمة الانتظار بعد النقل بنجاح
        await FirebaseFirestore.instance.collection('pendingFreeDrivers').doc(uid).delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("تم تفعيل ${data['fullname']} بحد $finalLimit ج.م ✅"), backgroundColor: Colors.green)
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ أثناء التفعيل: $e"), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<bool?> _showDialog(BuildContext context, String msg) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo'), textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("تأكيد")),
        ],
      ),
    );
  }
}

