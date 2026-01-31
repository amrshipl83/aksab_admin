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

  Stream<QuerySnapshot> _getPlans() {
    return _db.collection('subscription_settings').orderBy('price').snapshots();
  }

  Future<void> _updateFeature(String docId, String featureKey, dynamic newValue) async {
    try {
      DocumentSnapshot doc = await _db.collection('subscription_settings').doc(docId).get();
      List features = List.from(doc['features']);
      
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
      body: Localizations.override(
        context: context,
        locale: const Locale('ar', 'EG'),
        child: StreamBuilder<QuerySnapshot>(
          stream: _getPlans(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
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
              child: Text(plan['planName'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(15),
              children: [
                _buildPriceInfo(plan['price'].toString()),
                const Divider(),
                ...(plan['features'] as List).map((feature) {
                  return _buildFeatureToggle(id, feature);
                }).toList(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text("ID: $id", style: const TextStyle(fontSize: 10, color: Colors.grey)),
          )
        ],
      ),
    );
  }

  Widget _buildPriceInfo(String price) {
    return ListTile(
      title: const Text("السعر المستحق", style: TextStyle(fontSize: 13, fontFamily: 'Cairo')),
      subtitle: Text("$price EGP", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
      leading: const Icon(Icons.monetization_on, color: Colors.amber),
    );
  }

  Widget _buildFeatureToggle(String docId, Map<String, dynamic> feature) {
    bool isEnabled = (feature['value'] is bool) ? feature['value'] : (feature['value'] > 0);

    return SwitchListTile(
      title: Text(feature['label'], style: const TextStyle(fontSize: 13, fontFamily: 'Cairo')),
      value: isEnabled,
      activeColor: Colors.green,
      onChanged: (val) {
        dynamic newValue = (feature['value'] is int) ? (val ? 1 : 0) : val;
        _updateFeature(docId, feature['key'], newValue);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("لا توجد باقات حالياً", style: TextStyle(fontFamily: 'Cairo', fontSize: 18)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _createDefaultPlans,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB21F2D)),
            child: const Text("إنشاء الباقات الافتراضية", style: TextStyle(color: Colors.white)),
          ),
        ],
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
