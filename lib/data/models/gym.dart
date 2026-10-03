/// Gym entity reflecting the public.gyms Supabase table
class Gym {
  final String id;
  final String name;
  final String? phone;
  final String currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Gym({
    required this.id,
    required this.name,
    this.phone,
    this.currency = 'EGP',
    this.createdAt,
    this.updatedAt,
  });

  factory Gym.fromJson(Map<String, dynamic> json) {
    return Gym(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      phone: json['phone'] as String?,
      currency: (json['currency'] as String?) ?? 'EGP',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'currency': currency,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
