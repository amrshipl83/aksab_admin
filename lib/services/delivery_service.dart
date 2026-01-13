import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. جلب الطلبات المعلقة (مراقبة لحظية)
  Stream<QuerySnapshot> getPendingRequests() {
    return _db.collection('pendingSupermarkets').snapshots();
  }

  // 2. جلب الماركتات المفعلة (الموجودة في رادار المستهلك)
  Stream<QuerySnapshot> getActiveSupermarkets() {
    return _db.collection('deliverySupermarkets').snapshots();
  }

  // 3. تحديث حالة السوبر ماركت (نشط / معطل) - تشغيل وإيقاف يدوي من الأدمن
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
  // تضمن نقل البيانات الجغرافية والتصنيفية كاملة مع تفعيل عروض المنتجات
  Future<void> approveRequest({
    required String requestId,
    required String supermarketName,
    required String address,
    required String ownerId,
    required List<Map<String, dynamic>> products,
    required Map<String, dynamic> extraData, // البيانات اللوجستية المحدثة من الـ Dialog
  }) async {
    
    // --- خطوة استباقية: جلب كامل البيانات المخزنة في طلب الانتظار ---
    // لضمان سحب الـ location والـ storeType والـ storeIcon
    DocumentSnapshot pendingSnap = await _db.collection('pendingSupermarkets').doc(requestId).get();
    Map<String, dynamic> originalData = {};
    if (pendingSnap.exists) {
      originalData = pendingSnap.data() as Map<String, dynamic>;
    }

    WriteBatch batch = _db.batch();

    // أ- إعداد مرجع المستند في مجموعة "المقبولين"
    DocumentReference activeRef = _db.collection('deliverySupermarkets').doc(requestId);

    // تجميع البيانات النهائية للماركت:
    // ندمج (البيانات الأصلية) + (التعديلات الإدارية من الـ Dialog)
    Map<String, dynamic> finalMarketData = {
      ...originalData,           // تشمل الإحداثيات، الأيقونة، نوع النشاط، هاتف المالك
      'supermarketName': supermarketName,
      'address': address,
      'ownerId': ownerId,
      'status': 'active',        // تم قبول الطلب
      'isActive': true,          // تفعيل الظهور للمستهلك فوراً
      'approvalDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      ...extraData,              // دمج رسوم التوصيل، الحد الأدنى، الواتساب، المواعيد (لو تم تعديلهم)
    };

    // إضافة البيانات لمجموعة المقبولين
    batch.set(activeRef, finalMarketData);

    // ب- إضافة عروض المنتجات المسعرة لربطها بالماركت (marketOffer)
    for (var prod in products) {
      DocumentReference offerRef =
          _db.collection('marketOffer').doc("${requestId}_${prod['productId']}");
      batch.set(offerRef, {
        'ownerId': requestId,
        'supermarketName': supermarketName,
        'productId': prod['productId'],
        'units': prod['units'], // تشمل السعر والوحدة
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // ج- حذف الطلب من مجموعة "الانتظار" (لإخفائه من لوحة الإدارة ولدى التاجر)
    batch.delete(_db.collection('pendingSupermarkets').doc(requestId));

    // تنفيذ كل العمليات دفعة واحدة (Atomic Transaction)
    await batch.commit();
  }
}

