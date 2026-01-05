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
  
  // controllers للتحكم في الحقول الحسابية
  final TextEditingController _baseSalaryController = TextEditingController();
  final TextEditingController _commissionRateController = TextEditingController();
  final TextEditingController _commissionThresholdController = TextEditingController();
  final TextEditingController _deductionsValueController = TextEditingController();
  final TextEditingController _deductionsNotesController = TextEditingController();

  double _monthlySales = 0;
  double _monthlyTarget = 0;
  double _netSalary = 0;
  double _commissionAmount = 0;

  @override
  void dispose() {
    _baseSalaryController.dispose();
    _commissionRateController.dispose();
    _commissionThresholdController.dispose();
    _deductionsValueController.dispose();
    _deductionsNotesController.dispose();
    super.dispose();
  }

  // دالة الحساب التلقائي للمرتب
  void _calculateSalary() {
    double base = double.tryParse(_baseSalaryController.text) ?? 0;
    double rate = double.tryParse(_commissionRateController.text) ?? 0;
    double threshold = double.tryParse(_commissionThresholdController.text) ?? 0;
    double deduct = double.tryParse(_deductionsValueController.text) ?? 0;

    double targetPercent = (_monthlyTarget > 0) ? (_monthlySales / _monthlyTarget) * 100 : 0;

    setState(() {
      _commissionAmount = (targetPercent >= threshold) ? (_monthlySales * rate) : 0;
      _netSalary = base + _commissionAmount + deduct;
    });
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
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var data = snapshot.data!.data() as Map<String, dynamic>;
          _monthlySales = (data['monthlySales'] ?? 0).toDouble();
          
          // جلب الهدف للشهر الحالي
          String currentMonth = DateTime.now().toString().substring(0, 7);
          var targets = data['targetsHistory'] as List? ?? [];
          var currentTargetDoc = targets.firstWhere((t) => t['month'] == currentMonth, orElse: () => null);
          _monthlyTarget = (currentTargetDoc != null) ? currentTargetDoc['targetAmount'].toDouble() : 0.0;

          // تحديث الحقول في أول مرة فقط
          if (_baseSalaryController.text.isEmpty) {
            _baseSalaryController.text = (data['baseSalary'] ?? '').toString();
            _commissionRateController.text = (data['commissionRate'] ?? '').toString();
            _commissionThresholdController.text = (data['commissionThreshold'] ?? '0').toString();
            _deductionsValueController.text = (data['deductionsValue'] ?? '').toString();
            _deductionsNotesController.text = data['deductionsNotes'] ?? '';
            _calculateSalary();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileHeader(data),
                const Divider(),
                _buildPerformanceMetrics(),
                const Divider(),
                _buildDynamicContent(data),
                const Divider(),
                _buildSalarySheet(),
                const SizedBox(height: 20),
                _buildSaveButton(),
              ],
            ),
          );
        },
      ),
    );
  }

  // 1. الجزء العلوي: البروفايل
  Widget _buildProfileHeader(Map<String, dynamic> data) {
    return Row(
      children: [
        const Icon(Icons.account_circle, size: 80, color: Colors.orange),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['fullname'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              Text("الدور: ${_getArabicRole(widget.employeeType)}", style: const TextStyle(color: Colors.grey)),
              Text(data['email'] ?? ''),
            ],
          ),
        ),
      ],
    );
  }

  // 2. كروت مؤشرات الأداء
  Widget _buildPerformanceMetrics() {
    double percent = (_monthlyTarget > 0) ? (_monthlySales / _monthlyTarget * 100) : 0;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        _metricCard("الهدف الشهري", _monthlyTarget.toStringAsFixed(2), Colors.blue),
        _metricCard("المبيعات الفعلية", _monthlySales.toStringAsFixed(2), Colors.orange),
        _metricCard("تحقيق الهدف", "${percent.toStringAsFixed(1)}%", Colors.green),
        _metricCard("التقييم", percent >= 100 ? "ممتاز" : "جيد", Colors.purple),
      ],
    );
  }

  Widget _metricCard(String title, String val, Color color) {
    return Card(
      color: Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontFamily: 'Cairo')),
          Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // 3. المحتوى المتغير (زيارات أو تابعين)
  Widget _buildDynamicContent(Map<String, dynamic> data) {
    if (widget.employeeType == 'rep') {
      return _buildVisitsList(data['repCode']);
    } else {
      return Text("قائمة التابعين: ${(data['reps'] ?? data['supervisors'] ?? []).length} فرد");
    }
  }

  Widget _buildVisitsList(String? repCode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("سجل الزيارات الأخيرة", style: TextStyle(fontWeight: FontWeight.bold)),
        StreamBuilder<QuerySnapshot>(
          stream: _db.collection('visits').where('repCode', isEqualTo: repCode).limit(5).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const LinearProgressIndicator();
            return Column(
              children: snap.data!.docs.map((doc) => ListTile(
                title: Text(doc['customerName'] ?? 'عميل غير معروف'),
                subtitle: Text(doc['timestamp']?.toDate().toString() ?? ''),
              )).toList(),
            );
          },
        ),
      ],
    );
  }

  // 4. شيت المرتبات الحسابي
  Widget _buildSalarySheet() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          const Text("شيت المرتبات", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          _salaryField("الراتب الأساسي", _baseSalaryController),
          _salaryField("نسبة العمولة (مثلا 0.05)", _commissionRateController),
          _salaryField("نسبة تحقيق العمولة %", _commissionThresholdController),
          _salaryField("الخصومات/الإضافات", _deductionsValueController),
          TextField(
            controller: _deductionsNotesController,
            decoration: const InputDecoration(labelText: "ملاحظات الخصومات"),
            maxLines: 2,
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            color: const Color(0xFF1A2C3D),
            child: Text(
              "صافي الراتب: ${_netSalary.toStringAsFixed(2)}",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  Widget _salaryField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => _calculateSalary(),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        onPressed: _saveData,
        child: const Text("حفظ بيانات المرتب", style: TextStyle(color: Colors.white, fontSize: 18)),
      ),
    );
  }

  Future<void> _saveData() async {
    String collection = (widget.employeeType == 'rep') ? 'salesRep' : 'managers';
    await _db.collection(collection).doc(widget.employeeId).update({
      'baseSalary': double.tryParse(_baseSalaryController.text) ?? 0,
      'commissionRate': double.tryParse(_commissionRateController.text) ?? 0,
      'commissionThreshold': double.tryParse(_commissionThresholdController.text) ?? 0,
      'deductionsValue': double.tryParse(_deductionsValueController.text) ?? 0,
      'deductionsNotes': _deductionsNotesController.text,
      'netSalary': _netSalary,
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حفظ البيانات بنجاح")));
  }

  String _getArabicRole(String type) {
    if (type == 'manager') return 'مدير مبيعات';
    if (type == 'supervisor') return 'مشرف مبيعات';
    return 'مندوب مبيعات';
  }
}

