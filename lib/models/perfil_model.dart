class Perfil {
  final String stravaId;
  final String? nombre;
  final DateTime? fechaNacimiento;
  final int? edad;
  final double? pesoKg;
  final int? alturaCm;
  final String? genero;
  final int? fcMaxima;
  final int? fcReposo;
  final double? imc;

  Perfil({
    required this.stravaId,
    this.nombre,
    this.fechaNacimiento,
    this.edad,
    this.pesoKg,
    this.alturaCm,
    this.genero,
    this.fcMaxima,
    this.fcReposo,
    this.imc,
  });

  factory Perfil.fromJson(Map<String, dynamic> json) {
    return Perfil(
      stravaId: json['strava_id'] ?? '',
      nombre: json['nombre'],
      fechaNacimiento: json['fecha_nacimiento'] != null 
          ? DateTime.parse(json['fecha_nacimiento']) 
          : null,
      edad: json['edad'],
      pesoKg: json['peso_kg']?.toDouble(),
      alturaCm: json['altura_cm'],
      genero: json['genero'],
      fcMaxima: json['fc_maxima'],
      fcReposo: json['fc_reposo'],
      imc: json['imc']?.toDouble(),
    );
  }
}

class Lesion {
  final int id;
  final String zona;
  final String? descripcion;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final int severidad;
  final String severidadTexto;
  final bool enTratamiento;
  final String? notasMedicas;
  final bool activa;
  final int diasLesionado;

  Lesion({
    required this.id,
    required this.zona,
    this.descripcion,
    required this.fechaInicio,
    this.fechaFin,
    required this.severidad,
    required this.severidadTexto,
    required this.enTratamiento,
    this.notasMedicas,
    required this.activa,
    required this.diasLesionado,
  });

  factory Lesion.fromJson(Map<String, dynamic> json) {
    return Lesion(
      id: json['id'],
      zona: json['zona'] ?? '',
      descripcion: json['descripcion'],
      fechaInicio: DateTime.parse(json['fecha_inicio']),
      fechaFin: json['fecha_fin'] != null ? DateTime.parse(json['fecha_fin']) : null,
      severidad: json['severidad'] ?? 2,
      severidadTexto: json['severidad_texto'] ?? 'Moderada',
      enTratamiento: json['en_tratamiento'] ?? false,
      notasMedicas: json['notas_medicas'],
      activa: json['activa'] ?? true,
      diasLesionado: json['dias_lesionado'] ?? 0,
    );
  }
}

class Objetivo {
  final int id;
  final String nombre;
  final DateTime fecha;
  final String? tipo;
  final double? distanciaKm;
  final int? desnivelM;
  final String? tiempoObjetivo;
  final String? tiempoEstimado;  // Nuevo: estimación basada en historial
  final int prioridad;
  final String? notas;
  final bool completado;
  final int diasRestantes;
  final int semanasRestantes;

  Objetivo({
    required this.id,
    required this.nombre,
    required this.fecha,
    this.tipo,
    this.distanciaKm,
    this.desnivelM,
    this.tiempoObjetivo,
    this.tiempoEstimado,
    required this.prioridad,
    this.notas,
    required this.completado,
    required this.diasRestantes,
    required this.semanasRestantes,
  });

  factory Objetivo.fromJson(Map<String, dynamic> json) {
    return Objetivo(
      id: json['id'],
      nombre: json['nombre'] ?? '',
      fecha: DateTime.parse(json['fecha']),
      tipo: json['tipo'],
      distanciaKm: json['distancia_km']?.toDouble(),
      desnivelM: json['desnivel_m'],
      tiempoObjetivo: json['tiempo_objetivo'],
      tiempoEstimado: json['tiempo_estimado'],
      prioridad: json['prioridad'] ?? 1,
      notas: json['notas'],
      completado: json['completado'] ?? false,
      diasRestantes: json['dias_restantes'] ?? 0,
      semanasRestantes: json['semanas_restantes'] ?? 0,
    );
  }
}
