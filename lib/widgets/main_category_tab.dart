import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MainCategoryTab extends StatefulWidget {
  @override
  _MainCategoryTabState createState() => _MainCategoryTabState();
}

class _MainCategoryTabState extends State<MainCategoryTab> {
  String categoryName = '';
  String offerBehavior = 'supermarket_offers'; // القيمة الافتراضية

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(labelText: 'اسم القسم الرئيسي', border: OutlineInputBorder()),
            onChanged: (val) => categoryName = val,
          ),
          SizedBox(height: 15),
          DropdownButtonFormField(
            value: offerBehavior,
            items: [
              DropdownMenuItem(value: 'supermarket_offers', child: Text('عروض السوبر ماركت')),
              DropdownMenuItem(value: 'direct_seller_offers', child: Text('عروض التاجر المباشرة')),
            ],
            onChanged: (val) => setState(() => offerBehavior = val as String),
            decoration: InputDecoration(labelText: 'سلوك العرض'),
          ),
          SizedBox(height: 20),
          ElevatedButton(onPressed: () {}, child: Text("إضافة قسم رئيسي"))
        ],
      ),
    );
  }
}

