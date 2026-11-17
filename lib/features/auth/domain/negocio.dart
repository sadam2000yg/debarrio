class Negocio {
  final String id;
  final String ownerId;
  final String nombre;
  final String descripcion;
  final double lat;
  final double lng;
  final String storePhotoUrl;
  final String qrPhotoUrl;
  final List<String> deliveryOptions;
  final int shippingCost; // in cents
  final bool abierto;
  final String categoria;
  final double? distanciaMetros;
  final double? calificacionPromedio;
  final DateTime? createdAt;

  Negocio({
    required this.id,
    required this.ownerId,
    required this.nombre,
    required this.descripcion,
    required this.lat,
    required this.lng,
    required this.storePhotoUrl,
    required this.qrPhotoUrl,
    required this.deliveryOptions,
    required this.shippingCost,
    this.abierto = true,
    this.categoria = 'General',
    this.distanciaMetros,
    this.calificacionPromedio,
    this.createdAt,
  });

  Negocio copyWith({
    String? id,
    String? ownerId,
    String? nombre,
    String? descripcion,
    double? lat,
    double? lng,
    String? storePhotoUrl,
    String? qrPhotoUrl,
    List<String>? deliveryOptions,
    int? shippingCost,
    bool? abierto,
    String? categoria,
    double? distanciaMetros,
    double? calificacionPromedio,
    DateTime? createdAt,
  }) {
    return Negocio(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      storePhotoUrl: storePhotoUrl ?? this.storePhotoUrl,
      qrPhotoUrl: qrPhotoUrl ?? this.qrPhotoUrl,
      deliveryOptions: deliveryOptions ?? this.deliveryOptions,
      shippingCost: shippingCost ?? this.shippingCost,
      abierto: abierto ?? this.abierto,
      categoria: categoria ?? this.categoria,
      distanciaMetros: distanciaMetros ?? this.distanciaMetros,
      calificacionPromedio: calificacionPromedio ?? this.calificacionPromedio,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Negocio.fromMap(Map<String, dynamic> map) {
    double lat = 0.0;
    double lng = 0.0;
    if (map['lat'] != null) {
      lat = (map['lat'] as num).toDouble();
    }
    if (map['lng'] != null) {
      lng = (map['lng'] as num).toDouble();
    }

    List<String> delivery = [];
    if (map['delivery_options'] is List) {
      delivery = (map['delivery_options'] as List).map((e) => e.toString()).toList();
    } else if (map['delivery_options'] is String) {
      delivery = [map['delivery_options'].toString()];
    }

    double? dist;
    if (map['distancia_metros'] != null) {
      dist = (map['distancia_metros'] as num).toDouble();
    } else if (map['distanciaMetros'] != null) {
      dist = (map['distanciaMetros'] as num).toDouble();
    }

    double? calif;
    if (map['calificacion_promedio'] != null) {
      calif = (map['calificacion_promedio'] as num).toDouble();
    }

    return Negocio(
      id: map['id']?.toString() ?? '',
      ownerId: map['owner_id']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      descripcion: map['descripcion']?.toString() ?? '',
      lat: lat,
      lng: lng,
      storePhotoUrl: map['store_photo_url']?.toString() ?? '',
      qrPhotoUrl: map['qr_photo_url']?.toString() ?? '',
      deliveryOptions: delivery,
      shippingCost: map['shipping_cost'] != null ? (map['shipping_cost'] as num).toInt() : 0,
      abierto: map['abierto'] ?? true,
      categoria: map['categoria']?.toString() ?? 'General',
      distanciaMetros: dist,
      calificacionPromedio: calif,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'owner_id': ownerId,
      'nombre': nombre,
      'descripcion': descripcion,
      'lat': lat,
      'lng': lng,
      'store_photo_url': storePhotoUrl,
      'qr_photo_url': qrPhotoUrl,
      'delivery_options': deliveryOptions,
      'shipping_cost': shippingCost,
      'abierto': abierto,
      'categoria': categoria,
    };
  }
}
