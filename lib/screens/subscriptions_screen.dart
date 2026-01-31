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

  // دالة جلب البيانات
  Stream<QuerySnapshot> _getPlans() {
    return _db.collection('subscription_settings').orderBy('price').snapshots();
  }

  // دالة تحديث الحقول الأساسية (مثل السعر أو اسم الباقة)
  Future<void> _updateBasicField(String docId, String fieldName, dynamic newValue) async {
    try {
      await _db.collection('subscription_settings').doc(docId).update({fieldName: newValue});
      _showSnackBar("تم تحديث $fieldName بنجاح", Colors.green);
    } catch (e) {
      _showSnackBar("خطأ في التحديث: $e", Colors.red);
    }
  }

  // دالة تحديث المميزات داخل المصفوفة (Features Array)
  Future<void> _updateFeatureValue(String docId, String featureKey, dynamic newValue) async {
    try {
      DocumentSnapshot doc = await _db.collection('subscription_settings').doc(docId).get();
      List features = List.from(doc['features']);
      
      for (var f in features) {
        if (f['key'] == featureKey) {
          f['value'] = newValue;
        }
      }

      await _db.collection('subscription_settings').doc(docId).update({'features': features});
      _showSnackBar("تم تحديث الميزة بنجاح", Colors.green);
    } catch (e) {
      _showSnackBar("خطأ في التحديث: $e", Colors.red);
    }
  }

  // نافذة منبثقة لتعديل القيم النصية أو الرقمية
  void _showEditDialog(String docId, String title, dynamic currentValue, Function(dynamic) onConfirm) {
    TextEditingController controller = TextEditingController(text: currentValue.toString());
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text("تعديل $title", style: const TextStyle(fontFamily: 'Cairo')),
          content: TextFormField(
            controller: controller,
            decoration: const InputDecoration(border: OutlineInputBorder()),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text('إدارة باقات اشتراك المنصة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFB21F2D),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: StreamBuilder<QuerySnapshot>(
          stream: _getPlans(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

            return GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, 
                childAspectRatio: 0.7,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Column(
        children: [
          // رأس الكارت (اسم الباقة قابل للتعديل)
          InkWell(
            onTap: () => _showEditDialog(id, "اسم الباقة", plan['planName'], (v) => _updateBasicField(id, 'planName', v)),
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: plan['planName'] == 'الذهبية' ? const Color(0xFFB21F2D) : const Color(0xFF2c3e50),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Center(
                child: Text(plan['planName'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(15),
              children: [
                // تعديل السعر
                _buildEditableTile("السعر المستحق", "${plan['price']} EGP", Icons.monetization_on, () {
                  _showEditDialog(id, "السعر", plan['price'], (v) => _updateBasicField(id, 'price', v));
                }),
                // تعديل المدة
                _buildEditableTile("مدة الباقة (أيام)", "${plan['durationDays']} يوم", Icons.timer, () {
                  _showEditDialog(id, "عدد الأيام", plan['durationDays'], (v) => _updateBasicField(id, 'durationDays', v));
                }),
                const Divider(),
                // قائمة المميزات
                ...(plan['features'] as List).map((feature) {
                  return _buildFeatureControl(id, feature);
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableTile(String label, String value, IconData icon, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      title: Text(label, style: const TextStyle(fontSize: 12, fontFamily: 'Cairo', color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
      leading: Icon(icon, color: const Color(0xFFB21F2D)),
      trailing: const Icon(Icons.edit, size: 16, color: Colors.blue),
    );
  }

  Widget _buildFeatureControl(String docId, Map<String, dynamic> feature) {
    bool isBool = feature['value'] is bool;

    if (isBool) {
      return SwitchListTile(
        title: Text(feature['label'], style: const TextStyle(fontSize: 13, fontFamily: 'Cairo')),
        value: feature['value'],
        onChanged: (val) => _updateFeatureValue(docId, feature['key'], val),
      );
    } else {
      // ميزة رقمية (مثل عدد البانرات)
      return ListTile(
        onTap: () => _showEditDialog(docId, feature['label'], feature['value'], (v) => _updateFeatureValue(docId, feature['key'], v)),
        title: Text(feature['label'], style: const TextStyle(fontSize: 13, fontFamily: 'Cairo')),
        trailing: Text(feature['value'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        leading: const Icon(Icons.add_task, size: 20),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: ElevatedButton(
        onPressed: _createDefaultPlans,
        child: const Text("تأسيس نظام الباقات لأول مرة"),
      ),
    );
  }

  Future<void> _createDefaultPlans() async {
    List<Map<String, dynamic>> defaults = [
      {
        'planName': 'التجريبية',
        'price': 0.0,
        'durationDays': 7,
        'features': [
          {'key': 'delivery', 'label': 'خدمة الدليفري', 'value': true},
          {'key': 'banners', 'label': 'بانرات إعلانية', 'value': 0},
        ]
      },
      {
        'planName': 'الذهبية',
        'price': 1500.0,
        'durationDays': 30,
        'features': [
          {'key': 'delivery', 'label': 'خدمة الدليفري', 'value': true},
          {'key': 'banners', 'label': 'بانرات إعلانية', 'value': 5},
        ]
      }
    ];

    for (var plan in defaults) {
      await _db.collection('subscription_settings').add(plan);
    }
  }
}
