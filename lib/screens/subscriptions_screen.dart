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

  // دالة لجلب الباقات الحالية من الفايرستور
  Stream<QuerySnapshot> _getPlans() {
    return _db.collection('subscription_settings').orderBy('price').snapshots();
  }

  // دالة لتحديث قيمة معينة في الباقة (ديناميكياً)
  Future<void> _updateFeature(String docId, String featureKey, dynamic newValue) async {
    try {
      // جلب الوثيقة أولاً لتعديل المصفوفة بداخلها
      DocumentSnapshot doc = await _db.collection('subscription_settings').doc(docId).get();
      List features = doc['features'];
      
      // البحث عن العنصر وتعديله
      for (var f in features) {
        if (f['key'] == featureKey) {
          f['value'] = newValue;
        }
      }

      await _db.collection('subscription_settings').doc(docId).update({'features': features});
      _showSnackBar("تم التحديث بنجاح", Colors.green);
    } catch (e) {
      _showSnackBar("خطأ في التحديث: $e", Colors.red);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
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
                crossAxisCount: 3, // 3 باقات بجانب بعض في الويب
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
        boxShadow: const [BoxShadow(color: Colors.black10, blurRadius: 10)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: plan['planName'] == 'الذهبية' ? const Color(0xFFB21F2D) : const Color(0xFF2c3e50),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Center(
              child: Text(plan['planName'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(15),
              children: [
                _buildEditableRow("السعر (EGP)", plan['price'].toString(), (val) {
                   _db.collection('subscription_settings').doc(id).update({'price': double.parse(val)});
                }),
                const Divider(),
                // عرض المميزات الديناميكية
                ...(plan['features'] as List).map((feature) {
                  return _buildFeatureToggle(id, feature);
                }).toList(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Text("معرف الباقة: $id", style: const TextStyle(fontSize: 10, color: Colors.grey)),
          )
        ],
      ),
    );
  }

  Widget _buildEditableRow(String label, String value, Function(String) onSave) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
      trailing: IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () {
        // هنا تفتح Dialog لتعديل السعر
      }),
    );
  }

  Widget _buildFeatureToggle(String docId, Map<String, dynamic> feature) {
    bool isEnabled = feature['value'] is bool ? feature['value'] : (feature['value'] as int) > 0;

    return SwitchListTile(
      title: Text(feature['label'], style: const TextStyle(fontSize: 13)),
      value: isEnabled,
      activeColor: Colors.green,
      onChanged: (val) {
        // لو كانت ميزة رقمية (زي البانرات) بنخليها 1 أو 0، لو بولين بنخليها true/false
        dynamic newValue = feature['value'] is int ? (val ? 1 : 0) : val;
        _updateFeature(docId, feature['key'], newValue);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: ElevatedButton(
        onPressed: _createDefaultPlans,
        child: const Text("إنشاء الباقات الافتراضية لأول مرة"),
      ),
    );
  }

  // دالة لإنشاء بيانات تجريبية لو المجموعة فاضية
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
