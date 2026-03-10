import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});
  static const routeName = '/subscriptions';

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final _db = FirebaseFirestore.instance;

  // 🛠️ حوار إضافة باقة جديدة (الكتالوج اليدوي)
  Future<void> _showAddPlanDialog() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final durationController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text("إضافة باقة اشتراك جديدة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: "اسم الباقة (مثلاً: الباقة الذهبية)")),
                TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "السعر (EGP)")),
                TextField(controller: durationController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "المدة (بالأيام)")),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || priceController.text.isEmpty) return;
                await _db.collection('subscription_plans').add({
                  'planName': nameController.text.trim(),
                  'price': double.tryParse(priceController.text) ?? 0.0,
                  'durationDays': int.tryParse(durationController.text) ?? 30,
                  'features': [] // تبدأ بدون مميزات وتضيفها براحتك
                });
                Navigator.pop(context);
                _showSnackBar("تم إضافة الباقة بنجاح", Colors.green);
              },
              child: const Text("حفظ الباقة"),
            )
          ],
        ),
      ),
    );
  }

  // تحديث القيم الأساسية
  Future<void> _updateField(String docId, String field, dynamic value) async {
    await _db.collection('subscription_plans').doc(docId).update({field: value});
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    // 📱 تحديد عدد الأعمدة حسب حجم الشاشة
    double width = MediaQuery.of(context).size.width;
    int crossAxisCount = width > 1200 ? 4 : (width > 800 ? 3 : (width > 600 ? 2 : 1));

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة خطط الاشتراكات', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: const Color(0xFF2c3e50),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _showAddPlanDialog,
              icon: const Icon(Icons.add_business),
              label: const Text("إنشاء باقة جديدة"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: StreamBuilder<QuerySnapshot>(
          stream: _db.collection('subscription_plans').orderBy('price').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("لا توجد باقات حالياً"));

            return GridView.builder(
              padding: const EdgeInsets.all(15),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.85,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
              ),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var doc = snapshot.data!.docs[index];
                var plan = doc.data() as Map<String, dynamic>;
                return _buildResponsivePlanCard(doc.id, plan);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildResponsivePlanCard(String id, Map<String, dynamic> plan) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          // رأس الكارت - الاسم والسعر
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.blueGrey[800]!, Colors.blueGrey[600]!]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Text(plan['planName'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text("${plan['price']} EGP", style: const TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          // تفاصيل الباقة والمميزات
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                ListTile(
                  leading: const Icon(Icons.timer, color: Colors.orange),
                  title: const Text("المدة"),
                  subtitle: Text("${plan['durationDays']} يوم"),
                  onTap: () => _showEditValue(id, "المدة بالايام", 'durationDays', plan['durationDays']),
                ),
                const Divider(),
                const Text(" المميزات الفعالة:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ...(plan['features'] as List? ?? []).map((f) => CheckboxListTile(
                  title: Text(f['label'], style: const TextStyle(fontSize: 12)),
                  value: f['value'],
                  onChanged: (val) => _toggleFeature(id, f['key'], val!),
                )).toList(),
              ],
            ),
          ),
          // أزرار التحكم السفلى
          ButtonBar(
            alignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.edit_note, color: Colors.blue), onPressed: () => _showEditValue(id, "الاسم", 'planName', plan['planName'])),
              IconButton(icon: const Icon(Icons.add_task, color: Colors.green), onPressed: () => _addNewFeature(id)),
              IconButton(icon: const Icon(Icons.delete_forever, color: Colors.red), onPressed: () => _confirmDelete(id)),
            ],
          )
        ],
      ),
    );
  }

  // دالة تعديل سريعة
  void _showEditValue(String id, String label, String field, dynamic current) {
    final controller = TextEditingController(text: current.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("تعديل $label"),
        content: TextField(controller: controller, keyboardType: current is num ? TextInputType.number : TextInputType.text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          ElevatedButton(onPressed: () {
            _updateField(id, field, current is num ? (num.tryParse(controller.text) ?? current) : controller.text);
            Navigator.pop(ctx);
          }, child: const Text("حفظ")),
        ],
      ),
    );
  }

  // دوال الحذف والتبديل (نفس المنطق السابق مع تحسين الأداء)
  Future<void> _toggleFeature(String docId, String featureKey, bool newValue) async {
     DocumentSnapshot doc = await _db.collection('subscription_plans').doc(docId).get();
     List features = List.from(doc['features'] ?? []);
     for (var f in features) { if (f['key'] == featureKey) f['value'] = newValue; }
     await _db.collection('subscription_plans').doc(docId).update({'features': features});
  }

  Future<void> _addNewFeature(String id) async {
    String label = "";
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("إضافة ميزة للباقة"),
      content: TextField(onChanged: (v) => label = v, decoration: const InputDecoration(hintText: "مثلاً: دعم فني 24 ساعة")),
      actions: [
        ElevatedButton(onPressed: () async {
          if (label.isEmpty) return;
          await _db.collection('subscription_plans').doc(id).update({
            'features': FieldValue.arrayUnion([{'key': DateTime.now().toString(), 'label': label, 'value': true}])
          });
          Navigator.pop(ctx);
        }, child: const Text("إضافة"))
      ],
    ));
  }

  void _confirmDelete(String id) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("حذف الباقة"),
      content: const Text("هل أنت متأكد؟ لا يمكن التراجع."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
        TextButton(onPressed: () { _db.collection('subscription_plans').doc(id).delete(); Navigator.pop(ctx); }, child: const Text("حذف", style: TextStyle(color: Colors.red))),
      ],
    ));
  }
}

