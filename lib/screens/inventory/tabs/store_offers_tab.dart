import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:html' as html; // ضروري لعملية التصدير على الويب

class StoreOffersTab extends StatefulWidget {
  const StoreOffersTab({super.key});

  @override
  State<StoreOffersTab> createState() => _StoreOffersTabState();
}

class _StoreOffersTabState extends State<StoreOffersTab> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  // المعرف الثابت المستخدم في كود الـ HTML الخاص بك
  final String superAdminId = "4KflsGbA1vRWeuZOU18yo35T3nw2";

  /// دالة التصدير إلى Excel (CSV) بنفس منطق الـ JavaScript
  void _exportToCSV(List<Map<String, dynamic>> flatData) {
    if (flatData.isEmpty) return;

    // رؤوس الأعمدة كما في الكود الأصلي
    List<String> headers = ["اسم المنتج", "الوحدة", "الكمية المتوفرة (عرض)"];
    
    StringBuffer csvBuffer = StringBuffer();
    csvBuffer.writeln(headers.join(','));

    for (var row in flatData) {
      csvBuffer.writeln('"${row['name']}","${row['unit']}","${row['stock']}"');
    }

    // إضافة BOM لدعم اللغة العربية في Excel
    final bytes = utf8.encode('\uFEFF${csvBuffer.toString()}');
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "تقرير_رصيد_العروض_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv")
      ..click();

    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم تصدير البيانات بنجاح", style: TextStyle(fontFamily: 'Cairo'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان الرئيسي بتنسيق الـ CSS (h1)
          const Center(
            child: Text(
              "✨ رصيد العروض الحالية",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
                color: Color(0xFF1F4287), // نفس اللون الأزرق في الكود الأصلي
              ),
            ),
          ),
          const SizedBox(height: 30),

          // شريط التحكم (Controls Bar)
          StreamBuilder<QuerySnapshot>(
            stream: _db.collection('productOffers')
                .where('sellerId', isEqualTo: superAdminId)
                .snapshots(),
            builder: (context, snapshot) {
              // معالجة البيانات وتحويلها لـ Flat List (فك مصفوفة الوحدات)
              List<Map<String, dynamic>> flatList = [];
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  var units = data['units'] as List<dynamic>? ?? [];
                  for (var u in units) {
                    flatList.add({
                      'name': data['productName'] ?? 'غير معروف',
                      'unit': u['unitName'] ?? '-',
                      'stock': (u['availableStock'] ?? 0).toDouble(),
                    });
                  }
                }
              }

              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: flatList.isEmpty ? null : () => _exportToCSV(flatList),
                        icon: const Icon(Icons.file_download),
                        label: const Text("تصدير إلى Excel", style: TextStyle(fontFamily: 'Cairo')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF28A745), // لون الزر الأخضر الأصلي
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // الجدول أو رسالة "لا توجد بيانات"
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(child: CircularProgressIndicator())
                  else if (flatList.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCED4DA), style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text("🚫 لا يوجد عروض متاحة حالياً.", 
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 18, color: Color(0xFF6C757D))),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: const Color(0xFFE9ECEF)),
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(const Color(0xFF1F4287)),
                          headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                          columns: const [
                            DataColumn(label: Text("اسم المنتج")),
                            DataColumn(label: Text("الوحدة")),
                            DataColumn(label: Text("الكمية المتوفرة (عرض)")),
                          ],
                          rows: flatList.map((item) => DataRow(
                            cells: [
                              DataCell(Text(item['name'])),
                              DataCell(Text(item['unit'])),
                              DataCell(Text(item['stock'].toStringAsFixed(2))),
                            ],
                          )).toList(),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

