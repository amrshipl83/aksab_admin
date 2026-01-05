import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SalaryDetailScreen extends StatefulWidget {
  final String employeeId;
  final String employeeType; // 'manager', 'supervisor', 'rep'

  const SalaryDetailScreen({
    super.key,
    required this.employeeId,
    required this.employeeType,
  });

  @override
  State<SalaryDetailScreen> createState() => _SalaryDetailScreenState();
}

class _SalaryDetailScreenState extends State<SalaryDetailScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  final TextEditingController _baseSalaryController = TextEditingController();
  final TextEditingController _commissionRateController = TextEditingController();
  final TextEditingController _commissionThresholdController = TextEditingController();
  final TextEditingController _deductionsValueController = TextEditingController();
  final TextEditingController _deductionsNotesController = TextEditingController();

  double _monthlySales = 0;
  double _monthlyTarget = 0;
  double _netSalary = 0;
  double _commissionAmount = 0;
  bool _isInitialized = false; 

  @override
  void dispose() {
    _baseSalaryController.dispose();
    _commissionRateController.dispose();
    _commissionThresholdController.dispose();
    _deductionsValueController.dispose();
    _deductionsNotesController.dispose();
    super.dispose();
  }

  void _calculateSalary({bool shouldUpdateUI = true}) {
    double base = double.tryParse(_baseSalaryController.text) ?? 0;
    double rate = double.tryParse(_commissionRateController.text) ?? 0;
    double threshold = double.tryParse(_commissionThresholdController.text) ?? 0;
    double deduct = double.tryParse(_deductionsValueController.text) ?? 0;

    double targetPercent = (_monthlyTarget > 0) ? (_monthlySales / _monthlyTarget) * 100 : 0;
    double calcCommission = (targetPercent >= threshold) ? (_monthlySales * rate) : 0;
    double calcNet = base + calcCommission + deduct;

    if (shouldUpdateUI) {
      setState(() {
        _commissionAmount = calcCommission;
        _netSalary = calcNet;
      });
    } else {
      _commissionAmount = calcCommission;
      _netSalary = calcNet;
    }
  }

  @override
  Widget build(BuildContext context) {
    String collection = (widget.employeeType == 'rep') ? 'salesRep' : 'managers';

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير أداء الموظف', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: const Color(0xFF1A2C3D),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection(collection).doc(widget.employeeId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !_isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("عذراً، لم يتم العثور على بيانات الموظف"));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          _monthlySales = (data['monthlySales'] ?? 0).toDouble();
          String currentMonth = DateTime.now().toString().substring(0, 7);
          var targets = data['targetsHistory'] as List? ?? [];
          var currentTargetDoc = targets.firstWhere((t) => t['month'] == currentMonth, orElse: () => null);
          _monthlyTarget = (currentTargetDoc != null) ? currentTargetDoc['targetAmount'].toDouble() : 0.0;

          if (!_isInitialized) {
            _baseSalaryController.text = (data['baseSalary'] ?? '').toString();
            _commissionRateController.text = (data['commissionRate'] ?? '').toString();
            _commissionThresholdController.text = (data['commissionThreshold'] ?? '0').toString();
            _deductionsValueController.text = (data['deductionsValue'] ?? '').toString();
            _deductionsNotesController.text = data['deductionsNotes'] ?? '';
            _calculateSalary(shouldUpdateUI: false);
            _isInitialized = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileHeader(data),
                const Divider(height: 30),
                _buildPerformanceMetrics(),
                const Divider(height: 30),
                _buildDynamicContent(data),
                const Divider(height: 30),
                _buildSalarySheet(),
                const SizedBox(height: 30),
                _buildSaveButton(),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> data) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 35,
          backgroundColor: Colors.orange,
          child: Icon(Icons.person, size: 40, color: Colors.white),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['fullname'] ?? 'N/A', 
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              Text("الدور: ${_getArabicRole(widget.employeeType)}", 
                style: const TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
              Text(data['email'] ?? '', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceMetrics() {
    double percent = (_monthlyTarget > 0) ? (_monthlySales / _monthlyTarget * 100) : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("مؤشرات الأداء", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Cairo')),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.6,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            _metricCard("الهدف الشهري", _monthlyTarget.toStringAsFixed(2), Colors.blue),
            _metricCard("المبيعات الفعلية", _monthlySales.toStringAsFixed(2), Colors.orange),
            _metricCard("تحقيق الهدف", "${percent.toStringAsFixed(1)}%", Colors.green),
            _metricCard("التقييم", percent >= 100 ? "ممتاز" : "جيد", Colors.purple),
          ],
        ),
      ],
    );
  }

  Widget _metricCard(String title, String val, Color color) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: color.withOpacity(0.3))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontFamily: 'Cairo')),
          Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildDynamicContent(Map<String, dynamic> data) {
    if (widget.employeeType == 'rep') {
      return _buildVisitsList(data['repCode']);
    } else {
      int count = (data['reps'] as List? ?? data['supervisors'] as List? ?? []).length;
      return ListTile(
        tileColor: Colors.grey[100],
        title: const Text("عدد التابعين المسجلين", style: TextStyle(fontFamily: 'Cairo')),
        trailing: CircleAvatar(child: Text(count.toString())),
      );
    }
  }

  Widget _buildVisitsList(String? repCode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("آخر الزيارات المسجلة", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        const SizedBox(height: 10),
        if (repCode == null || repCode.isEmpty)
          const Text("لا يوجد كود تعريفي للمندوب")
        else
          StreamBuilder<QuerySnapshot>(
            stream: _db.collection('visits')
                .where('repCode', isEqualTo: repCode)
                .orderBy('timestamp', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
              if (!snap.hasData || snap.data!.docs.isEmpty) return const Text("لا توجد زيارات مسجلة لهذا الشهر");
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snap.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snap.data!.docs[index];
                  var visitData = doc.data() as Map<String, dynamic>;
                  String dateStr = "N/A";
                  if (visitData['timestamp'] != null) {
                    dateStr = (visitData['timestamp'] as Timestamp).toDate().toString().split('.')[0];
                  }
                  return Card(
                    child: ListTile(
                      dense: true,
                      title: Text(visitData['customerName'] ?? 'غير معروف'),
                      subtitle: Text(dateStr),
                      leading: const Icon(Icons.location_on, color: Colors.red),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildSalarySheet() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey[300]!)),
      child: Column(
        children: [
          const Text("شيت المرتبات", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          _salaryField("الراتب الأساسي", _baseSalaryController),
          _salaryField("نسبة العمولة (مثلاً 0.05)", _commissionRateController),
          _salaryField("نسبة تحقيق العمولة %", _commissionThresholdController),
          _salaryField("الخصومات / الإضافات الرقمية", _deductionsValueController),
          const SizedBox(height: 10),
          TextField(
            controller: _deductionsNotesController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: "ملاحظات الخصومات والمكافآت", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: const Color(0xFF1A2C3D), borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("صافي الراتب النهائي:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                Text(_netSalary.toStringAsFixed(2), style: const TextStyle(color: Colors.orange, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _salaryField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, border: const UnderlineInputBorder()),
        onChanged: (_) => _calculateSalary(),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.save, color: Colors.white),
        label: const Text("حفظ البيانات في النظام", style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Cairo')),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        onPressed: _saveData,
      ),
    );
  }

  Future<void> _saveData() async {
    String collection = (widget.employeeType == 'rep') ? 'salesRep' : 'managers';
    try {
      await _db.collection(collection).doc(widget.employeeId).update({
        'baseSalary': double.tryParse(_baseSalaryController.text) ?? 0,
        'commissionRate': double.tryParse(_commissionRateController.text) ?? 0,
        'commissionThreshold': double.tryParse(_commissionThresholdController.text) ?? 0,
        'deductionsValue': double.tryParse(_deductionsValueController.text) ?? 0,
        'deductionsNotes': _deductionsNotesController.text,
        'netSalary': _netSalary,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم التحديث بنجاح")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ في الحفظ: $e")));
    }
  }

  String _getArabicRole(String type) {
    if (type == 'manager') return 'مدير مبيعات';
    if (type == 'supervisor') return 'مشرف مبيعات';
    return 'مندوب مبيعات';
  }
}

