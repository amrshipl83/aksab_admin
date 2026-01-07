import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PointsSettingsScreen extends StatefulWidget {
  const PointsSettingsScreen({super.key});

  @override
  State<PointsSettingsScreen> createState() => _PointsSettingsScreenState();
}

class _PointsSettingsScreenState extends State<PointsSettingsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // المتحكمات للنصوص (Controllers)
  final TextEditingController _pointsReqCtrl = TextEditingController();
  final TextEditingController _cashEquivCtrl = TextEditingController();
  final TextEditingController _minPointsCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات نظام النقاط', style: TextStyle(fontFamily: 'Tajawal')),
        backgroundColor: const Color(0xFF4CAF50),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('appSettings').doc('points').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("حدث خطأ ما"));
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("لا توجد بيانات، ابدأ بإضافة الإعدادات"));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          var convRate = data['conversionRate'] ?? {};
          
          // تحديث الحقول إذا لم تكن قيد التعديل
          _pointsReqCtrl.text = convRate['pointsRequired']?.toString() ?? '';
          _cashEquivCtrl.text = convRate['cashEquivalent']?.toString() ?? '';
          _minPointsCtrl.text = convRate['minPointsForRedemption']?.toString() ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(Icons.swap_horiz, "معدل تحويل النقاط"),
                _buildConversionSection(),
                const SizedBox(height: 30),
                
                _buildHeader(Icons.Add_chart, "قواعد كسب النقاط"),
                _buildDynamicList(data['earningRules'] ?? [], "قواعد كسب"),
                
                const SizedBox(height: 30),
                _buildHeader(Icons.policy, "سياسة الاستبدال"),
                _buildDynamicList(data['redemptionPolicies'] ?? [], "سياسات"),
              ],
            ),
          );
        },
      ),
    );
  }

  // بخش بناء رؤوس الأقسام بنفس ستايل الـ CSS
  Widget _buildHeader(IconData icon, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFFFFC107)),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF388E3C))),
          ],
        ),
        const Divider(thickness: 2),
        const SizedBox(height: 15),
      ],
    );
  }

  // قسم معدل التحويل
  Widget _buildConversionSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            _buildTextField(_pointsReqCtrl, "عدد النقاط المطلوبة"),
            _buildTextField(_cashEquivCtrl, "المبلغ النقدي المقابل"),
            _buildTextField(_minPointsCtrl, "الحد الأدنى للاستبدال"),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _saveConversionRate,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
              child: const Text("حفظ معدل التحويل", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        keyboardType: TextInputType.number,
      ),
    );
  }

  // قائمة العناصر الديناميكية (مثل القواعد والسياسات)
  Widget _buildDynamicList(List items, String type) {
    return Column(
      children: [
        ...items.map((item) => Card(
          child: ListTile(
            title: Text(item['name'] ?? item['text_ar'] ?? "بدون عنوان"),
            subtitle: Text(item['type'] ?? "ترتيب: ${item['order']}"),
            trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () {}),
            leading: Icon(Icons.circle, size: 12, color: item['isActive'] == false ? Colors.red : Colors.green),
          ),
        )).toList(),
        TextButton.icon(
          onPressed: () {}, 
          icon: const Icon(Icons.add), 
          label: Text("إضافة $type جديدة")
        ),
      ],
    );
  }

  // دالة الحفظ
  Future<void> _saveConversionRate() async {
    try {
      await _db.collection('appSettings').doc('points').set({
        'conversionRate': {
          'pointsRequired': double.tryParse(_pointsReqCtrl.text) ?? 0,
          'cashEquivalent': double.tryParse(_cashEquivCtrl.text) ?? 0,
          'minPointsForRedemption': double.tryParse(_minPointsCtrl.text) ?? 0,
        }
      }, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الحفظ بنجاح")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    }
  }
}

