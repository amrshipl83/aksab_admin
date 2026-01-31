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

  // 1. إضافة باقة جديدة تماماً بقيم افتراضية
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
      _showSnackBar("تم إضافة باقة جديدة، يمكنك تعديلها الآن", Colors.green);
    } catch (e) {
      _showSnackBar("خطأ في إضافة الباقة", Colors.red);
    }
  }

  // 2. حذف باقة (اختياري)
  Future<void> _deletePlan(String docId) async {
    try {
      await _db.collection('subscription_plans').doc(docId).delete();
      _showSnackBar("تم حذف الباقة", Colors.orange);
    } catch (e) {
      _showSnackBar("خطأ في الحذف", Colors.red);
    }
  }

  // 3. إضافة ميزة جديدة لباقة معينة
  Future<void> _addNewFeature(String docId) async {
    String label = "";
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("إضافة ميزة جديدة", style: TextStyle(fontFamily: 'Cairo')),
        content: TextField(
          decoration: const InputDecoration(hintText: "مثلاً: دعم فني 24 ساعة"),
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
    );
  }

  // بقية الدوال (UpdateField, UpdateFeatureValue, EditDialog) كما هي في الكود السابق...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text('إدارة الباقات', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: const Color(0xFFB21F2D),
        actions: [
          // زر إضافة باقة جديدة في الـ AppBar
          TextButton.icon(
            onPressed: _addNewPlan,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text("إضافة باقة", style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
          )
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: StreamBuilder<QuerySnapshot>(
          stream: _db.collection('subscription_plans').orderBy('price').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            return GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, 
                childAspectRatio: 0.75,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
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
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            color: const Color(0xFF2c3e50),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showEditDialog(id, "الاسم", plan['planName'], (v) => _updateBasicField(id, 'planName', v)),
                    child: Text(plan['planName'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18), onPressed: () => _deletePlan(id)),
              ],
            ),
          ),
          // عرض السعر والمدة والمميزات وزر إضافة ميزة (نفس الكود السابق مع تجميل التصميم)...
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(10),
              children: [
                _buildEditableTile("السعر", "${plan['price']} EGP", () => _showEditDialog(id, "السعر", plan['price'], (v) => _updateBasicField(id, 'price', v))),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("المميزات:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    TextButton(onPressed: () => _addNewFeature(id), child: const Text("+ ميزة جديدة", style: TextStyle(fontSize: 11))),
                  ],
                ),
                ...(plan['features'] as List).map((f) => _buildFeatureControl(id, f)).toList(),
              ],
            ),
          )
        ],
      ),
    );
  }
}
