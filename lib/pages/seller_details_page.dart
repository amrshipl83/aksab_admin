import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SellerDetailsPage extends StatefulWidget {
  final String sellerId;
  final Map<String, dynamic> sellerData;

  const SellerDetailsPage({super.key, required this.sellerId, required this.sellerData});

  @override
  State<SellerDetailsPage> createState() => _SellerDetailsPageState();
}

class _SellerDetailsPageState extends State<SellerDetailsPage> {
  // دالة الحماية من البيانات الفارغة
  String _f(dynamic val) => (val == null || val.toString().isEmpty) ? "—" : val.toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: Text(widget.sellerData['supermarketName'] ?? "تفاصيل التاجر"),
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            
            // قسم الحسابات المالية
            _buildSection("المؤشرات المالية", Icons.monetization_on, [
              EditableInfoRow(
                label: "نسبة العمولة",
                value: _f(widget.sellerData['commissionRate']),
                field: "commissionRate",
                sellerId: widget.sellerId,
                isNumber: true,
                suffix: " %",
              ),
              EditableInfoRow(
                label: "مديونية الكاش باك",
                value: _f(widget.sellerData['cashbackAccruedDebt']),
                field: "cashbackAccruedDebt",
                sellerId: widget.sellerId,
                isNumber: true,
                suffix: " ج.م",
              ),
            ], color: Colors.green),

            // قسم البيانات البنكية
            _buildSection("بيانات التحويل البنكي", Icons.account_balance, [
              EditableInfoRow(
                label: "اسم البنك",
                value: _f(widget.sellerData['bankName']),
                field: "bankName",
                sellerId: widget.sellerId,
              ),
              EditableInfoRow(
                label: "رقم الحساب",
                value: _f(widget.sellerData['bankAccountNumber']),
                field: "bankAccountNumber",
                sellerId: widget.sellerId,
              ),
              EditableInfoRow(
                label: "رقم الـ IBAN",
                value: _f(widget.sellerData['iban']),
                field: "iban",
                sellerId: widget.sellerId,
              ),
            ], color: Colors.blue),

            // قسم التشغيل
            _buildSection("إعدادات التشغيل", Icons.delivery_dining, [
              EditableInfoRow(
                label: "رسوم التوصيل",
                value: _f(widget.sellerData['deliveryFee']),
                field: "deliveryFee",
                sellerId: widget.sellerId,
                isNumber: true,
              ),
            ], color: Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.amber[100],
            child: const Icon(Icons.store, size: 35, color: Colors.amber),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_f(widget.sellerData['fullname']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text("ID: ${widget.sellerId}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> items, {required Color color}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: color),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(12), child: Column(children: items)),
        ],
      ),
    );
  }
}

// ✅ الويدجت السحرية للتعديل المباشر في السطر
class EditableInfoRow extends StatefulWidget {
  final String label;
  final String value;
  final String field;
  final String sellerId;
  final bool isNumber;
  final String suffix;

  const EditableInfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.field,
    required this.sellerId,
    this.isNumber = false,
    this.suffix = "",
  });

  @override
  State<EditableInfoRow> createState() => _EditableInfoRowState();
}

class _EditableInfoRowState extends State<EditableInfoRow> {
  bool _isEditing = false;
  bool _isLoading = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value == "—" ? "" : widget.value);
  }

  Future<void> _saveChange() async {
    setState(() => _isLoading = true);
    try {
      dynamic finalValue = _controller.text;
      if (widget.isNumber) {
        finalValue = double.tryParse(_controller.text) ?? 0;
      }

      await FirebaseFirestore.instance
          .collection('sellers')
          .doc(widget.sellerId)
          .update({widget.field: finalValue});

      setState(() {
        _isEditing = false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ في التحديث: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(widget.label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(width: 10),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _isEditing
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            autofocus: true,
                            keyboardType: widget.isNumber ? TextInputType.number : TextInputType.text,
                            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: _saveChange),
                        IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => _isEditing = false)),
                      ],
                    )
                  : InkWell(
                      onTap: () => setState(() => _isEditing = true),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isLoading)
                            const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                          else
                            const Icon(Icons.edit, size: 14, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Text("${widget.value}${widget.suffix}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

