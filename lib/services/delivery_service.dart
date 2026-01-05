import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. جلب الطلبات المعلقة
  Stream<QuerySnapshot> getPendingRequests() {
    return _db.collection('pendingSupermarkets').snapshots();
  }

  // 2. جلب الماركتات المفعلة
  Stream<QuerySnapshot> getActiveSupermarkets() {
    return _db.collection('deliverySupermarkets').snapshots();
  }

  // 3. تحديث حالة السوبر ماركت (نشط / معطل) - "جديد"
  Future<void> updateSupermarketStatus(String docId, bool status) async {
    await _db.collection('deliverySupermarkets').doc(docId).update({
      'isActive': status,
    });
  }

  // 4. رفض وحذف الطلب المعلق - "جديد"
  Future<void> deletePendingRequest(String requestId) async {
    await _db.collection('pendingSupermarkets').doc(requestId).delete();
  }

  // 5. عملية الموافقة (Batch Write)
  Future<void> approveRequest(
      String requestId,
      String name,
      String address,
      double? fee,
      List<Map<String, dynamic>> products) async {
    WriteBatch batch = _db.batch();

    // أ- إضافة للمفعلين
    DocumentReference activeRef = _db.collection('deliverySupermarkets').doc(requestId);
    batch.set(activeRef, {
      'supermarketName': name,
      'address': address,
      'deliveryFee': fee,
      'status': 'active',
      'isActive': true,
      'approvalDate': FieldValue.serverTimestamp(),
    });

    // ب- إضافة عروض المنتجات المسعرة
    for (var prod in products) {
      DocumentReference offerRef =
          _db.collection('marketOffer').doc("${requestId}_${prod['productId']}");
      batch.set(offerRef, {
        'ownerId': requestId,
        'supermarketName': name,
        'productId': prod['productId'],
        'units': prod['units'],
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // ج- حذف من المعلقين
    batch.delete(_db.collection('pendingSupermarkets').doc(requestId));

    await batch.commit();
  }
}

