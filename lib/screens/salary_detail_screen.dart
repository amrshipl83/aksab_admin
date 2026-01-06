import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SalaryDetailScreen extends StatefulWidget {
  final String employeeId;
  final String employeeType;
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

  // وحدات التحكم للحقول المالية
  final TextEditingController _baseSalaryController = TextEditingController();
  final TextEditingController _commissionRateController = TextEditingController();
  final TextEditingController _commissionThresholdController = TextEditingController();

  // الحقول الاحترافية الجديدة
  final TextEditingController _bonusesController = TextEditingController(); // مكافآت
  final TextEditingController _taxesController = TextEditingController(); // ضرائب
  final TextEditingController _insuranceController = TextEditingController(); // تأمينات
  final TextEditingController _otherDeductionsController = TextEditingController(); // خصومات أخرى
  final TextEditingController _notesController = TextEditingController();

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
    _bonusesController.dispose();
    _taxesController.dispose();
    _insuranceController.dispose();
    _otherDeductionsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _calculateSalary({bool shouldUpdateUI = true}) {
    double base = double.tryParse(_baseSalaryController.text) ?? 0;
    double rate = double.tryParse(_commissionRateController.text) ?? 0;
    double threshold = double.tryParse(_commissionThresholdController.text) ?? 0;
    double bonuses = double.tryParse(_bonusesController.text) ?? 0;
    double taxes = double.tryParse(_taxesController.text) ?? 0;
    double insurance = double.tryParse(_insuranceController.text) ?? 0;
    double others = double.tryParse(_otherDeductionsController.text) ?? 0;

    double targetPercent = (_monthlyTarget > 0) ? (_monthlySales / _monthlyTarget) * 100 : 0;
    _commissionAmount = (targetPercent >= threshold) ? (_monthlySales * rate) : 0;

    // صافي الراتب = (أساسي + عمولة + مكافآت) - (ضرائب + تأمينات + خصومات)
    double calcNet = (base + _commissionAmount + bonuses) - (taxes + insurance + others);

    if (shouldUpdateUI) {
      setState(() {
        _netSalary = calcNet;
      });
    } else {
      _netSalary = calcNet;
    }
  }

  @override
  Widget build(BuildContext context) {
    String collection = (widget.employeeType == 'rep') ? 'salesRep' : 'managers';

    return Scaffold(
      appBar: AppBar(
        title: const Text('اعتماد مسيرات الرواتب', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: const Color(0xFF1A2C3D),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection(collection).doc(widget.employeeId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !_isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: Text("الموظف غير موجود"));

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
            _bonusesController.text = (data['lastBonus'] ?? '').toString();
            _calculateSalary(shouldUpdateUI: false);
            _isInitialized = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildProfileHeader(data),
                const SizedBox(height: 20),
                _buildPerformanceMetrics(),
                const Divider(height: 40),
                _buildSalaryForm(),
                const SizedBox(height: 20),
                _buildNetSalaryCard(),
                const SizedBox(height: 30),
                _buildApproveButton(data['fullname'] ?? 'الموظف'),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSalaryForm() {
    return Card(
      elevation: 0,
      // تم تصحيح الخطأ هنا بتغيير border إلى side
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            const Text("تفاصيل المستحقات والاستقطاعات", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            const SizedBox(height: 10),
            _moneyField("الراتب الأساسي", _baseSalaryController, Icons.money),
            _moneyField("مكافآت إضافية (+)", _bonusesController, Icons.add_circle, color: Colors.green),
            const Divider(),
            _moneyField("ضرائب ورسوم (-)", _taxesController, Icons.remove_circle, color: Colors.red),
            _moneyField("تأمينات اجتماعية (-)", _insuranceController, Icons.security, color: Colors.red),
            _moneyField("خصومات أخرى (-)", _otherDeductionsController, Icons.money_off, color: Colors.red),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: "ملاحظات الاعتماد الشهرية", border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _moneyField(String label, TextEditingController controller, IconData icon, {Color? color}) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: (_) => _calculateSalary(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color),
        labelStyle: TextStyle(color: color, fontSize: 13, fontFamily: 'Cairo'),
      ),
    );
  }

  Widget _buildNetSalaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1A2C3D), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          const Text("صافي المستحق النهائي", style: TextStyle(color: Colors.white70, fontFamily: 'Cairo')),
          Text("${_netSalary.toStringAsFixed(2)} ج.م",
              style: const TextStyle(color: Colors.orange, fontSize: 28, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildApproveButton(String name) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: () => _confirmApproval(name),
        child: const Text("اعتماد الراتب وترحيله للأرشيف",
            style: TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Cairo')),
      ),
    );
  }

  void _confirmApproval(String name) async {
    String currentMonth = DateTime.now().toString().substring(0, 7);
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("تأكيد الاعتماد المالي", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo')),
            content: Text(
                "هل أنت متأكد من اعتماد مبلغ ($_netSalary) للموظف ($name) عن شهر ($currentMonth)؟\n\nسيتم ترحيل البيانات ولن يمكن تعديلها من هذه الشاشة مرة أخرى.",
                textAlign: TextAlign.right),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("مراجعة")),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text("تأكيد الترحيل")),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      _processSettlement(currentMonth, name);
    }
  }

  Future<void> _processSettlement(String month, String name) async {
    try {
      // 1. إضافة السجل في الأرشيف
      await _db.collection('salariesHistory').add({
        'employeeId': widget.employeeId,
        'employeeName': name,
        'employeeType': widget.employeeType,
        'month': month,
        'baseSalary': double.tryParse(_baseSalaryController.text) ?? 0,
        'commission': _commissionAmount,
        'bonuses': double.tryParse(_bonusesController.text) ?? 0,
        'deductions': (double.tryParse(_taxesController.text) ?? 0) +
            (double.tryParse(_insuranceController.text) ?? 0) +
            (double.tryParse(_otherDeductionsController.text) ?? 0),
        'netSalary': _netSalary,
        'approvedAt': FieldValue.serverTimestamp(),
        'notes': _notesController.text,
      });

      // 2. تحديث حالة الموظف
      String collection = (widget.employeeType == 'rep') ? 'salesRep' : 'managers';
      await _db.collection(collection).doc(widget.employeeId).update({
        'lastSettledMonth': month,
        'isSettled': true,
        'monthlySales': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الاعتماد بنجاح وتم ترحيل البيانات"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("حدث خطأ أثناء الترحيل: $e")));
    }
  }

  Widget _buildProfileHeader(Map<String, dynamic> data) {
    return Row(children: [
      const CircleAvatar(radius: 30, backgroundColor: Colors.orange, child: Icon(Icons.person, color: Colors.white)),
      const SizedBox(width: 15),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(data['fullname'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        Text("الكود: ${data['repCode'] ?? '---'}", style: const TextStyle(fontSize: 12)),
      ])
    ]);
  }

  Widget _buildPerformanceMetrics() {
    double percent = (_monthlyTarget > 0) ? (_monthlySales / _monthlyTarget * 100) : 0;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _smallMetric("المبيعات", _monthlySales.toStringAsFixed(0), Colors.blue),
      _smallMetric("الهدف", _monthlyTarget.toStringAsFixed(0), Colors.grey),
      _smallMetric("التحقيق", "${percent.toStringAsFixed(1)}%", Colors.green),
    ]);
  }

  Widget _smallMetric(String label, String val, Color color) {
    return Column(children: [
      Text(label, style: const TextStyle(fontSize: 10, fontFamily: 'Cairo')),
      Text(val, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
    ]);
  }
}

