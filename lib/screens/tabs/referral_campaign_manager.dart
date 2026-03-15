import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReferralCampaignsScreen extends StatefulWidget {
  const ReferralCampaignsScreen({super.key});

  @override
  _ReferralCampaignsScreenState createState() => _ReferralCampaignsScreenState();
}

class _ReferralCampaignsScreenState extends State<ReferralCampaignsScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _orderNumController = TextEditingController();
  final TextEditingController _rewardController = TextEditingController();
  
  // خريطة لتخزين الأهداف (Milestones)
  Map<int, double> _milestones = {1: 20.0, 3: 50.0, 5: 100.0};
  bool _isPublishing = false;

  void _addMilestone() {
    if (_orderNumController.text.isNotEmpty && _rewardController.text.isNotEmpty) {
      setState(() {
        _milestones[int.parse(_orderNumController.text)] = double.parse(_rewardController.text);
        _orderNumController.clear();
        _rewardController.clear();
      });
    }
  }

  Future<void> _createNewCampaign() async {
    if (_idController.text.isEmpty || _nameController.text.isEmpty || _milestones.isEmpty) {
      _showMsg("برجاء ملء كافة البيانات وإضافة هدف واحد على الأقل");
      return;
    }

    setState(() => _isPublishing = true);

    try {
      String campaignId = _idController.text.trim();
      Map<String, double> formattedMilestones = {};
      _milestones.forEach((key, value) {
        formattedMilestones['order_$key'] = value;
      });

      await FirebaseFirestore.instance.collection('referralCampaigns').doc(campaignId).set({
        'campaignName': _nameController.text.trim(),
        'milestones': formattedMilestones,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      await FirebaseFirestore.instance.collection('appSettings').doc('referralConfig').set({
        'activeCampaignId': campaignId,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      _showMsg("✅ تم إطلاق الحملة وتفعيلها لجميع المناديب الجدد");
      _idController.clear();
      _nameController.clear();
    } catch (e) {
      _showMsg("❌ خطأ: $e");
    } finally {
      setState(() => _isPublishing = false);
    }
  }

  void _showMsg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m, textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'Cairo'))));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("إدارة نظام الإحالة والمكافآت", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.orange[900],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800), // تحديد عرض أقصى للويب ليكون التصميم مريحاً
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildActiveCampaignStatus(),
                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 20),
                Text("إنشاء حملة مكافآت جديدة 🚀", style: TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange[900])),
                const SizedBox(height: 20),
                _buildInputCard(),
                const SizedBox(height: 30),
                _isPublishing 
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _createNewCampaign,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text("حفظ ونشر الحملة كـ (نشطة الآن)", style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 16)),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCampaignStatus() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('appSettings').doc('referralConfig').snapshots(),
      builder: (context, configSnap) {
        if (!configSnap.hasData) return const LinearProgressIndicator();
        String activeId = configSnap.data!.exists ? (configSnap.data!.get('activeCampaignId') ?? "لا توجد") : "لا توجد";

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('referralCampaigns').doc(activeId).snapshots(),
          builder: (context, campSnap) {
            if (!campSnap.hasData || !campSnap.data!.exists) {
              return _statusCard("الحملة الحالية", "لا توجد حملة نشطة حالياً (معرف: $activeId)", Colors.red);
            }
            
            var data = campSnap.data!.data() as Map<String, dynamic>;
            return _statusCard(
              "الحملة النشطة: ${data['campaignName']}",
              "المعرف: $activeId | الأهداف: ${(data['milestones'] as Map).length}",
              Colors.green[700]!,
              isLive: true
            );
          },
        );
      },
    );
  }

  Widget _statusCard(String title, String sub, Color color, {bool isLive = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        border: Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      child: Row(
        children: [
          Icon(isLive ? Icons.sensors : Icons.sensors_off, color: color, size: 40),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: color)),
                Text(sub, style: const TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        children: [
          TextField(controller: _idController, decoration: const InputDecoration(labelText: "معرف الحملة (مثال: spring_2026)", border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: "اسم الحملة الظاهر للمناديب", border: OutlineInputBorder())),
          const SizedBox(height: 25),
          const Text("إضافة أهداف المكافأة (Milestones)", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextField(controller: _orderNumController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: "رقم الأوردر"))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _rewardController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: "المكافأة ج.م"))),
              const SizedBox(width: 10),
              IconButton(onPressed: _addMilestone, icon: const Icon(Icons.add_circle, color: Colors.green, size: 35)),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _milestones.entries.map((e) => Chip(
              backgroundColor: Colors.orange[50],
              label: Text("أوردر ${e.key} ⬅️ ${e.value} ج.م", style: const TextStyle(fontFamily: 'Cairo')),
              onDeleted: () => setState(() => _milestones.remove(e.key)),
              deleteIconColor: Colors.red,
            )).toList(),
          ),
        ],
      ),
    );
  }
}

