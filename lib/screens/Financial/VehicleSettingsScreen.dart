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
      // استخدام merge: true يحافظ على البيانات القديمة ويضيف الجديد
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
      appBar: AppBar(
        title: const Text("إدارة أسعار وخدمات المركبات"),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
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
  // تعريف الـ Controllers لجميع الحقول بما فيها الغرامة
  final Map<String, TextEditingController> _controllers = {
    'baseFare': TextEditingController(),
    'kmRate': TextEditingController(),
    'minFare': TextEditingController(),
    'serviceFee': TextEditingController(),
    'serviceFeePercentage': TextEditingController(),
    'cancelPenaltyPoints': TextEditingController(), // حقل الغرامة الجديد
  };

  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // دالة جلب البيانات مع ضمان ظهور الحقول الجديدة
  _loadData() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('${widget.vehicleName}Config')
          .get();

      if (doc.exists) {
        var data = doc.data()!;
        _controllers.forEach((key, controller) {
          // إذا كان الحقل (مثل الغرامة) غير موجود في الداتابيز، نضع '0'
          controller.text = (data[key] ?? '0').toString();
        });
      } else {
        // إذا كان المستند غير موجود أصلاً (أول مرة)، نضع أصفار في كل الحقول
        _controllers.forEach((key, controller) => controller.text = '0');
      }
    } catch (e) {
      debugPrint("Error loading vehicle data: $e");
    } finally {
      if (mounted) setState(() => _isLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(child: CircularProgressIndicator()),
    );

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
                const Icon(Icons.delivery_dining, color: Colors.blue, size: 30),
                const SizedBox(width: 10),
                Text(widget.vehicleName.toUpperCase(),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
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
                // الحقل السحرى الذي سيعمل الآن 🪄
                _buildField("غرامة الإلغاء (نقاط)", _controllers['cancelPenaltyPoints']!, isPenalty: true),
              ],
            ),
            const SizedBox(height: 25),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text("حفظ الإعدادات"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
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
      width: 220,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isPenalty ? Colors.red[700] : Colors.blueGrey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: isPenalty ? Colors.red[200]! : Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: isPenalty ? Colors.red : Colors.blue, width: 2),
          ),
          prefixIcon: Icon(
            isPenalty ? Icons.warning_amber_rounded : Icons.edit_note,
            color: isPenalty ? Colors.red : Colors.blue,
          ),
          filled: true,
          fillColor: isPenalty ? Colors.red[50] : Colors.grey[50],
        ),
      ),
    );
  }
}

