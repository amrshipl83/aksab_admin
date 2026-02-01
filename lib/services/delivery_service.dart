import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. جلب الطلبات المعلقة (مراقبة لحظية من الأدمن)
  Stream<QuerySnapshot> getPendingRequests() {
    return _db.collection('pendingSupermarkets').snapshots();
  }

  // 2. جلب الماركتات المفعلة (التي تجاوزت مرحلة القبول)
  Stream<QuerySnapshot> getActiveSupermarkets() {
    return _db.collection('deliverySupermarkets').snapshots();
  }

  // 3. تحديث حالة السوبر ماركت (نشط / معطل) - إيقاف يدوي للطوارئ
  Future<void> updateSupermarketStatus(String docId, bool status) async {
    await _db.collection('deliverySupermarkets').doc(docId).update({
      'isActive': status,
      'isVisibleInStore': status, // ربط الظهور في الستور بالحالة اليدوية أيضاً
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // 4. رفض وحذف الطلب المعلق
  Future<void> deletePendingRequest(String requestId) async {
    await _db.collection('pendingSupermarkets').doc(requestId).delete();
  }

  // 5. عملية الموافقة المطورة (نظام الـ 30 يوم المجانية)
  Future<void> approveRequest({
    required String requestId,
    required String supermarketName,
    required String address,
    required String ownerId,
    required List<Map<String, dynamic>> products,
    required Map<String, dynamic> extraData, 
  }) async {
    
    // جلب البيانات الأصلية (الإحداثيات، الأيقونة، هاتف المالك)
    DocumentSnapshot pendingSnap = await _db.collection('pendingSupermarkets').doc(requestId).get();
    Map<String, dynamic> originalData = {};
    if (pendingSnap.exists) {
      originalData = pendingSnap.data() as Map<String, dynamic>;
    }

    WriteBatch batch = _db.batch();

    // إعداد مرجع المستند في مجموعة السوبر ماركتات النشطة
    DocumentReference activeRef = _db.collection('deliverySupermarkets').doc(requestId);

    // --- منطق التوقيت والاشتراك ---
    DateTime now = DateTime.now();
    // إعطاء 30 يوم مجانية تبدأ من لحظة موافقة الأدمن
    DateTime trialExpiry = now.add(const Duration(days: 30));

    Map<String, dynamic> finalMarketData = {
      ...originalData,           // البيانات التقنية الأصلية من طلب التسجيل
      'supermarketName': supermarketName,
      'address': address,
      'ownerId': ownerId,
      'status': 'active',        
      'isActive': true,          
      'approvalDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      
      // --- حقول نظام الاشتراكات الجديد ---
      'subscriptionStatus': 'trial',          // الحالة الابتدائية: فترة تجريبية
      'currentPlan': 'الافتراضية',             // اسم الباقة المجانية
      'trialExpiryDate': Timestamp.fromDate(trialExpiry), // تاريخ انتهاء الصلاحية
      'isVisibleInStore': true,               // السماح بالظهور للمستهلك فوراً
      'isTrialUsed': true,                    // علامة أمان لعدم تكرار الفترة المجانية
      
      ...extraData,              // الرسوم والمواعيد والواتساب من الـ Dialog
    };

    // 1. إضافة الماركت للمجموعة الأساسية
    batch.set(activeRef, finalMarketData);

    // 2. إضافة المنتجات لمجموعة عروض السوق (marketOffer)
    for (var prod in products) {
      DocumentReference offerRef =
          _db.collection('marketOffer').doc("${requestId}_${prod['productId']}");
      batch.set(offerRef, {
        'ownerId': requestId,
        'supermarketName': supermarketName,
        'productId': prod['productId'],
        'units': prod['units'],
        'status': 'active',
        'isVisible': true, // لجعل المنتجات تختفي تلقائياً عند انتهاء الاشتراك
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // 3. حذف الطلب من قائمة الانتظار
    batch.delete(_db.collection('pendingSupermarkets').doc(requestId));

    // تنفيذ العملية بالكامل
    await batch.commit();
  }
}
