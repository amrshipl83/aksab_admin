import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class InventoryStockTab extends StatefulWidget {
  const InventoryStockTab({super.key});

  @override
  State<InventoryStockTab> createState() => _InventoryStockTabState();
}

class _InventoryStockTabState extends State<InventoryStockTab> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String superAdminId = "vdrX1zA28GWgVjX3ogEQ8zJOeYP2";

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "📊 رصيد المخزون الحالي",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // هنا يمكن إضافة دالة التصدير لاحقاً
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("جاري تجهيز ملف Excel..."))
                  );
                },
                icon: const Icon(Icons.file_download),
                label: const Text("تصدير إلى Excel", style: TextStyle(fontFamily: 'Cairo')),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection('vendor_inventories').doc(superAdminId).collection('items').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("خطأ: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("🚫 لا يوجد منتجات في المخزون حالياً.", style: TextStyle(fontFamily: 'Cairo', fontSize: 18)),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(const Color(0xFF1F4287)),
                      headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      columns: const [
                        DataColumn(label: Text("اسم المنتج")),
                        DataColumn(label: Text("المتوفر")),
                        DataColumn(label: Text("المحجوز")),
                        DataColumn(label: Text("الفعلي")),
                        DataColumn(label: Text("الإجمالي")),
                        DataColumn(label: Text("الوحدة")),
                        DataColumn(label: Text("متوسط التكلفة")),
                        DataColumn(label: Text("آخر سعر")),
                        DataColumn(label: Text("تاريخ الشراء")),
                      ],
                      rows: snapshot.data!.docs.map((doc) {
                        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                        
                        double balance = (data['balance'] ?? 0).toDouble();
                        double reserved = (data['reserved_stock'] ?? 0).toDouble();
                        
                        // معالجة التاريخ
                        String dateStr = "-";
                        if (data['lastPurchaseDate'] != null) {
                          if (data['lastPurchaseDate'] is Timestamp) {
                            dateStr = DateFormat('yyyy-MM-dd').format((data['lastPurchaseDate'] as Timestamp).toDate());
                          }
                        }

                        return DataRow(cells: [
                          DataCell(Text(data['productName'] ?? 'غير معروف')),
                          DataCell(Text(balance.toStringAsFixed(2))),
                          DataCell(Text(reserved.toStringAsFixed(2))),
                          DataCell(Text((balance - reserved).toStringAsFixed(2))),
                          DataCell(Text((balance + reserved).toStringAsFixed(2))),
                          DataCell(Text(data['unit'] ?? '-')),
                          DataCell(Text("${(data['averageCost'] ?? 0).toStringAsFixed(2)}")),
                          DataCell(Text("${(data['lastPurchasePrice'] ?? 0).toStringAsFixed(2)}")),
                          DataCell(Text(dateStr)),
                        ]);
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

