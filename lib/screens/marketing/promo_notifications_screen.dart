import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

class PromoNotificationsScreen extends StatefulWidget {
  const PromoNotificationsScreen({super.key});

  @override
  State<PromoNotificationsScreen> createState() => _PromoNotificationsScreenState();
}

class _PromoNotificationsScreenState extends State<PromoNotificationsScreen> {
  // الروابط الخاصة بالـ API لديك
  final String TOPIC_API = 'https://tx85tvinb2.execute-api.us-east-1.amazonaws.com/V1/get_topic';
  final String SEND_API = 'https://o5d9ke4l82.execute-api.us-east-1.amazonaws.com/V1/m_nofiction';

  // إعدادات Cloudinary الخاصة بك
  final String cloudName = "dgmmx6jbu"; 
  final String uploadPreset = "commerce";

  final TextEditingController _titleCtrl = TextEditingController(text: "أكسب 💰");
  final TextEditingController _msgCtrl = TextEditingController();
  final TextEditingController _imgUrlCtrl = TextEditingController();
  
  String? _selectedTopic;
  String _selectedSound = 'default';
  String _targetScreen = 'Home'; 
  List<String> _topics = [];
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchTopics();
  }

  Future<void> _fetchTopics() async {
    try {
      final response = await http.get(Uri.parse(TOPIC_API));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _topics = List<String>.from(data['topics']);
          if (_topics.isNotEmpty) _selectedTopic = _topics[0];
        });
      }
    } catch (e) {
      debugPrint("Error fetching topics: $e");
    }
  }

  // دالة اختيار ورفع الصورة لـ Cloudinary
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() => _isUploading = true);
      try {
        final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
        final bytes = await pickedFile.readAsBytes();
        
        final request = http.MultipartRequest('POST', url)
          ..fields['upload_preset'] = uploadPreset
          ..fields['folder'] = 'promoNotifications'
          ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: pickedFile.name));

        final response = await request.send();
        if (response.statusCode == 200) {
          final data = jsonDecode(await response.stream.bytesToString());
          setState(() {
            _imgUrlCtrl.text = data['secure_url']; // وضع الرابط تلقائياً
          });
          _showSnackBar("تم رفع الصورة بنجاح", Colors.green);
        } else {
          _showSnackBar("فشل رفع الصورة للسيرفر", Colors.red);
        }
      } catch (e) {
        _showSnackBar("خطأ أثناء الرفع", Colors.red);
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _sendNotification() async {
    if (_selectedTopic == null || _msgCtrl.text.isEmpty) {
      _showSnackBar("يرجى كتابة نص الرسالة واختيار الجمهور", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(SEND_API),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'topic': _selectedTopic,
          'title': _titleCtrl.text,
          'message': _msgCtrl.text,
          'image': _imgUrlCtrl.text,
          'sound': _selectedSound,
          'data': {
            'screen': _targetScreen,
            'image': _imgUrlCtrl.text,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          }
        }),
      );

      if (response.statusCode == 200) {
        _showSnackBar("تم إرسال الإشعار بنجاح!", Colors.green);
        _msgCtrl.clear();
        _imgUrlCtrl.clear();
      } else {
        _showSnackBar("فشل الإرسال: ${response.body}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("حدث خطأ في الاتصال بالشبكة", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: color)
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F5),
      appBar: AppBar(
        title: const Text("إرسال إشعار ترويجي", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        backgroundColor: const Color(0xFF1A2C3D),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel("اختر الجمهور المستهدف:"),
                  DropdownButtonFormField<String>(
                    value: _selectedTopic,
                    items: _topics.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) => setState(() => _selectedTopic = val),
                    decoration: _inputDecoration(),
                  ),
                  const SizedBox(height: 15),
                  _buildLabel("عنوان الإشعار:"),
                  TextField(controller: _titleCtrl, decoration: _inputDecoration()),
                  const SizedBox(height: 15),
                  _buildLabel("نص الرسالة:"),
                  TextField(controller: _msgCtrl, maxLines: 3, decoration: _inputDecoration(hint: "اكتب رسالتك هنا...")),
                  const SizedBox(height: 15),
                  
                  _buildLabel("صورة الإشعار:"),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _imgUrlCtrl, 
                          decoration: _inputDecoration(hint: "رابط الصورة سيظهر هنا...")
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _isUploading ? null : _pickAndUploadImage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                        ),
                        child: _isUploading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.cloud_upload, color: Colors.white),
                      )
                    ],
                  ),
                  
                  const SizedBox(height: 15),
                  _buildLabel("اختر النغمة المتكلمة:"),
                  DropdownButtonFormField<String>(
                    value: _selectedSound,
                    items: const [
                      DropdownMenuItem(value: 'default', child: Text("الافتراضية")),
                      DropdownMenuItem(value: 'order_new', child: Text("نغمة: طلب جديد")),
                      DropdownMenuItem(value: 'order_cancel', child: Text("نغمة: إلغاء طلب")),
                      DropdownMenuItem(value: 'promo_msg', child: Text("نغمة: عرض ترويجي")),
                      DropdownMenuItem(value: 'wallet_add', child: Text("نغمة: شحن محفظة")),
                      DropdownMenuItem(value: 'urgent_alert', child: Text("نغمة: تنبيه عاجل")),
                    ],
                    onChanged: (val) => setState(() => _selectedSound = val!),
                    decoration: _inputDecoration(),
                  ),
                  const SizedBox(height: 15),
                  _buildLabel("عند الضغط يفتح صفحة:"),
                  DropdownButtonFormField<String>(
                    value: _targetScreen,
                    items: const [
                      DropdownMenuItem(value: 'Home', child: Text("الرئيسية")),
                      DropdownMenuItem(value: 'Orders', child: Text("قائمة الطلبات")),
                      DropdownMenuItem(value: 'Wallet', child: Text("المحفظة")),
                      DropdownMenuItem(value: 'Offers', child: Text("صفحة العروض")),
                    ],
                    onChanged: (val) => setState(() => _targetScreen = val!),
                    decoration: _inputDecoration(),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendNotification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("إرسال الآن", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) => InputDecoration(
    hintText: hint,
    fillColor: const Color(0xFFF9F9F9),
    filled: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.deepPurple, width: 2)),
  );

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, right: 5),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14)),
  );
}

