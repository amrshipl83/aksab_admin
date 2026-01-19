import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VehicleSettingsScreen extends StatefulWidget {
  const VehicleSettingsScreen({super.key});

  @override
  State<VehicleSettingsScreen> createState() => _VehicleSettingsScreenState();
}

class _VehicleSettingsScreenState extends State<VehicleSettingsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final List<String> _vehicles = ['motorcycle', 'pickup', 'jumbo'];

  Future<void> _updateSettings(String vehicle, Map<String, dynamic> data) async {
    try {
      await _db.collection('appSettings').doc('${vehicle}Config').set(data, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("تم تحديث إعدادات $vehicle بنجاح ✅"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ في التحديث: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إدارة أسعار وخدمات المركبات")),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _vehicles.length,
        itemBuilder: (context, index) {
          return VehicleConfigCard(
            vehicleName: _vehicles[index],
            onSave: (newData) => _updateSettings(_vehicles[index], newData),
          );
        },
      ),
    );
  }
}

class VehicleConfigCard extends StatefulWidget {
  final String vehicleName;
  final Function(Map<String, dynamic>) onSave;

  const VehicleConfigCard({super.key, required this.vehicleName, required this.onSave});

  @override
  State<VehicleConfigCard> createState() => _VehicleConfigCardState();
}

class _VehicleConfigCardState extends State<VehicleConfigCard> {
  // 🔥 تم إضافة حقل cancelPenaltyPoints هنا
  final Map<String, TextEditingController> _controllers = {
    'baseFare': TextEditingController(),
    'kmRate': TextEditingController(),
    'minFare': TextEditingController(),
    'serviceFee': TextEditingController(),
    'serviceFeePercentage': TextEditingController(),
    'cancelPenaltyPoints': TextEditingController(), // حقل غرامة الإلغاء
  };

  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  _loadData() async {
    var doc = await FirebaseFirestore.instance
        .collection('appSettings')
        .doc('${widget.vehicleName}Config')
        .get();
    if (doc.exists) {
      var data = doc.data()!;
      _controllers.forEach((key, controller) {
        controller.text = (data[key] ?? '0').toString();
      });
      if (mounted) setState(() => _isLoaded = true);
    } else {
      if (mounted) setState(() => _isLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const LinearProgressIndicator();

    return Card(
      margin: const EdgeInsets.only(bottom: 25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings_suggest, color: Colors.blue),
                const SizedBox(width: 10),
                Text(widget.vehicleName.toUpperCase(),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 30),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                _buildField("فتح العداد", _controllers['baseFare']!),
                _buildField("سعر الكيلو", _controllers['kmRate']!),
                _buildField("الحد الأدنى للرحلة", _controllers['minFare']!),
                _buildField("العمولة الثابتة (Min)", _controllers['serviceFee']!),
                _buildField("نسبة العمولة (%)", _controllers['serviceFeePercentage']!),
                // 🔥 إضافة الحقل في الواجهة
                _buildField("غرامة الإلغاء (نقاط)", _controllers['cancelPenaltyPoints']!, isPenalty: true),
              ],
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text("حفظ التعديلات"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[900], foregroundColor: Colors.white),
                onPressed: () {
                  Map<String, dynamic> dataToSave = {};
                  _controllers.forEach((key, controller) {
                    dataToSave[key] = double.tryParse(controller.text) ?? 0.0;
                  });
                  widget.onSave(dataToSave);
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {bool isPenalty = false}) {
    return SizedBox(
      width: 200,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isPenalty ? Colors.red : null), // تمييز الغرامة باللون
          border: const OutlineInputBorder(),
          prefixIcon: Icon(isPenalty ? Icons.warning_amber_rounded : Icons.edit, 
                          size: 16, 
                          color: isPenalty ? Colors.red : null),
        ),
      ),
    );
  }
}

