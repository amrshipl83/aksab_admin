import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // المتغيرات المختارة
  String? _selectedUserType; // sellers or deliverySupermarkets
  String? _selectedUserId;
  String? _selectedUserName;
  String _subType = 'شهري'; // شهري أو مساحة إعلانية
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  final TextEditingController _amountController = TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();

  List<Map<String, dynamic>> _usersList = [];
  bool _isLoadingUsers = false;

  // جلب المستخدمين بناءً على النوع المختار
  Future<void> _fetchUsers(String type) async {
    setState(() {
      _isLoadingUsers = true;
      _usersList = [];
      _selectedUserId = null;
    });

    final snapshot = await FirebaseFirestore.instance.collection(type).get();
    
    setState(() {
      _usersList = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          // المورد عنده merchantName والسوبر ماركت عنده supermarketName
          'name': data['merchantName'] ?? data['supermarketName'] ?? 'بدون اسم',
        };
      }).toList();
      _isLoadingUsers = false;
    });
  }

  // حفظ الاشتراك في مجموعة منفصلة
  Future<void> _saveSubscription() async {
    if (!_formKey.currentState!.validate() || _selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برجاء استكمال البيانات')));
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('subscriptions').add({
        'userId': _selectedUserId,
        'userName': _selectedUserName,
        'userType': _selectedUserType,
        'subscriptionType': _subType,
        'startDate': _startDate,
        'endDate': _endDate,
        'amount': double.tryParse(_amountController.text) ?? 0,
        'notes': _notesController.text,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active', 
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل الاشتراك بنجاح')));
      _formKey.currentState!.reset();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الاشتراكات والتحصيل')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('1. تحديد الطرف الثانـي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'نوع المستخدم', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'sellers', child: Text('مورد (Sellers)')),
                        DropdownMenuItem(value: 'deliverySupermarkets', child: Text('سوبر ماركت (Delevery)')),
                      ],
                      onChanged: (val) => _fetchUsers(val!),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _isLoadingUsers 
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'اختر الاسم', border: OutlineInputBorder()),
                          value: _selectedUserId,
                          items: _usersList.map((user) => DropdownMenuItem(
                            value: user['id'] as String,
                            child: Text(user['name']),
                          )).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedUserId = val;
                              _selectedUserName = _usersList.firstWhere((u) => u['id'] == val)['name'];
                            });
                          },
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const Text('2. تفاصيل الاشتراك', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 15),
              _buildSubscriptionDetails(),
              const SizedBox(height: 40),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _saveSubscription,
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ واشتراك جديد'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionDetails() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _subType,
          decoration: const InputDecoration(labelText: 'نوع الاشتراك', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'شهري', child: Text('اشتراك شهري (عضوية)')),
            DropdownMenuItem(value: 'مساحة إعلانية', child: Text('اشتراك تسويقي (مساحة إعلانية)')),
          ],
          onChanged: (val) => setState(() => _subType = val!),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ListTile(
                title: const Text('تاريخ البداية'),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(_startDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  DateTime? picked = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2025), lastDate: DateTime(2030));
                  if (picked != null) setState(() => _startDate = picked);
                },
              ),
            ),
            Expanded(
              child: ListTile(
                title: const Text('تاريخ النهاية'),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(_endDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  DateTime? picked = await showDatePicker(context: context, initialDate: _endDate, firstDate: DateTime(2025), lastDate: DateTime(2030));
                  if (picked != null) setState(() => _endDate = picked);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _amountController,
          decoration: const InputDecoration(labelText: 'القيمة المالية (EGP)', border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }
}

