import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'add_expense_screen.dart';

class GeneralExpensesScreen extends StatefulWidget {
  const GeneralExpensesScreen({super.key});

  @override
  State<GeneralExpensesScreen> createState() => _GeneralExpensesScreenState();
}

class _GeneralExpensesScreenState extends State<GeneralExpensesScreen> {
  final List<DocumentSnapshot> _expenses = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _indexErrorUrl; 
  String _activeFilter = 'all'; 
  final int _documentLimit = 8;
  DocumentSnapshot? _lastDocument;

  final Map<String, String> _expenseSources = {
    'all': 'الكل',
    'office': 'إيجار ومرافق',
    'salaries': 'مرتبات',
    'marketing': 'تسويق',
    'maintenance': 'صيانة',
    'other': 'أخرى',
  };

  @override
  void initState() {
    super.initState();
    _getExpenses();
  }

  Future<void> _getExpenses({bool isRefresh = false}) async {
    if (_isLoading || (!_hasMore && !isRefresh)) return;

    setState(() {
      _isLoading = true;
      _indexErrorUrl = null; 
      if (isRefresh) {
        _expenses.clear();
        _lastDocument = null;
        _hasMore = true;
      }
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('platform_ledger')
          .where('entryType', isEqualTo: 'expense');

      if (_activeFilter != 'all') {
        query = query.where('source', isEqualTo: _activeFilter);
      }

      query = query.orderBy('createdAt', descending: true).limit(_documentLimit);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      QuerySnapshot querySnapshot = await query.get();
      
      if (querySnapshot.docs.length < _documentLimit) {
        _hasMore = false;
      }

      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        _expenses.addAll(querySnapshot.docs);
      }
    } catch (e) {
      String errorStr = e.toString();
      if (errorStr.contains('https://console.firebase.google.com')) {
        int startIndex = errorStr.indexOf('https://');
        _indexErrorUrl = errorStr.substring(startIndex).split(' ').first;
      }
      debugPrint("Error: $e");
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text("المصروفات العامة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFB21F2D),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildTotalExpensesHeader(),
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              children: _expenseSources.entries.map((e) => _buildFilterChip(e.key, e.value)).toList(),
            ),
          ),
          Expanded(
            child: _indexErrorUrl != null 
              ? _buildIndexErrorUI() 
              : _expenses.isEmpty && _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _expenses.isEmpty
                    ? const Center(child: Text("لا توجد بيانات لهذه الفئة", style: TextStyle(fontFamily: 'Cairo')))
                    : RefreshIndicator(
                        onRefresh: () => _getExpenses(isRefresh: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          itemCount: _expenses.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _expenses.length) {
                              return _buildLoadMoreButton();
                            }
                            var data = _expenses[index].data() as Map<String, dynamic>;
                            return _buildExpenseCard(data);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddExpenseScreen()));
          _getExpenses(isRefresh: true);
        },
        backgroundColor: const Color(0xFFB21F2D),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    bool isSelected = _activeFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontFamily: 'Cairo', color: isSelected ? Colors.white : Colors.black)),
        selected: isSelected,
        selectedColor: const Color(0xFFB21F2D),
        onSelected: (val) {
          if (val) {
            setState(() => _activeFilter = key);
            _getExpenses(isRefresh: true);
          }
        },
      ),
    );
  }

  // ✅ التصحيح هنا: استخدام Padding مع Center
  Widget _buildIndexErrorUI() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 80),
            const SizedBox(height: 10),
            const Text("مطلوب تفعيل الـ Index", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)),
            const Text("هذا الإجراء مطلوب مرة واحدة عند استخدام الفلتر لأول مرة", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo')),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(_indexErrorUrl!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              icon: const Icon(Icons.open_in_new, color: Colors.white),
              label: const Text("تفعيل الـ Index الآن", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Center(
        child: _isLoading 
          ? const CircularProgressIndicator()
          : TextButton(onPressed: _getExpenses, child: const Text("عرض المزيد 👇", style: TextStyle(fontFamily: 'Cairo'))),
      ),
    );
  }

  Widget _buildTotalExpensesHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('platform_ledger').where('entryType', isEqualTo: 'expense').snapshots(),
      builder: (context, snapshot) {
        double total = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            total += (doc['totalAmount'] ?? 0).toDouble();
          }
        }
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(15),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)]),
          child: Column(
            children: [
              const Text("إجمالي المصروفات", style: TextStyle(fontFamily: 'Cairo', color: Colors.grey)),
              Text("${NumberFormat('#,###').format(total)} ج.م", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFB21F2D))),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> data) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(data['details'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        subtitle: Text("${data['period']} | ${_expenseSources[data['source']] ?? data['source']}", style: const TextStyle(fontSize: 12)),
        trailing: Text("-${data['totalAmount']} ج.م", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        onTap: () {
          if (data['attachmentUrl'] != null) {
             _showImage(data['attachmentUrl']);
          }
        },
      ),
    );
  }

  void _showImage(String url) {
    showDialog(context: context, builder: (context) => AlertDialog(content: Image.network(url), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("إغلاق"))]));
  }
}

