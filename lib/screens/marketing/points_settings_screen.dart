import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PointsSettingsScreen extends StatefulWidget {
  const PointsSettingsScreen({super.key});

  @override
  State<PointsSettingsScreen> createState() => _PointsSettingsScreenState();
}

class _PointsSettingsScreenState extends State<PointsSettingsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Controllers لضمان التعامل السليم مع الحقول الرقمية
  final TextEditingController _pointsReqCtrl = TextEditingController();
  final TextEditingController _cashEquivCtrl = TextEditingController();
  final TextEditingController _minPointsCtrl = TextEditingController();

  @override
  void dispose() {
    _pointsReqCtrl.dispose();
    _cashEquivCtrl.dispose();
    _minPointsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBFC),
      appBar: AppBar(
        title: const Text('إعدادات نظام النقاط', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('appSettings').doc('points').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("حدث خطأ في الاتصال"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // إذا كانت الوثيقة موجودة، نملأ الحقول مبدئياً
          if (snapshot.hasData && snapshot.data!.exists) {
            var data = snapshot.data!.data() as Map<String, dynamic>;
            var convRate = data['conversionRate'] ?? {};
            
            // تحديث قيم النصوص فقط إذا كانت فارغة (حتى لا نقاطع كتابة المستخدم)
            if (_pointsReqCtrl.text.isEmpty) _pointsReqCtrl.text = convRate['pointsRequired']?.toString() ?? '';
            if (_cashEquivCtrl.text.isEmpty) _cashEquivCtrl.text = convRate['cashEquivalent']?.toString() ?? '';
            if (_minPointsCtrl.text.isEmpty) _minPointsCtrl.text = convRate['minPointsForRedemption']?.toString() ?? '';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(Icons.auto_graph, "معدل التحويل الأساسي"),
                _buildCardContainer([
                  _buildInputField(_pointsReqCtrl, "عدد النقاط المطلوبة للاستبدال"),
                  _buildInputField(_cashEquivCtrl, "المبلغ النقدي المقابل (جنيه)"),
                  _buildInputField(_minPointsCtrl, "الحد الأدنى للنقاط لبدء الاستبدال"),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveConversionRate,
                      icon: const Icon(Icons.save),
                      label: const Text("حفظ الإعدادات الأساسية"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 30),
                _buildSectionHeader(Icons.rule, "قواعد كسب النقاط المضافة"),
                _buildPlaceholderCard("سيتم عرض القواعد الديناميكية هنا قريباً"),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInputField(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        keyboardType: TextInputType.number,
      ),
    );
  }

  Widget _buildPlaceholderCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
      ),
      child: Center(child: Text(text, style: const TextStyle(color: Colors.grey, fontFamily: 'Cairo'))),
    );
  }

  Future<void> _saveConversionRate() async {
    try {
      await _db.collection('appSettings').doc('points').set({
        'conversionRate': {
          'pointsRequired': double.tryParse(_pointsReqCtrl.text) ?? 0,
          'cashEquivalent': double.tryParse(_cashEquivCtrl.text) ?? 0,
          'minPointsForRedemption': double.tryParse(_minPointsCtrl.text) ?? 0,
        }
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تحديث البيانات بنجاح")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ أثناء الحفظ: $e")));
      }
    }
  }
}

