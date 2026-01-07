import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert'; // لتشفير البيانات
import 'dart:html' as html; // خاص بالتعامل مع المتصفح وتنزيل الملفات

class InventoryStockTab extends StatefulWidget {
  const InventoryStockTab({super.key});

  @override
  State<InventoryStockTab> createState() => _InventoryStockTabState();
}

class _InventoryStockTabState extends State<InventoryStockTab> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String superAdminId = "vdrX1zA28GWgVjX3ogEQ8zJOeYP2";

  /// دالة تصدير البيانات إلى ملف CSV متوافق مع Excel
  void _exportToCSV(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return;

    // 1. تعريف رؤوس الأعمدة
    List<String> headers = [
      "اسم المنتج",
      "الكمية المتوفرة (رصيد)",
      "الكمية المحجوزة",
      "الكمية الفعلية",
      "إجمالي الرصيد الفعلي",
      "الوحدة",
      "متوسط التكلفة",
      "آخر سعر شراء",
      "آخر تاريخ شراء"
    ];

    // 2. بناء محتوى الملف
    StringBuffer csvBuffer = StringBuffer();
    csvBuffer.writeln(headers.join(','));

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      
      double balance = (data['balance'] ?? 0).toDouble();
      double reserved = (data['reserved_stock'] ?? 0).toDouble();
      double actualQuantity = balance - reserved;
      double totalPhysical = balance + reserved;
      
      String dateStr = "-";
      if (data['lastPurchaseDate'] != null && data['lastPurchaseDate'] is Timestamp) {
        dateStr = DateFormat('yyyy-MM-dd').format((data['lastPurchaseDate'] as Timestamp).toDate());
      }

      List<String> row = [
        '"${data['productName'] ?? 'غير معروف'}"', // وضع الاسم بين علامات اقتباس لتفادي مشاكل الفواصل
        balance.toStringAsFixed(2),
        reserved.toStringAsFixed(2),
        actualQuantity.toStringAsFixed(2),
        totalPhysical.toStringAsFixed(2),
        '"${data['unit'] ?? '-'}"',
        (data['averageCost'] ?? 0).toStringAsFixed(2),
        (data['lastPurchasePrice'] ?? 0).toStringAsFixed(2),
        dateStr
      ];
      csvBuffer.writeln(row.join(','));
    }

    // 3. تحويل النص إلى ملف قابل للتنزيل
    // نستخدم \uFEFF لضمان أن Excel يفتح الملف بترميز UTF-8 ويفهم اللغة العربية
    final bytes = utf8.encode('\uFEFF${csvBuffer.toString()}');
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "inventory_report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv")
      ..click();

    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم تصدير البيانات بنجاح", style: TextStyle(fontFamily: 'Cairo'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('vendor_inventories').doc(superAdminId).collection('items').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("خطأ: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

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
                    onPressed: (snapshot.hasData && snapshot.data!.docs.isNotEmpty)
                        ? () => _exportToCSV(snapshot.data!.docs)
                        : null,
                    icon: const Icon(Icons.file_download),
                    label: const Text("تصدير إلى Excel", style: TextStyle(fontFamily: 'Cairo')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text("🚫 لا يوجد منتجات في المخزون حالياً.", style: TextStyle(fontFamily: 'Cairo', fontSize: 18)),
                  ),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
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
                          
                          String dateStr = "-";
                          if (data['lastPurchaseDate'] != null && data['lastPurchaseDate'] is Timestamp) {
                            dateStr = DateFormat('yyyy-MM-dd').format((data['lastPurchaseDate'] as Timestamp).toDate());
                          }

                          return DataRow(cells: [
                            DataCell(Text(data['productName'] ?? 'غير معروف')),
                            DataCell(Text(balance.toStringAsFixed(2))),
                            DataCell(Text(reserved.toStringAsFixed(2))),
                            DataCell(Text((balance - reserved).toStringAsFixed(2))),
                            DataCell(Text((balance + reserved).toStringAsFixed(2))),
                            DataCell(Text(data['unit'] ?? '-')),
                            DataCell(Text((data['averageCost'] ?? 0).toStringAsFixed(2))),
                            DataCell(Text((data['lastPurchasePrice'] ?? 0).toStringAsFixed(2))),
                            DataCell(Text(dateStr)),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

