import 'package:url_launcher/url_launcher.dart';

/// Service for handling Whatsapp click-to-chat with intelligent Egyptian number normalization.
class WhatsappService {
  WhatsappService._();

  /// Intelligently normalizes Egyptian numbers to international format (starting with 20)
  /// Examples:
  /// '01012345678' -> '201012345678'
  /// '+20 111 234 5678' -> '201112345678'
  /// '00201212345678' -> '201212345678'
  /// '201512345678' -> '201512345678'
  static String? normalizeEgyptianNumber(String phone) {
    // Remove all whitespace, dashes, parentheses and non-digit characters except leading '+'
    var clean = phone.replaceAll(RegExp(r'[\s\-()]+'), '');
    
    // Strip leading '+' or '00'
    if (clean.startsWith('+')) {
      clean = clean.substring(1);
    } else if (clean.startsWith('00')) {
      clean = clean.substring(2);
    }

    if (clean.isEmpty) return null;

    // If it already starts with Egyptian country code '20'
    if (clean.startsWith('20') && clean.length >= 11) {
      return clean;
    }

    // If it starts with local prefix '01' (010, 011, 012, 015)
    if (clean.startsWith('01') && clean.length == 11) {
      return '20${clean.substring(1)}';
    }

    // If it is 10 digits starting with '1' (e.g. 10xxxxxxxx, 11xxxxxxxx, 12xxxxxxxx, 15xxxxxxxx)
    if (clean.startsWith('1') && clean.length == 10) {
      return '20$clean';
    }

    // Non-egyptian or already fully formatted international number
    return clean;
  }

  /// Format payment reminder message in Arabic
  static String getPaymentReminder(String memberName, double amount) {
    return 'السلام عليكم يا كابتن $memberName، نود تذكيرك بوجود دفعة مستحقة لاشتراكك في جيم الديب بقيمة $amount ج.م. شكراً لك! 💪';
  }

  /// Format membership expiring reminder message in Arabic
  static String getExpiryReminder(String memberName, String planName, String endDateStr) {
    return 'السلام عليكم يا كابتن $memberName، نود تذكيرك بأن اشتراكك ($planName) في جيم الديب ينتهي قريباً بتاريخ $endDateStr. يسعدنا استمرار تمرينك معنا! 🏋️‍♂️';
  }

  /// Format general contact message in Arabic
  static String getGeneralContact(String memberName) {
    return 'السلام عليكم يا كابتن $memberName، نأمل أن تكون بخير وبكامل النشاط! نتشرف بالتواصل معك من جيم الديب. 🦁';
  }

  /// Launch WhatsApp click-to-chat
  static Future<bool> launchWhatsApp({
    required String phone,
    String? message,
  }) async {
    final normalized = normalizeEgyptianNumber(phone);
    if (normalized == null) {
      throw Exception('رقم الهاتف المدخل غير صالح');
    }

    var urlString = 'https://wa.me/$normalized';
    if (message != null && message.trim().isNotEmpty) {
      final encodedMessage = Uri.encodeComponent(message);
      urlString += '?text=$encodedMessage';
    }

    final uri = Uri.parse(urlString);

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to launch in web browser
        return await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      throw Exception('تعذر فتح تطبيق واتساب. يرجى التأكد من تثبيت التطبيق على جهازك.');
    }
  }
}
