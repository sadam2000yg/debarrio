class UserProfile {
  final String id;
  final String email;
  final String nombre;
  final String ci;
  final String telefono;
  final String selfieUrl;
  final String facadeUrl;
  final String ciAnversoUrl;
  final String ciReversoUrl;
  final double lat;
  final double lng;
  final String activeRole; // 'VECINO' or 'EMPRENDEDOR'
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.nombre,
    required this.ci,
    required this.telefono,
    required this.selfieUrl,
    required this.facadeUrl,
    required this.ciAnversoUrl,
    required this.ciReversoUrl,
    required this.lat,
    required this.lng,
    required this.activeRole,
    this.createdAt,
  });

  UserProfile copyWith({
    String? id,
    String? email,
    String? nombre,
    String? ci,
    String? telefono,
    String? selfieUrl,
    String? facadeUrl,
    String? ciAnversoUrl,
    String? ciReversoUrl,
    double? lat,
    double? lng,
    String? activeRole,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      nombre: nombre ?? this.nombre,
      ci: ci ?? this.ci,
      telefono: telefono ?? this.telefono,
      selfieUrl: selfieUrl ?? this.selfieUrl,
      facadeUrl: facadeUrl ?? this.facadeUrl,
      ciAnversoUrl: ciAnversoUrl ?? this.ciAnversoUrl,
      ciReversoUrl: ciReversoUrl ?? this.ciReversoUrl,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      activeRole: activeRole ?? this.activeRole,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    double lat = 0.0;
    double lng = 0.0;
    if (map['lat'] != null) {
      lat = (map['lat'] as num).toDouble();
    }
    if (map['lng'] != null) {
      lng = (map['lng'] as num).toDouble();
    }

    return UserProfile(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      ci: map['ci']?.toString() ?? '',
      telefono: map['telefono']?.toString() ?? '',
      selfieUrl: map['selfie_url']?.toString() ?? '',
      facadeUrl: map['facade_url']?.toString() ?? '',
      ciAnversoUrl: map['ci_anverso_url']?.toString() ?? '',
      ciReversoUrl: map['ci_reverso_url']?.toString() ?? '',
      lat: lat,
      lng: lng,
      activeRole: map['active_role']?.toString() ?? 'VECINO',
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'nombre': nombre,
      'ci': ci,
      'telefono': telefono,
      'selfie_url': selfieUrl,
      'facade_url': facadeUrl,
      'ci_anverso_url': ciAnversoUrl,
      'ci_reverso_url': ciReversoUrl,
      'lat': lat,
      'lng': lng,
      'active_role': activeRole,
    };
  }
}
