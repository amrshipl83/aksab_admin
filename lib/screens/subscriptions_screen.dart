import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});
  static const routeName = '/subscriptions';

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedUserType; 
  String? _selectedUserId;
  String? _selectedUserName;
  String _subType = 'شهري'; 
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  
  final TextEditingController _amountController = TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();

  List<Map<String, dynamic>> _usersList = [];
  bool _isLoadingUsers = false;
  bool _isSaving = false;

  Future<void> _fetchUsers(String type) async {
    setState(() {
      _isLoadingUsers = true;
      _selectedUserType = type;
      _usersList = [];
      _selectedUserId = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance.collection(type).get();
      setState(() {
        _usersList = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['merchantName'] ?? data['supermarketName'] ?? 'اسم غير مسجل',
          };
        }).toList();
      });
    } catch (e) {
      _showSnackBar("خطأ في جلب البيانات: $e", Colors.red);
    } finally {
      setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _saveSubscription() async {
    if (!_formKey.currentState!.validate() || _selectedUserId == null) {
      _showSnackBar('برجاء اختيار الجهة وتحديد المستخدم أولاً', Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    try {
      String userRole = (_selectedUserType == 'sellers') ? 'seller' : 'buyer';

      await FirebaseFirestore.instance.collection('subscriptions').add({
        'targetUserId': _selectedUserId,
        'targetUserName': _selectedUserName,
        'targetUserType': _selectedUserType, 
        'role': userRole,                    
        'subscriptionType': _subType,
        'startDate': Timestamp.fromDate(_startDate),
        'endDate': Timestamp.fromDate(_endDate),
        'amount': double.tryParse(_amountController.text) ?? 0,
        'notes': _notesController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'AdminPanel',
        'paymentStatus': 'pending',          
        'invoiceGenerated': false,           
        'needsSettlement': true,             
      });

      _showSnackBar('تم تسجيل الاشتراك بنجاح وبدء المخالصة المالية', Colors.green);
      
      _formKey.currentState!.reset();
      setState(() {
        _selectedUserId = null;
        _amountController.text = '0';
        _notesController.clear();
      });
    } catch (e) {
      _showSnackBar('حدث خطأ أثناء الحفظ: $e', Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 تم استبدال Directionality بـ Theme مُعدل أو استخدام الـ Widgets مباشرة
    // لضمان عدم حدوث خطأ Member not found: 'rtl'
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text('إعدادات اشتراكات الحسابات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFB21F2D),
        centerTitle: true,
        elevation: 0,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl, // سيتم قراءتها الآن من Material بشكل صحيح
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))],
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderSection(),
                    const Divider(height: 40),
                    _buildUserSelection(),
                    const SizedBox(height: 25),
                    _buildSubscriptionDetails(),
                    const SizedBox(height: 30),
                    _buildAmountSection(),
                    const SizedBox(height: 40),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFB21F2D).withOpacity(0.1),
          child: const Icon(Icons.settings_applications, color: Color(0xFFB21F2D)),
        ),
        const SizedBox(width: 15),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("تسجيل اشتراك جديد", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            Text("حدد المستخدم ونوع الاشتراك لبدء المخالصة المالية", style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildUserSelection() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'جهة الاشتراك',
              prefixIcon: const Icon(Icons.category),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: const [
              DropdownMenuItem(value: 'sellers', child: Text('الموردين (Sellers)')),
              DropdownMenuItem(value: 'deliverySupermarkets', child: Text('سوبر ماركت (Delivery)')),
            ],
            onChanged: (val) => _fetchUsers(val!),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _isLoadingUsers 
            ? const Center(child: CircularProgressIndicator())
            : DropdownButtonFormField<String>(
                value: _selectedUserId,
                decoration: InputDecoration(
                  labelText: 'اختر الاسم',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: _usersList.map((u) => DropdownMenuItem(value: u['id'] as String, child: Text(u['name']))).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedUserId = val;
                    _selectedUserName = _usersList.firstWhere((u) => u['id'] == val)['name'];
                  });
                },
              ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionDetails() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _subType,
          decoration: InputDecoration(
            labelText: 'نوع الاشتراك المالي',
            prefixIcon: const Icon(Icons.star_border),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: const [
            DropdownMenuItem(value: 'شهري', child: Text('اشتراك شهري (عضوية الحساب)')),
            DropdownMenuItem(value: 'مساحة إعلانية', child: Text('اشتراك تسويقي (مساحة إعلانية)')),
          ],
          onChanged: (val) => setState(() => _subType = val!),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _datePickerTile("بداية الفترة", _startDate, (d) => setState(() => _startDate = d))),
            const SizedBox(width: 20),
            Expanded(child: _datePickerTile("نهاية الفترة", _endDate, (d) => setState(() => _endDate = d))),
          ],
        ),
      ],
    );
  }

  Widget _datePickerTile(String label, DateTime date, Function(DateTime) onSelect) {
    return InkWell(
      onTap: () async {
        DateTime? picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2025), lastDate: DateTime(2030));
        if (picked != null) onSelect(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(DateFormat('yyyy-MM-dd').format(date), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const Icon(Icons.calendar_today, size: 20, color: Color(0xFFB21F2D)),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountSection() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'القيمة المالية المستحقة',
              prefixIcon: const Icon(Icons.monetization_on),
              suffixText: 'EGP',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'ملاحظات (اختياري)',
              prefixIcon: const Icon(Icons.note_alt),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveSubscription,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFB21F2D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 5,
        ),
        child: _isSaving 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('اعتماد البيانات وبدء المخالصة', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
      ),
    );
  }
}

