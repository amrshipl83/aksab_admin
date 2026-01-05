import 'package:flutter/material.dart';
import '../models/supermarket_model.dart';

class RequestCard extends StatelessWidget {
  final SupermarketModel request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const RequestCard({
    super.key, 
    required this.request, 
    required this.onApprove, 
    required this.onReject
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      elevation: 4,
      child: ListTile(
        title: Text(request.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("العنوان: ${request.address}\nمصاريف التوصيل: ${request.deliveryFee} ج.م"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // زر المراجعة والموافقة
            IconButton(
              icon: const Icon(Icons.fact_check, color: Colors.green, size: 30),
              onPressed: onApprove, // تأكد أن هذه ليست فارغة
            ),
            // زر الرفض
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red, size: 30),
              onPressed: onReject,
            ),
          ],
        ),
      ),
    );
  }
}

