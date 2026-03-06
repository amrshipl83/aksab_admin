import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FinancialSummaryScreen extends StatefulWidget {
  const FinancialSummaryScreen({super.key});

  @override
  State<FinancialSummaryScreen> createState() => _FinancialSummaryScreenState();
}

class _FinancialSummaryScreenState extends State<FinancialSummaryScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // تنسيق العملة المصرية
  String formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'ar_EG', symbol: 'ج.م', decimalDigits: 2).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text("ملخص أرصدة المنصة التراكمي", style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: const Color(0xFFB21F2D),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: () => _showVehicleSettingsSheet(context),
            icon: const Icon(Icons.settings_suggest, color: Colors.white),
            label: const Text("إعدادات حسابات التوصيل",
                style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- القسم الأول: عمولات التجار والكاش باك (تحديث يدوي أو عند الفتح) ---
            const Text(
              "📊 نظرة عامة على العمولات والديون (التجار)",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
            ),
            const SizedBox(height: 20),
            FutureBuilder<Map<String, dynamic>>(
              future: _fetchMerchantFinancialData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFB21F2D)));
                }
                final data = snapshot.data!;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 1,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 2.5,
                  children: [
                    _buildFinanceCard("عمولات محققة مستحقة", data['realized'], Icons.check_circle_outline, Colors.green),
                    _buildFinanceCard("عمولات قيد التجميع", data['unrealized'], Icons.hourglass_empty, Colors.orange),
                    _buildFinanceCard("دين كاش باك (من التجار)", data['cbDebt'], Icons.trending_down, Colors.red),
                    _buildFinanceCard("كاش باك مستحق (للتجار)", data['cbCredit'], Icons.account_balance_wallet, Colors.blue),
                    _buildFinanceCard("إيرادات الرسوم الشهرية", data['monthlyFees'], Icons.calendar_today, Colors.teal),
                    _buildFinanceCard("فواتير قيد الانتظار", data['pendingInvoices'].toDouble(), Icons.receipt_long, Colors.blueGrey, isCurrency: false),
                  ],
                );
              },
            ),

            const SizedBox(height: 40),
            const Divider(thickness: 2),
            const SizedBox(height: 20),

            // --- القسم الثاني: حصالة التوصيل (تحديث لحظي لايف) ---
            const Text(
              "🚚 إيرادات وحصالة التوصيل (الشهر الحالي)",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Color(0xFFB21F2D)),
            ),
            const SizedBox(height: 10),
            const Text("هذه البيانات تتحدث تلقائياً مع كل طلب يتم تسليمه", style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 20),
            
            StreamBuilder<DocumentSnapshot>(
              stream: _db.collection('platform_stats').doc('delivery_monthly_accumulator').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text("Error: ${snapshot.error}");
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text("لا توجد بيانات للحصالة حالياً"));
                }
                
                final delData = snapshot.data!.data() as Map<String, dynamic>;
                
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 1,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 2.5,
                  children: [
                    _buildFinanceCard("عمولات توصيل (كاش)", (delData['walletRevenue'] ?? 0).toDouble(), Icons.account_balance_wallet_outlined, Colors.deepPurple),
                    _buildFinanceCard("عمولات توصيل (آجل)", (delData['creditRevenue'] ?? 0).toDouble(), Icons.timer_outlined, Colors.indigo),
                    _buildFinanceCard("إجمالي دخل الطيارين", (delData['totalDriversEarnings'] ?? 0).toDouble(), Icons.moped, Colors.orange[800]!),
                    _buildFinanceCard("حجم مبيعات البضاعة", (delData['totalVolume'] ?? 0).toDouble(), Icons.shopping_basket_outlined, Colors.blueAccent),
                    _buildFinanceCard("عدد طلبات الشهر", (delData['totalOrders'] ?? 0).toDouble(), Icons.local_shipping_outlined, Colors.brown, isCurrency: false),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showVehicleSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFFF4F7FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: const VehicleSettingsPanel(),
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchMerchantFinancialData() async {
    double totalRealized = 0;
    double totalUnrealized = 0;
    double totalCbDebt = 0;
    double totalCbCredit = 0;
    double totalMonthlyFees = 0;

    final sellersSnapshot = await _db.collection('sellers').get();
    for (var doc in sellersSnapshot.docs) {
      final d = doc.data();
      totalRealized += (d['realizedCommission'] ?? 0).toDouble();
      totalUnrealized += (d['unrealizedCommission'] ?? 0).toDouble();
      totalCbDebt += (d['cashbackAccruedDebt'] ?? 0).toDouble();
      totalCbCredit += (d['cashbackPlatformCredit'] ?? 0).toDouble();
      totalMonthlyFees += (d['monthlyFee'] ?? 0).toDouble();
    }

    final invoicesSnapshot = await _db.collection('invoices').where('status', isEqualTo: 'pending').get();
    return {
      'realized': totalRealized,
      'unrealized': totalUnrealized,
      'cbDebt': totalCbDebt,
      'cbCredit': totalCbCredit,
      'monthlyFees': totalMonthlyFees,
      'pendingInvoices': invoicesSnapshot.size,
    };
  }

  Widget _buildFinanceCard(String title, double value, IconData icon, Color color, {bool isCurrency = true}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(right: BorderSide(color: color, width: 6)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Cairo')),
                const SizedBox(height: 5),
                Text(
                  isCurrency ? formatCurrency(value) : value.toInt().toString(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- بقية كود VehicleSettingsPanel و VehicleConfigCard كما هو بدون تغيير ---

class VehicleSettingsPanel extends StatelessWidget {
  const VehicleSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> vehicles = ['motorcycle', 'pickup', 'jumbo'];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("إعدادات حسابات المركبات (المحدثة)",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: vehicles.length,
            itemBuilder: (context, index) => VehicleConfigCard(vehicleName: vehicles[index]),
          ),
        ),
      ],
    );
  }
}

class VehicleConfigCard extends StatefulWidget {
  final String vehicleName;
  const VehicleConfigCard({super.key, required this.vehicleName});

  @override
  State<VehicleConfigCard> createState() => _VehicleConfigCardState();
}

class _VehicleConfigCardState extends State<VehicleConfigCard> {
  final Map<String, TextEditingController> _controllers = {
    'baseFare': TextEditingController(),
    'kmRate': TextEditingController(),
    'minFare': TextEditingController(),
    'serviceFee': TextEditingController(),
    'serviceFeePercentage': TextEditingController(),
    'cancelPenaltyPoints': TextEditingController(),
  };

  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  _loadData() async {
    var doc = await FirebaseFirestore.instance.collection('appSettings').doc('${widget.vehicleName}Config').get();
    if (doc.exists) {
      var data = doc.data()!;
      _controllers.forEach((key, controller) {
        controller.text = (data[key] ?? '0').toString();
      });
    } else {
      _controllers.forEach((key, controller) => controller.text = '0');
    }
    if (mounted) setState(() => _isLoaded = true);
  }

  Future<void> _save() async {
    try {
      Map<String, dynamic> dataToSave = {};
      _controllers.forEach((key, controller) {
        dataToSave[key] = double.tryParse(controller.text) ?? 0.0;
      });

      await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('${widget.vehicleName}Config')
          .set(dataToSave, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("تم تحديث إعدادات ${widget.vehicleName} بنجاح ✅"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping, color: Color(0xFFB21F2D)),
                const SizedBox(width: 10),
                Text(widget.vehicleName.toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            Wrap(
              spacing: 15,
              runSpacing: 15,
              children: [
                _buildInput("فتح العداد", _controllers['baseFare']!),
                _buildInput("سعر الكيلو", _controllers['kmRate']!),
                _buildInput("أقل رحلة", _controllers['minFare']!),
                _buildInput("عمولة ثابتة", _controllers['serviceFee']!),
                _buildInput("نسبة %", _controllers['serviceFeePercentage']!),
                _buildInput("غرامة إلغاء (نقطة)", _controllers['cancelPenaltyPoints']!, isPenalty: true),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text("حفظ الإعدادات"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, {bool isPenalty = false}) {
    return SizedBox(
      width: 155,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
              fontSize: 12,
              fontFamily: 'Cairo',
              color: isPenalty ? Colors.red[900] : Colors.black54,
              fontWeight: isPenalty ? FontWeight.bold : FontWeight.normal),
          border: const OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: isPenalty ? Colors.red : Colors.blue, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          prefixIcon: isPenalty ? const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18) : null,
          filled: isPenalty,
          fillColor: isPenalty ? Colors.red.withOpacity(0.05) : null,
        ),
      ),
    );
  }
}

