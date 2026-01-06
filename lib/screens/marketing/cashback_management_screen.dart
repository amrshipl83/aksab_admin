import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // ستحتاج لإضافة intl: ^0.19.0 في pubspec.yaml

class CashbackManagementScreen extends StatefulWidget {
  const CashbackManagementScreen({super.key});

  @override
  State<CashbackManagementScreen> createState() => _CashbackManagementScreenState();
}

class _CashbackManagementScreenState extends State<CashbackManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _editingRuleId; // لتحديد ما إذا كنا نعدل قاعدة موجودة

  // الـ Controllers
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _priorityController = TextEditingController(text: "1");
  final TextEditingController _minPurchaseController = TextEditingController();

  // متغيرات الحالة
  String _ruleType = 'percentage';
  String _appliesTo = 'all';
  String _targetType = 'none';
  bool _isActive = true;

  // التواريخ
  DateTime? _startDate;
  DateTime? _endDate;

  // الاختيارات
  String? _selectedSellerId, _selectedMainCatId, _selectedSubCatId;
  String? _selectedSellerName, _selectedMainCatName, _selectedSubCatName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      appBar: AppBar(
        title: const Text("إدارة قواعد الكاش باك", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A2C3D),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // قسم النموذج (Form Section)
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(_editingRuleId == null ? "إضافة قاعدة جديدة" : "تعديل القاعدة", Icons.edit_calendar),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: "وصف القاعدة", border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? "مطلوب" : null,
                      ),
                      const SizedBox(height: 15),
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
                      DropdownButtonFormField<String>(
                        value: _appliesTo,
                        decoration: const InputDecoration(labelText: "تطبق على", border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text("الجميع")),
                          DropdownMenuItem(value: 'seller', child: Text("تاجر محدد")),
                          DropdownMenuItem(value: 'category', child: Text("قسم رئيسي")),
                          DropdownMenuItem(value: 'subcategory', child: Text("قسم فرعي")),
                        ],
                        onChanged: (v) => setState(() { _appliesTo = v!; }),
                      ),
                      const SizedBox(height: 15),
                      if (_appliesTo == 'seller') _buildSellerDropdown(),
                      if (_appliesTo == 'category') _buildMainCategoryDropdown(),
                      if (_appliesTo == 'subcategory') _buildSubCategoryDropdown(),
                      const SizedBox(height: 15),
                      
                      // اختيار التواريخ (مثل الـ HTML)
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              title: const Text("تاريخ البدء", style: TextStyle(fontSize: 12)),
                              subtitle: Text(_startDate == null ? "اختر تاريخ" : DateFormat('yyyy-MM-dd').format(_startDate!)),
                              onTap: () async {
                                DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
                                if (picked != null) setState(() => _startDate = picked);
                              },
                            ),
                          ),
                          Expanded(
                            child: ListTile(
                              title: const Text("تاريخ الانتهاء", style: TextStyle(fontSize: 12)),
                              subtitle: Text(_endDate == null ? "اختر تاريخ" : DateFormat('yyyy-MM-dd').format(_endDate!)),
                              onTap: () async {
                                DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
                                if (picked != null) setState(() => _endDate = picked);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      
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
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _minPurchaseController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "الحد الأدنى للشراء", border: OutlineInputBorder()),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _saveRule,
                              icon: const Icon(Icons.save),
                              label: Text(_editingRuleId == null ? "حفظ القاعدة" : "تحديث القاعدة"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            ),
                          ),
                          if (_editingRuleId != null) ...[
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () => setState(() => _resetForm()),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                              child: const Text("إلغاء"),
                            ),
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            
            // قسم عرض القواعد الحالية (Rules List Section)
            _buildSectionTitle("القواعد النشطة حالياً", Icons.list),
            const SizedBox(height: 10),
            _buildRulesList(),
          ],
        ),
      ),
    );
  }

  // --- بناء قائمة القواعد من Firestore ---
  Widget _buildRulesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('cashbackRules').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Text("لا توجد قواعد حالياً");

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Colors.redAccent.withOpacity(0.1), child: const Icon(Icons.percent, color: Colors.redAccent)),
                title: Text(data['description'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("القيمة: ${data['value']} | تطبق على: ${data['appliesTo']}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editRule(doc)),
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteRule(doc.id)),

                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- دوال المساعدة للدروب داون ---
  Widget _buildSellerDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('sellers').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        return DropdownButtonFormField<String>(
          value: _selectedSellerId,
          hint: const Text("اختر التاجر"),
          items: snapshot.data!.docs.map((d) {
            var data = d.data() as Map<String, dynamic>;
            return DropdownMenuItem(value: d.id, child: Text("${data['merchantName']}"));
          }).toList(),
          onChanged: (v) {
            setState(() {
              _selectedSellerId = v;
              _selectedSellerName = snapshot.data!.docs.firstWhere((d) => d.id == v).get('merchantName');
            });
          },
        );
      },
    );
  }

  // (كرر نفس المنطق لـ MainCategory و SubCategory كما في الكود السابق)
  Widget _buildMainCategoryDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('mainCategory').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        return DropdownButtonFormField<String>(
          value: _selectedMainCatId,
          hint: const Text("اختر القسم"),
          items: snapshot.data!.docs.map((d) => DropdownMenuItem(value: d.id, child: Text(d.get('name')))).toList(),
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

  Widget _buildSubCategoryDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('subCategory').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        return DropdownButtonFormField<String>(
          value: _selectedSubCatId,
          hint: const Text("اختر القسم الفرعي"),
          items: snapshot.data!.docs.map((d) => DropdownMenuItem(value: d.id, child: Text(d.get('name')))).toList(),
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

  void _editRule(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    setState(() {
      _editingRuleId = doc.id;
      _descriptionController.text = data['description'] ?? '';
      _valueController.text = data['value'].toString();
      _ruleType = data['type'] ?? 'percentage';
      _appliesTo = data['appliesTo'] ?? 'all';
      _targetType = data['targetType'] ?? 'none';
      _minPurchaseController.text = data['minPurchaseAmount'].toString();
      _selectedSellerId = data['sellerId'];
      _selectedMainCatId = data['mainCategoryId'];
      _selectedSubCatId = data['subCategoryId'];
      if (data['startDate'] != null) _startDate = (data['startDate'] as Timestamp).toDate();
      if (data['endDate'] != null) _endDate = (data['endDate'] as Timestamp).toDate();
    });
  }

  void _deleteRule(String id) async {
    bool? confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("حذف"), content: const Text("هل أنت متأكد؟"), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("لا")), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("نعم"))]));
    if (confirm == true) await FirebaseFirestore.instance.collection('cashbackRules').doc(id).delete();
  }

  void _resetForm() {
    _editingRuleId = null;
    _descriptionController.clear();
    _valueController.clear();
    _minPurchaseController.clear();
    _startDate = null;
    _endDate = null;
    _selectedSellerId = null;
    _selectedMainCatId = null;
    _selectedSubCatId = null;
  }

  void _saveRule() async {
    if (_formKey.currentState!.validate()) {
      var data = {
        'description': _descriptionController.text,
        'type': _ruleType,
        'value': double.tryParse(_valueController.text) ?? 0.0,
        'appliesTo': _appliesTo,
        'targetType': _targetType,
        'goalBasis': _targetType == 'per_order' ? 'single_order' : 'cumulative_spending',
        'minPurchaseAmount': double.tryParse(_minPurchaseController.text) ?? 0.0,
        'sellerId': _selectedSellerId,
        'sellerName': _selectedSellerName,
        'mainCategoryId': _selectedMainCatId,
        'mainCategoryName': _selectedMainCatName,
        'subCategoryId': _selectedSubCatId,
        'subCategoryName': _selectedSubCatName,
        'startDate': _startDate != null ? Timestamp.fromDate(_startDate!) : null,
        'endDate': _endDate != null ? Timestamp.fromDate(_endDate!) : null,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_editingRuleId == null) {
        await FirebaseFirestore.instance.collection('cashbackRules').add(data);
      } else {
        await FirebaseFirestore.instance.collection('cashbackRules').doc(_editingRuleId).update(data);
      }
      _resetForm();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الحفظ بنجاح")));
    }
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(children: [Icon(icon, size: 20, color: const Color(0xFF1A2C3D)), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))]);
  }
}

