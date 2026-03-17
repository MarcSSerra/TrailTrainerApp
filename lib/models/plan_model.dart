class Ejercicio {
  final String nombre;
  final int series;
  final int repeticiones;
  final String tiempoEjecucion;
  final String tiempoDescanso;

  Ejercicio({
    required this.nombre,
    required this.series,
    required this.repeticiones,
    required this.tiempoEjecucion,
    required this.tiempoDescanso,
  });

  factory Ejercicio.fromJson(Map<String, dynamic> json) {
    return Ejercicio(
      nombre: json['nombre'] ?? '',
      series: json['series'] ?? 0,
      repeticiones: json['repeticiones'] ?? 0,
      tiempoEjecucion: json['tiempo_ejecucion'] ?? '',
      tiempoDescanso: json['tiempo_descanso'] ?? '',
    );
  }
}

class SesionEntrenamiento {
  final String dia;
  final String tipoSesion;
  final String calentamiento;
  final List<Ejercicio> bloquesPrincipales;
  final String vueltaCalma;

  SesionEntrenamiento({
    required this.dia,
    required this.tipoSesion,
    required this.calentamiento,
    required this.bloquesPrincipales,
    required this.vueltaCalma,
  });

  factory SesionEntrenamiento.fromJson(Map<String, dynamic> json) {
    return SesionEntrenamiento(
      dia: json['dia'] ?? '',
      tipoSesion: json['tipo_sesion'] ?? '',
      calentamiento: json['calentamiento'] ?? '',
      bloquesPrincipales: (json['bloques_principales'] as List? ?? [])
          .map((e) => Ejercicio.fromJson(e))
          .toList(),
      vueltaCalma: json['vuelta_a_la_calma'] ?? '',
    );
  }
}

class SemanaPlan {
  final int numeroSemana;
  final String objetivoSemana;
  final List<SesionEntrenamiento> sesiones;
  final String? notas;

  SemanaPlan({
    required this.numeroSemana,
    required this.objetivoSemana,
    required this.sesiones,
    this.notas,
  });

  factory SemanaPlan.fromJson(Map<String, dynamic> json) {
    return SemanaPlan(
      numeroSemana: json['numero_semana'] ?? 0,
      objetivoSemana: json['objetivo_semana'] ?? '',
      sesiones: (json['sesiones'] as List? ?? [])
          .map((s) => SesionEntrenamiento.fromJson(s))
          .toList(),
      notas: json['notas'],
    );
  }
}

class PlanMensual {
  final String objetivoGeneral;
  final int duracionSemanas;
  final List<SemanaPlan> semanas;
  final String? recomendacionesGenerales;

  PlanMensual({
    required this.objetivoGeneral,
    required this.duracionSemanas,
    required this.semanas,
    this.recomendacionesGenerales,
  });

  factory PlanMensual.fromJson(Map<String, dynamic> json) {
    return PlanMensual(
      objetivoGeneral: json['objetivo_general'] ?? '',
      duracionSemanas: json['duracion_semanas'] ?? 0,
      semanas: (json['semanas'] as List? ?? [])
          .map((s) => SemanaPlan.fromJson(s))
          .toList(),
      recomendacionesGenerales: json['recomendaciones_generales'],
    );
  }
}

class PlanResponse {
  final bool success;
  final PlanMensual? plan;
  final List<String>? preguntasPendientes;
  final String? message;

  PlanResponse({
    required this.success,
    this.plan,
    this.preguntasPendientes,
    this.message,
  });

  factory PlanResponse.fromJson(Map<String, dynamic> json) {
    return PlanResponse(
      success: json['success'] ?? false,
      plan: json['plan'] != null ? PlanMensual.fromJson(json['plan']) : null,
      preguntasPendientes: (json['preguntas_pendientes'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      message: json['message'],
    );
  }
}
