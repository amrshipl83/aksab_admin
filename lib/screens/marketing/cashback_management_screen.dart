import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CashbackManagementScreen extends StatefulWidget {
  const CashbackManagementScreen({super.key});

  @override
  State<CashbackManagementScreen> createState() => _CashbackManagementScreenState();
}

class _CashbackManagementScreenState extends State<CashbackManagementScreen> {
  final _formKey = GlobalKey<FormState>();

  // الـ Controllers
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _priorityController = TextEditingController(text: "1");
  final TextEditingController _minPurchaseController = TextEditingController();

  // متغيرات الحالة (State)
  String _ruleType = 'percentage';
  String _appliesTo = 'all';
  String _targetType = 'none';
  bool _isActive = true;

  // متغيرات الاختيار من القوائم
  String? _selectedSellerId;
  String? _selectedMainCatId;
  String? _selectedSubCatId;

  // تخزين الأسماء المختارة لإرسالها مع الـ ID لتسهيل الفلترة
  String? _selectedSellerName;
  String? _selectedMainCatName;
  String? _selectedSubCatName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إدارة قواعد الكاش باك", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A2C3D),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("إضافة قاعدة جديدة", Icons.add_circle_outline),
              const SizedBox(height: 15),
              
              // وصف القاعدة
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: "وصف القاعدة (مثال: خصم الصيف)", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "يرجى إدخال الوصف" : null,
              ),
              const SizedBox(height: 15),

              // نوع القيمة وقيمتها
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _ruleType,
                      decoration: const InputDecoration(labelText: "النوع", border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'percentage', child: Text("نسبة مئوية")),
                        DropdownMenuItem(value: 'fixedAmount', child: Text("مبلغ ثابت")),
                      ],
                      onChanged: (v) => setState(() => _ruleType = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _valueController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "القيمة", border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? "مطلوب" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // تطبق على (التاجر أو القسم)
              DropdownButtonFormField<String>(
                value: _appliesTo,
                decoration: const InputDecoration(labelText: "تطبق على", border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text("الجميع")),
                  DropdownMenuItem(value: 'seller', child: Text("تاجر محدد")),
                  DropdownMenuItem(value: 'category', child: Text("قسم رئيسي")),
                  DropdownMenuItem(value: 'subcategory', child: Text("قسم فرعي")),
                ],
                onChanged: (v) => setState(() {
                  _appliesTo = v!;
                  _selectedSellerId = null;
                  _selectedMainCatId = null;
                  _selectedSubCatId = null;
                }),
              ),
              const SizedBox(height: 15),

              // القوائم المنسدلة الديناميكية (التحسين المطلوب)
              if (_appliesTo == 'seller') _buildSellerDropdown(),
              if (_appliesTo == 'category') _buildMainCategoryDropdown(),
              if (_appliesTo == 'subcategory') _buildSubCategoryDropdown(),

              const SizedBox(height: 15),

              // نوع التارجت
              DropdownButtonFormField<String>(
                value: _targetType,
                decoration: const InputDecoration(labelText: "نوع التارجت", border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text("لا يوجد")),
                  DropdownMenuItem(value: 'per_order', child: Text("لكل طلب")),
                  DropdownMenuItem(value: 'cumulative_period', child: Text("تراكمي")),
                ],
                onChanged: (v) => setState(() => _targetType = v!),
              ),
              
              if (_targetType != 'none') ...[
                const SizedBox(height: 15),
                TextFormField(
                  controller: _minPurchaseController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "الحد الأدنى للشراء", border: OutlineInputBorder()),
                ),
              ],

              const SizedBox(height: 20),
              
              // زر الحفظ
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saveRule,
                  icon: const Icon(Icons.save),
                  label: const Text("حفظ قاعدة الكاش باك", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- منسدلة التجار ---
  Widget _buildSellerDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('sellers').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        var docs = snapshot.data!.docs;
        return DropdownButtonFormField<String>(
          value: _selectedSellerId,
          hint: const Text("اختر التاجر"),
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: docs.map((d) {
            var data = d.data() as Map<String, dynamic>;
            return DropdownMenuItem(
              value: d.id,
              child: Text("${data['merchantName'] ?? 'بدون اسم'} (${data['phone'] ?? ''})"),
            );
          }).toList(),
          onChanged: (v) {
            setState(() {
              _selectedSellerId = v;
              var doc = docs.firstWhere((d) => d.id == v);
              _selectedSellerName = (doc.data() as Map)['merchantName'];
            });
          },
        );
      },
    );
  }

  // --- منسدلة الأقسام الرئيسية ---
  Widget _buildMainCategoryDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('mainCategory').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        return DropdownButtonFormField<String>(
          value: _selectedMainCatId,
          hint: const Text("اختر القسم الرئيسي"),
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: snapshot.data!.docs.map((d) {
            var data = d.data() as Map<String, dynamic>;
            return DropdownMenuItem(value: d.id, child: Text(data['name'] ?? ''));
          }).toList(),
          onChanged: (v) {
            setState(() {
              _selectedMainCatId = v;
              _selectedMainCatName = snapshot.data!.docs.firstWhere((d) => d.id == v).get('name');
            });
          },
        );
      },
    );
  }

  // --- منسدلة الأقسام الفرعية ---
  Widget _buildSubCategoryDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('subCategory').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        return DropdownButtonFormField<String>(
          value: _selectedSubCatId,
          hint: const Text("اختر القسم الفرعي"),
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: snapshot.data!.docs.map((d) {
            var data = d.data() as Map<String, dynamic>;
            return DropdownMenuItem(value: d.id, child: Text(data['name'] ?? ''));
          }).toList(),
          onChanged: (v) {
            setState(() {
              _selectedSubCatId = v;
              _selectedSubCatName = snapshot.data!.docs.firstWhere((d) => d.id == v).get('name');
            });
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1A2C3D)),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
      ],
    );
  }

  // --- دالة حفظ القاعدة ---
  void _saveRule() async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseFirestore.instance.collection('cashbackRules').add({
          'description': _descriptionController.text,
          'type': _ruleType,
          'value': double.tryParse(_valueController.text) ?? 0.0,
          'appliesTo': _appliesTo,
          'priority': int.tryParse(_priorityController.text) ?? 1,
          'status': _isActive ? 'active' : 'inactive',
          'targetType': _targetType,
          'goalBasis': _targetType == 'per_order' ? 'single_order' : 'cumulative_spending',
          'minPurchaseAmount': double.tryParse(_minPurchaseController.text) ?? 0.0,
          
          // إرسال الـ IDs والأسماء كما طلبت لتسهيل الفلترة
          'sellerId': _selectedSellerId,
          'sellerName': _selectedSellerName,
          'mainCategoryId': _selectedMainCatId,
          'mainCategoryName': _selectedMainCatName,
          'subCategoryId': _selectedSubCatId,
          'subCategoryName': _selectedSubCatName,
          
          'createdAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حفظ القاعدة بنجاح!")));
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
      }
    }
  }
}

