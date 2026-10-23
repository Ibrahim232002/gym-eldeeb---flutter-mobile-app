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

  /// Format a friendly Arabic welcome/general contact message.
  static String getGeneralContact(
    String memberName, {
    String? startDateStr,
    String? endDateStr,
    String? planName,
  }) {
    final membershipDetails = (startDateStr != null && endDateStr != null)
        ? '\n📋 باقة الاشتراك: ${planName ?? 'الاشتراك الحالي'}'
            '\n📅 بداية الاشتراك: $startDateStr'
            '\n📅 نهاية الاشتراك: $endDateStr'
        : '';
    return 'السلام عليكم يا كابتن $memberName 👋🦁\n\n'
        'أهلاً بيك في جيم الديب! نتمنى لك القوة والنشاط وتحقيق أهدافك الرياضية. 💪'
        '$membershipDetails\n\n'
        'يسعدنا وجودك معانا، ومستنيينك دايمًا في التمرين! 🏋️‍♂️';
  }

  /// Format an outstanding-payment reminder in Arabic.
  static String getPaymentReminder(
    String memberName,
    double amount, {
    String? startDateStr,
    String? endDateStr,
  }) {
    final dates = (startDateStr != null && endDateStr != null)
        ? '\n📅 فترة الاشتراك: من $startDateStr إلى $endDateStr'
        : '';
    return 'السلام عليكم يا كابتن $memberName 👋\n\n'
        'بنحب نفكّرك إن فيه مبلغ مستحق لاشتراكك في جيم الديب بقيمة '
        '${amount.toStringAsFixed(2)} ج.م.$dates\n\n'
        'لو تم السداد بالفعل، نرجو تجاهل الرسالة دي. شكرًا لثقتك في جيم الديب! 💪🦁';
  }

  /// Reminder for a membership that will expire soon.
  static String getExpiryReminder(
    String memberName,
    String planName,
    String endDateStr, {
    String? startDateStr,
  }) {
    final startDate = startDateStr == null
        ? ''
        : '\n📅 بداية الاشتراك: $startDateStr';
    return 'السلام عليكم يا كابتن $memberName 👋🏋️‍♂️\n\n'
        'بنحب نفكّرك إن اشتراكك في جيم الديب ($planName) هينتهي قريبًا '
        'يوم $endDateStr.$startDate\n'
        '📅 تاريخ الانتهاء: $endDateStr\n\n'
        'جدّد اشتراكك في الوقت المناسب عشان تكمّل تمرينك من غير انقطاع. '
        'مستنيينك دايمًا! 💪🦁';
  }

  /// Reminder for an expired membership with an outstanding balance.
  static String getExpiredReminder(
    String memberName,
    double amount, {
    String? startDateStr,
    String? endDateStr,
  }) {
    final dates = (startDateStr != null && endDateStr != null)
        ? '\n📅 فترة الاشتراك: من $startDateStr إلى $endDateStr'
        : '';
    final balance = amount > 0
        ? '\n💳 المبلغ المستحق: ${amount.toStringAsFixed(2)} ج.م'
        : '';
    return 'السلام عليكم يا كابتن $memberName 👋\n\n'
        'بنحب نفكّرك إن اشتراكك في جيم الديب انتهى بتاريخ '
        '${endDateStr ?? 'غير محدد'}.$dates$balance\n\n'
        'يسعدنا تجديد اشتراكك وعودتك للتمرين معانا. ولو تم السداد أو التجديد بالفعل، '
        'نرجو تجاهل الرسالة دي. 💪🦁';
  }

  /// Confirmation message to send after recording a payment.
  static String getPaymentConfirmation(
    String memberName,
    double amount, {
    String? startDateStr,
    String? endDateStr,
  }) {
    final dates = (startDateStr != null && endDateStr != null)
        ? '\n📅 فترة الاشتراك: من $startDateStr إلى $endDateStr'
        : '';
    return 'السلام عليكم يا كابتن $memberName 👋\n\n'
        'تم استلام دفعتك بنجاح بقيمة ${amount.toStringAsFixed(2)} ج.م، '
        'شكرًا لالتزامك وثقتك في جيم الديب!$dates\n\n'
        'نتمنالك تمرينًا موفقًا ونتائج ممتازة. مستنيينك دايمًا! 💪🦁';
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
      throw Exception(
          'تعذر فتح تطبيق واتساب. يرجى التأكد من تثبيت التطبيق على جهازك.');
    }
  }
}
