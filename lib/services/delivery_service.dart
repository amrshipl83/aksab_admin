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

  // 3. تحديث حالة السوبر ماركت (نشط / معطل)
  Future<void> updateSupermarketStatus(String docId, bool status) async {
    await _db.collection('deliverySupermarkets').doc(docId).update({
      'isActive': status,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // 4. رفض وحذف الطلب المعلق
  Future<void> deletePendingRequest(String requestId) async {
    await _db.collection('pendingSupermarkets').doc(requestId).delete();
  }

  // 5. عملية الموافقة المطورة (Batch Write)
  Future<void> approveRequest({
    required String requestId,
    required String supermarketName,
    required String address,
    required String ownerId,
    required List<Map<String, dynamic>> products,
    required Map<String, dynamic> extraData, // البيانات اللوجستية المحدثة من المنبثقة
  }) async {
    WriteBatch batch = _db.batch();

    // أ- إضافة للمفعلين (deliverySupermarkets)
    DocumentReference activeRef = _db.collection('deliverySupermarkets').doc(requestId);
    
    // تجميع البيانات النهائية للماركت
    Map<String, dynamic> finalMarketData = {
      'supermarketName': supermarketName,
      'address': address,
      'ownerId': ownerId,
      'status': 'active',
      'isActive': true,
      'approvalDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      // دمج البيانات اللوجستية المحدثة (fee, minOrder, whatsapp, hours)
      ...extraData, 
    };

    batch.set(activeRef, finalMarketData);

    // ب- إضافة عروض المنتجات المسعرة (marketOffer)
    for (var prod in products) {
      DocumentReference offerRef =
          _db.collection('marketOffer').doc("${requestId}_${prod['productId']}");
      batch.set(offerRef, {
        'ownerId': requestId,
        'supermarketName': supermarketName,
        'productId': prod['productId'],
        'units': prod['units'],
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // ج- حذف من مجموعة "تحت المراجعة"
    batch.delete(_db.collection('pendingSupermarkets').doc(requestId));

    // تنفيذ كل العمليات في وقت واحد لضمان سلامة البيانات
    await batch.commit();
  }
}

