import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddAdminTab extends StatefulWidget {
  const AddAdminTab({super.key});

  @override
  State<AddAdminTab> createState() => _AddAdminTabState();
}

class _AddAdminTabState extends State<AddAdminTab> {
  final _formKey = GlobalKey<FormState>();

  // البيانات الشخصية والوظيفية
  final nameCont = TextEditingController();
  final emailCont = TextEditingController();
  final phoneCont = TextEditingController();
  final deptCont = TextEditingController();
  final jobCont = TextEditingController();
  DateTime? selectedDate;

  // البيانات المالية الخام (Raw Data)
  final baseSalaryCont = TextEditingController();
  final allowancesCont = TextEditingController();
  final insuranceCont = TextEditingController();
  final taxesCont = TextEditingController();

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate() || selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى ملء كافة البيانات واختيار تاريخ التعيين")),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('administrativeEmployees').add({
        'fullname': nameCont.text,
        'email': emailCont.text,
        'phoneNumber': phoneCont.text,
        'department': deptCont.text,
        'jobTitle': jobCont.text,
        'startDate': selectedDate,
        'status': 'active',
        // البيانات المالية الخام التي ستعالجها اللمدا
        'baseSalary': double.tryParse(baseSalaryCont.text) ?? 0.0,
        'allowances': double.tryParse(allowancesCont.text) ?? 0.0,
        'insurance': double.tryParse(insuranceCont.text) ?? 0.0,
        'taxes': double.tryParse(taxesCont.text) ?? 0.0,
        'attendanceDays': 0, // قيمة افتراضية تبدأ من الصفر
        'netSalary': 0.0,      // ستحدثه اللمدا لاحقاً
        'createdAt': FieldValue.serverTimestamp(),
        'allowedBranches': [], // مصفوفة فارغة للفروع
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تمت إضافة الموظف بنجاح")));
      _formKey.currentState!.reset();
      setState(() => selectedDate = null);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("البيانات الأساسية", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            _buildField(nameCont, "الاسم الكامل", Icons.person),
            _buildField(emailCont, "البريد الإلكتروني", Icons.email, keyboardType: TextInputType.emailAddress),
            _buildField(phoneCont, "رقم الهاتف", Icons.phone, keyboardType: TextInputType.phone),
            _buildField(deptCont, "الإدارة", Icons.business),
            _buildField(jobCont, "المسمى الوظيفي", Icons.work),
            
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(selectedDate == null ? "تاريخ مباشرة العمل" : selectedDate.toString().split(' ')[0]),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) setState(() => selectedDate = picked);
              },
            ),

            const SizedBox(height: 20),
            const Text("المدخلات المالية (البيانات الخام)", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange)),
            const Divider(),
            _buildField(baseSalaryCont, "الراتب الأساسي", Icons.money, keyboardType: TextInputType.number),
            _buildField(allowancesCont, "إجمالي البدلات", Icons.add_circle_outline, keyboardType: TextInputType.number),
            _buildField(insuranceCont, "خصم التأمينات", Icons.remove_circle_outline, keyboardType: TextInputType.number),
            _buildField(taxesCont, "خصم الضرائب", Icons.account_balance, keyboardType: TextInputType.number),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitData,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A2C3D), foregroundColor: Colors.white),
                child: const Text("حفظ بيانات الموظف", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        validator: (value) => value!.isEmpty ? "هذا الحقل مطلوب" : null,
      ),
    );
  }
}

