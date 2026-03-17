class Actividad {
  final int id;
  final String nombre;
  final String tipo;
  final DateTime fecha;
  final double distanciaKm;
  final double desnivelM;
  final double tiempoMin;
  final double? fcMedia;
  final double? fcMax;
  final double? sufferScore;

  Actividad({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.fecha,
    required this.distanciaKm,
    required this.desnivelM,
    required this.tiempoMin,
    this.fcMedia,
    this.fcMax,
    this.sufferScore,
  });

  factory Actividad.fromJson(Map<String, dynamic> json) {
    return Actividad(
      id: json['id'],
      nombre: json['nombre'] ?? '',
      tipo: json['tipo'] ?? '',
      fecha: DateTime.parse(json['fecha']),
      distanciaKm: (json['distancia_km'] ?? 0).toDouble(),
      desnivelM: (json['desnivel_m'] ?? 0).toDouble(),
      tiempoMin: (json['tiempo_min'] ?? 0).toDouble(),
      fcMedia: json['fc_media']?.toDouble(),
      fcMax: json['fc_max']?.toDouble(),
      sufferScore: json['suffer_score']?.toDouble(),
    );
  }

  String get tiempoFormateado {
    final horas = (tiempoMin / 60).floor();
    final mins = (tiempoMin % 60).round();
    if (horas > 0) return '${horas}h ${mins}m';
    return '${mins}m';
  }
}
