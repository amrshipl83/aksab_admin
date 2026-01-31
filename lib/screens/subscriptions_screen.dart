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

  // 1. إضافة باقة جديدة
  Future<void> _addNewPlan() async {
    try {
      await _db.collection('subscription_plans').add({
        'planName': 'باقة جديدة',
        'price': 100.0,
        'durationDays': 30,
        'features': [
          {'key': 'default', 'label': 'ميزة افتراضية', 'value': true}
        ]
      });
      _showSnackBar("تم إضافة باقة جديدة", Colors.green);
    } catch (e) {
      _showSnackBar("خطأ: $e", Colors.red);
    }
  }

  // 2. حذف باقة
  Future<void> _deletePlan(String docId) async {
    try {
      await _db.collection('subscription_plans').doc(docId).delete();
      _showSnackBar("تم حذف الباقة", Colors.orange);
    } catch (e) {
      _showSnackBar("خطأ في الحذف", Colors.red);
    }
  }

  // 3. إضافة ميزة جديدة
  Future<void> _addNewFeature(String docId) async {
    String label = "";
    await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text("إضافة ميزة جديدة", style: TextStyle(fontFamily: 'Cairo')),
          content: TextField(
            decoration: const InputDecoration(hintText: "اسم الميزة"),
            onChanged: (v) => label = v,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: () async {
                if (label.isEmpty) return;
                DocumentSnapshot doc = await _db.collection('subscription_plans').doc(docId).get();
                List features = List.from(doc['features'] ?? []);
                features.add({
                  'key': DateTime.now().millisecondsSinceEpoch.toString(),
                  'label': label,
                  'value': false 
                });
                await _db.collection('subscription_plans').doc(docId).update({'features': features});
                Navigator.pop(context);
              },
              child: const Text("إضافة"),
            )
          ],
        ),
      ),
    );
  }

  // 4. تحديث حقل أساسي
  Future<void> _updateBasicField(String docId, String fieldName, dynamic newValue) async {
    try {
      await _db.collection('subscription_plans').doc(docId).update({fieldName: newValue});
    } catch (e) {
      _showSnackBar("خطأ في التحديث", Colors.red);
    }
  }

  // 5. تحديث ميزة
  Future<void> _updateFeatureValue(String docId, String featureKey, dynamic newValue) async {
    try {
      DocumentSnapshot doc = await _db.collection('subscription_plans').doc(docId).get();
      List features = List.from(doc['features'] ?? []);
      for (var f in features) {
        if (f['key'] == featureKey) { f['value'] = newValue; }
      }
      await _db.collection('subscription_plans').doc(docId).update({'features': features});
    } catch (e) {
      _showSnackBar("خطأ في تحديث الميزة", Colors.red);
    }
  }

  // 6. حوار التعديل
  void _showEditDialog(String docId, String title, dynamic currentValue, Function(dynamic) onConfirm) {
    TextEditingController controller = TextEditingController(text: currentValue.toString());
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text("تعديل $title"),
          content: TextFormField(
            controller: controller,
            keyboardType: currentValue is num ? TextInputType.number : TextInputType.text,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: () {
                dynamic val = controller.text;
                if (currentValue is num) val = num.tryParse(controller.text) ?? currentValue;
                onConfirm(val);
                Navigator.pop(context);
              },
              child: const Text("حفظ"),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة باقات الاشتراك', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: const Color(0xFFB21F2D),
        actions: [
          ElevatedButton.icon(
            onPressed: _addNewPlan,
            icon: const Icon(Icons.add),
            label: const Text("إضافة باقة"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: StreamBuilder<QuerySnapshot>(
          stream: _db.collection('subscription_plans').orderBy('price').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("لا توجد باقات. اضغط إضافة باقة"));

            return GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, 
                childAspectRatio: 0.75,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var doc = snapshot.data!.docs[index];
                var plan = doc.data() as Map<String, dynamic>;
                return _buildPlanEditorCard(doc.id, plan);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlanEditorCard(String id, Map<String, dynamic> plan) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF2c3e50),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showEditDialog(id, "الاسم", plan['planName'], (v) => _updateBasicField(id, 'planName', v)),
                    child: Text(plan['planName'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20), onPressed: () => _deletePlan(id)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(15),
              children: [
                _buildEditableTile("السعر", "${plan['price']} EGP", () => _showEditDialog(id, "السعر", plan['price'], (v) => _updateBasicField(id, 'price', v))),
                _buildEditableTile("المدة (أيام)", "${plan['durationDays']}", () => _showEditDialog(id, "المدة", plan['durationDays'], (v) => _updateBasicField(id, 'durationDays', v))),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("المميزات:", style: TextStyle(fontWeight: FontWeight.bold)),
                    TextButton(onPressed: () => _addNewFeature(id), child: const Text("+ إضافة ميزة")),
                  ],
                ),
                ...(plan['features'] as List? ?? []).map((f) => _buildFeatureControl(id, f)).toList(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEditableTile(String label, String value, VoidCallback onTap) {
    return ListTile(
      dense: true,
      onTap: onTap,
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      trailing: const Icon(Icons.edit, size: 14),
    );
  }

  Widget _buildFeatureControl(String docId, Map<String, dynamic> feature) {
    return SwitchListTile(
      dense: true,
      title: Text(feature['label'] ?? "", style: const TextStyle(fontSize: 13)),
      value: feature['value'] ?? false,
      onChanged: (val) => _updateFeatureValue(docId, feature['key'], val),
    );
  }
}
