import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminFAQScreen extends StatefulWidget {
  static const routeName = '/admin-faq';
  const AdminFAQScreen({super.key});

  @override
  State<AdminFAQScreen> createState() => _AdminFAQScreenState();
}

class _AdminFAQScreenState extends State<AdminFAQScreen> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  
  // ✅ تم تغيير اسم المجموعة ليتوافق مع الـ Backend
  final CollectionReference _faqCollection =
      FirebaseFirestore.instance.collection('all_questions');

  // دالة مساعدة لتوليد الكلمات الدلالية (Keywords) كما تتوقعها الدالة البرمجية
  List<String> _generateKeywords(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[؟?!.,/\\#@!%^&*()_+={}\[\]|:;\"<>]'), '') // تنظيف النص
        .split(RegExp(r'\s+')) // التقسيم بناءً على المسافات
        .where((word) => word.length > 2) // استبعاد الكلمات القصيرة جداً
        .toSet() // إزالة التكرار
        .toList();
  }

  // إضافة سؤال جديد
  Future<void> _addQuestion() async {
    final String question = _questionController.text.trim();
    final String answer = _answerController.text.trim();

    if (question.isEmpty || answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال السؤال والإجابة')),
      );
      return;
    }

    try {
      // ✅ توليد الكلمات الدلالية لضمان عثور البوت على الإجابة
      List<String> keywords = _generateKeywords(question);

      await _faqCollection.add({
        'question': question,
        'answer': answer,
        'keywords': keywords, // الحقل المطلوب في دالة البحث (Fuzzy Match)
        'createdAt': FieldValue.serverTimestamp(),
      });

      _questionController.clear();
      _answerController.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إضافة السؤال بنجاح وتفعيل البحث الذكي')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
  }

  // حذف سؤال
  Future<void> _deleteQuestion(String id) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد أنك تريد حذف هذا السؤال من قاعدة معرفة البوت؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              await _faqCollection.doc(id).delete();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double contentWidth = screenWidth > 800 ? 800 : screenWidth * 0.95;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة قاعدة معرفة البوت (FAQ)'),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
        ),
        backgroundColor: const Color(0xFFF4F4F4),
        body: Center(
          child: SizedBox(
            width: contentWidth,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildFormCard(),
                  const SizedBox(height: 30),
                  _buildListCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إضافة سؤال وجواب للبوت',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildLabel('السؤال المتوقع من المستخدم:'),
            TextField(
              controller: _questionController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'مثال: كيف يمكنني تتبع طلبي؟',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            _buildLabel('إجابة البوت الثابتة:'),
            TextField(
              controller: _answerController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'اكتب الإجابة التي سيقوم البوت بالرد بها مباشرة...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: _addQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28A745),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: const Text('حفظ في قاعدة المعرفة',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text('الأسئلة المفعلة حالياً',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: _faqCollection.orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('حدث خطأ في جلب البيانات'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('لا توجد أسئلة في قاعدة المعرفة حاليًا.')),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['question'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(data['answer'] ?? ''),
                          const SizedBox(height: 4),
                          // إظهار الكلمات الدلالية للتأكد من عمل النظام (اختياري)
                          if (data['keywords'] != null)
                            Wrap(
                              spacing: 5,
                              children: (data['keywords'] as List)
                                  .map((k) => Chip(
                                        label: Text(k, style: const TextStyle(fontSize: 10)),
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: Colors.green.withOpacity(0.1),
                                      ))
                                  .toList(),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteQuestion(doc.id),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
    );
  }
}

