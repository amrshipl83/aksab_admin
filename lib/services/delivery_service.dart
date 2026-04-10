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
      'isVisibleInStore': status,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // 4. رفض وحذف الطلب المعلق
  Future<void> deletePendingRequest(String requestId) async {
    await _db.collection('pendingSupermarkets').doc(requestId).delete();
  }

  // 5. عملية الموافقة المطورة (نظام البحث السريع بالحشر المباشر)
  Future<void> approveRequest({
    required String requestId,
    required String supermarketName,
    required String address,
    required String ownerId,
    required List<Map<String, dynamic>> products,
    required Map<String, dynamic> extraData,
  }) async {
    // جلب البيانات الأصلية
    DocumentSnapshot pendingSnap = await _db.collection('pendingSupermarkets').doc(requestId).get();
    Map<String, dynamic> originalData = {};
    if (pendingSnap.exists) {
      originalData = pendingSnap.data() as Map<String, dynamic>;
    }

    WriteBatch batch = _db.batch();
    DocumentReference activeRef = _db.collection('deliverySupermarkets').doc(requestId);

    // --- منطق التوقيت والاشتراك المتغير ---
    DateTime now = DateTime.now();

    // قراءة المدة من البيانات المرسلة من اللوحة (الافتراضي 30 يوم إذا لم يرسل)
    int trialDays = extraData['customTrialDays'] ?? 30;
    DateTime trialExpiry = now.add(Duration(days: trialDays));

    Map<String, dynamic> finalMarketData = {
      ...originalData,
      'supermarketName': supermarketName,
      'address': address,
      'ownerId': ownerId,
      'status': 'active',
      'isActive': true,
      'approvalDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),

      // --- حقول نظام الاشتراكات المحدثة بقيمة متغيرة ---
      'subscriptionStatus': 'trial',
      'currentPlan': 'الافتراضية',
      'trialExpiryDate': Timestamp.fromDate(trialExpiry),
      'isVisibleInStore': true,
      'isTrialUsed': true,
      'selectedTrialPeriod': trialDays, // توثيق المدة المختارة للرجوع إليها
      ...extraData,
    };

    // 1. إضافة الماركت للمجموعة الأساسية
    batch.set(activeRef, finalMarketData);

    // 2. إضافة المنتجات لمجموعة عروض السوق (مع حشر البيانات للبحث السريع) 🚀
    for (var prod in products) {
      DocumentReference offerRef = _db.collection('marketOffer').doc("${requestId}_${prod['productId']}");
      
      batch.set(offerRef, {
        'ownerId': requestId,
        'supermarketName': supermarketName,
        'productId': prod['productId'],
        'units': prod['units'],
        'status': 'active',
        'isVisible': true,
        'createdAt': FieldValue.serverTimestamp(),
        
        // 🎯 البيانات المحشورة لضمان سرعة تطبيق المستهلك:
        'productName': prod['name'] ?? 'منتج',
        'productImage': prod['imageUrl'] ?? '',
        'mainCategoryId': prod['mainId'] ?? '',
        'subCategoryId': prod['subId'] ?? '',
      });
    }

    // 3. حذف الطلب من قائمة الانتظار
    batch.delete(_db.collection('pendingSupermarkets').doc(requestId));

    await batch.commit();
  }
}

