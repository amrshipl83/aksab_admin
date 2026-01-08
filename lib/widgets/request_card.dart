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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF2c3e50),
                child: Icon(Icons.store, color: Colors.white),
              ),
              title: Text(request.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  Text("📍 العنوان: ${request.address}"),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      _infoBadge(Icons.delivery_dining, "${request.deliveryFee} ج.م", Colors.blue),
                      const SizedBox(width: 8),
                      _infoBadge(Icons.shopping_basket, "حد أدنى: ${request.minimumOrderValue} ج.م", Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 5),
                  _infoBadge(Icons.access_time, "المواعيد: ${request.deliveryHours ?? 'غير محدد'}", Colors.grey),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.fact_check, color: Colors.green, size: 32),
                        onPressed: onApprove,
                        tooltip: "مراجعة وتفعيل",
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red, size: 32),
                        onPressed: onReject,
                        tooltip: "رفض الطلب",
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

