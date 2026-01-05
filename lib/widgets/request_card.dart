import 'package:flutter/material.dart';
import '../models/supermarket_model.dart';

class RequestCard extends StatelessWidget {
  final SupermarketModel request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const RequestCard({super.key, required this.request, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(10),
      child: ListTile(
        title: Text(request.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("العنوان: ${request.address}\nالتوصيل: ${request.deliveryFee} ج.م"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: onApprove),
            IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: onReject),
          ],
        ),
      ),
    );
  }
}

