import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class PointsSettingsScreen extends StatefulWidget {
  const PointsSettingsScreen({super.key});

  @override
  State<PointsSettingsScreen> createState() => _PointsSettingsScreenState();
}

class _PointsSettingsScreenState extends State<PointsSettingsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Controllers للمعدلات الأساسية
  final TextEditingController _pointsReqCtrl = TextEditingController();
  final TextEditingController _cashEquivCtrl = TextEditingController();
  final TextEditingController _minPointsCtrl = TextEditingController();

  // دالة لتوليد ID فريد كما في كود الـ JavaScript
  String _generateId() => 'id_${Random().nextInt(1000000)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text('إعدادات نظام النقاط', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF4CAF50),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('appSettings').doc('points').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          var conversionRate = data['conversionRate'] ?? {};
          List earningRules = data['earningRules'] ?? [];
          List policies = data['redemptionPolicies'] ?? [];

          // تعبئة البيانات الأساسية مرة واحدة
          if (_pointsReqCtrl.text.isEmpty) {
            _pointsReqCtrl.text = conversionRate['pointsRequired']?.toString() ?? '';
            _cashEquivCtrl.text = conversionRate['cashEquivalent']?.toString() ?? '';
            _minPointsCtrl.text = conversionRate['minPointsForRedemption']?.toString() ?? '';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 1. قسم معدل التحويل
                _buildSectionCard(
                  title: "معدل تحويل النقاط",
                  icon: Icons.currency_exchange,
                  child: Column(
                    children: [
                      _buildTextField(_pointsReqCtrl, "عدد النقاط المطلوبة للاستبدال"),
                      _buildTextField(_cashEquivCtrl, "المبلغ النقدي المقابل"),
                      _buildTextField(_minPointsCtrl, "الحد الأدنى للاستبدال"),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _saveConversionRate,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF388E3C)),
                        child: const Text("حفظ معدل التحويل", style: TextStyle(color: Colors.white)),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2. قسم قواعد كسب النقاط
                _buildSectionCard(
                  title: "قواعد كسب النقاط",
                  icon: Icons.add_chart,
                  child: Column(
                    children: [
                      ...earningRules.map((rule) => _buildListItem(
                        title: rule['name'],
                        subtitle: "${rule['value']} نقطة - ${rule['type']}",
                        onDelete: () => _deleteItem('earningRules', rule['id'], earningRules),
                      )),
                      const SizedBox(height: 10),
                      _buildAddButton("إضافة قاعدة كسب", () => _showAddRuleDialog(earningRules)),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. قسم نصوص السياسة
                _buildSectionCard(
                  title: "سياسة الاستبدال",
                  icon: Icons.description,
                  child: Column(
                    children: [
                      ...policies.map((policy) => _buildListItem(
                        title: policy['text_ar'],
                        subtitle: "الترتيب: ${policy['order']}",
                        onDelete: () => _deleteItem('redemptionPolicies', policy['id'], policies),
                      )),
                      const SizedBox(height: 10),
                      _buildAddButton("إضافة بند سياسة", () => _showAddPolicyDialog(policies)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Widgets مساعدة لبناء الواجهة ---

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFFC107)),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF388E3C))),
            ],
          ),
          const Divider(),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildListItem({required String title, required String subtitle, required VoidCallback onDelete}) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: onDelete),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildAddButton(String label, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2196F3)),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        keyboardType: TextInputType.number,
      ),
    );
  }

  // --- دوال التحكم في البيانات (Firebase) ---

  Future<void> _saveConversionRate() async {
    await _db.collection('appSettings').doc('points').set({
      'conversionRate': {
        'pointsRequired': double.tryParse(_pointsReqCtrl.text) ?? 0,
        'cashEquivalent': double.tryParse(_cashEquivCtrl.text) ?? 0,
        'minPointsForRedemption': double.tryParse(_minPointsCtrl.text) ?? 0,
      }
    }, SetOptions(merge: true));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حفظ المعدل")));
  }

  Future<void> _deleteItem(String field, String id, List currentList) async {
    List newList = currentList.where((item) => item['id'] != id).toList();
    await _db.collection('appSettings').doc('points').update({field: newList});
  }

  // --- النوافذ المنبثقة (Dialogs) كما في الـ HTML Form ---

  void _showAddRuleDialog(List currentRules) {
    String name = "";
    double value = 0;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("إضافة قاعدة كسب"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(onChanged: (v) => name = v, decoration: const InputDecoration(labelText: "اسم القاعدة")),
            TextField(onChanged: (v) => value = double.tryParse(v) ?? 0, decoration: const InputDecoration(labelText: "قيمة النقاط")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () async {
              var newRule = {'id': _generateId(), 'name': name, 'value': value, 'type': 'per_currency_unit', 'isActive': true};
              await _db.collection('appSettings').doc('points').update({'earningRules': [...currentRules, newRule]});
              Navigator.pop(context);
            },
            child: const Text("إضافة"),
          )
        ],
      ),
    );
  }

  void _showAddPolicyDialog(List currentPolicies) {
    String textAr = "";
    int order = 1;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("إضافة بند سياسة"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(onChanged: (v) => textAr = v, decoration: const InputDecoration(labelText: "النص بالعربية")),
            TextField(onChanged: (v) => order = int.tryParse(v) ?? 1, decoration: const InputDecoration(labelText: "الترتيب")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () async {
              var newPolicy = {'id': _generateId(), 'text_ar': textAr, 'order': order};
              await _db.collection('appSettings').doc('points').update({'redemptionPolicies': [...currentPolicies, newPolicy]});
              Navigator.pop(context);
            },
            child: const Text("إضافة"),
          )
        ],
      ),
    );
  }
}

