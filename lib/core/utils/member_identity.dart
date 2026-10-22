import '../../data/models/member.dart';
import '../services/whatsapp_service.dart';

enum DuplicateMemberField { name, phone, unknown }

String normalizeMemberName(String name) {
  return name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

String? normalizeMemberPhone(String? phone) {
  if (phone == null || phone.trim().isEmpty) return null;
  final asciiDigits = String.fromCharCodes(phone.runes.map((rune) {
    if (rune >= 0x0660 && rune <= 0x0669) return rune - 0x0660 + 0x30;
    if (rune >= 0x06F0 && rune <= 0x06F9) return rune - 0x06F0 + 0x30;
    return rune;
  }));
  final formatted = asciiDigits.replaceAll(RegExp(r'[^0-9+]'), '');
  return WhatsappService.normalizeEgyptianNumber(formatted);
}

DuplicateMemberField? duplicateMemberField(
  Member candidate,
  Iterable<Member> existing, {
  String? excludingMemberId,
}) {
  final normalizedName = normalizeMemberName(candidate.fullName);
  final normalizedPhone = normalizeMemberPhone(candidate.phone);

  for (final member in existing) {
    if (member.id == excludingMemberId ||
        member.gymId != candidate.gymId ||
        member.deletedAt != null) {
      continue;
    }
    if (normalizeMemberName(member.fullName) == normalizedName) {
      return DuplicateMemberField.name;
    }
    if (normalizedPhone != null &&
        normalizeMemberPhone(member.phone) == normalizedPhone) {
      return DuplicateMemberField.phone;
    }
  }
  return null;
}
