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

  String _generateId() => 'id_${Random().nextInt(1000000)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text('إعدادات نظام النقاط',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
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
                  title: "معدل تحويل النقاط (الاستبدال)",
                  icon: Icons.currency_exchange,
                  child: Column(
                    children: [
                      _buildTextField(_pointsReqCtrl, "عدد النقاط المطلوبة للاستبدال"),
                      _buildTextField(_cashEquivCtrl, "المبلغ النقدي المقابل (جنيه)"),
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
                  title: "قواعد كسب النقاط (Earning Rules)",
                  icon: Icons.add_chart,
                  child: Column(
                    children: [
                      ...earningRules.map((rule) => _buildListItem(
                            title: rule['name'],
                            subtitle: "${rule['value']} نقطة - النوع: ${rule['type']}",
                            onDelete: () => _deleteItem('earningRules', rule['id'], earningRules),
                            onEdit: () => _showAddRuleDialog(earningRules, existingRule: rule),
                          )),
                      const SizedBox(height: 10),
                      _buildAddButton("إضافة قاعدة كسب جديدة", () => _showAddRuleDialog(earningRules)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. قسم نصوص السياسة
                _buildSectionCard(
                  title: "سياسة الاستبدال والشروط",
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

  // --- Widgets مساعدة ---

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
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF388E3C))),
            ],
          ),
          const Divider(),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildListItem({required String title, required String subtitle, required VoidCallback onDelete, VoidCallback? onEdit}) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEdit != null) IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: onEdit),
          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: onDelete),
        ],
      ),
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

  // --- دوال التحكم في البيانات ---

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

  // --- الحوار المطور لإضافة وتعديل القواعد ---

  void _showAddRuleDialog(List currentRules, {Map<String, dynamic>? existingRule}) {
    String name = existingRule?['name'] ?? "";
    double value = (existingRule?['value'] ?? 0).toDouble();
    String selectedType = existingRule?['type'] ?? 'per_currency_unit';
    bool isActive = existingRule?['isActive'] ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existingRule == null ? "إضافة قاعدة كسب" : "تعديل قاعدة"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: TextEditingController(text: name)..selection = TextSelection.collapsed(offset: name.length),
                  onChanged: (v) => name = v,
                  decoration: const InputDecoration(labelText: "اسم القاعدة"),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: TextEditingController(text: value.toString()),
                  onChanged: (v) => value = double.tryParse(v) ?? 0,
                  decoration: const InputDecoration(labelText: "قيمة النقاط"),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: "نوع العملية", border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'per_currency_unit', child: Text("نقاط مقابل كل جنيه")),
                    DropdownMenuItem(value: 'on_new_customer_registration', child: Text("هدية تسجيل جديد")),
                  ],
                  onChanged: (v) => setDialogState(() => selectedType = v!),
                ),
                SwitchListTile(
                  title: const Text("تفعيل القاعدة"),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: () async {
                List newList = List.from(currentRules);
                var ruleData = {
                  'id': existingRule?['id'] ?? _generateId(),
                  'name': name,
                  'value': value,
                  'type': selectedType,
                  'isActive': isActive
                };

                if (existingRule == null) {
                  newList.add(ruleData);
                } else {
                  int index = newList.indexWhere((r) => r['id'] == existingRule['id']);
                  newList[index] = ruleData;
                }

                await _db.collection('appSettings').doc('points').update({'earningRules': newList});
                Navigator.pop(context);
              },
              child: const Text("حفظ"),
            )
          ],
        ),
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

