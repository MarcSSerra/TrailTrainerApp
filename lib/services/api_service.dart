import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/plan_model.dart';
import '../models/actividad_model.dart';
import '../models/perfil_model.dart';

class ApiService {
  // Producción: Render
  static const String baseUrl = 'https://trailtraineragent.onrender.com';
  
  // Desarrollo local (descomentar para debug):
  // static const String baseUrl = 'http://localhost:8000';

  // --- Strava Auth ---
  Future<Map<String, dynamic>> getStravaAuthUrl() async {
    return {'url': '$baseUrl/strava/auth'};
  }

  // --- Actividades ---
  Future<List<Actividad>> getActividades({int dias = 7, String? userId}) async {
    final uri = userId != null 
        ? '$baseUrl/actividades?dias=$dias&user_id=$userId'
        : '$baseUrl/actividades?dias=$dias';
    final response = await http.get(Uri.parse(uri));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List acts = data['actividades'] ?? [];
      return acts.map((a) => Actividad.fromJson(a)).toList();
    }
    throw Exception('Error obteniendo actividades: ${response.body}');
  }

  // --- Plan ---
  Future<PlanResponse> generarPlan({
    required String userId,
    String? estadoLesiones,
    String? objetivosCarrera,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/plan'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'estado_lesiones': estadoLesiones,
        'objetivos_carrera': objetivosCarrera,
      }),
    );
    if (response.statusCode == 200) {
      return PlanResponse.fromJson(json.decode(response.body));
    }
    throw Exception('Error generando plan: ${response.body}');
  }

  // --- Perfil ---
  Future<Perfil> getPerfil(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/perfil/$userId'));
    if (response.statusCode == 200) {
      return Perfil.fromJson(json.decode(response.body));
    }
    throw Exception('Error obteniendo perfil');
  }

  Future<Perfil> updatePerfil(String userId, Map<String, dynamic> datos) async {
    final response = await http.put(
      Uri.parse('$baseUrl/perfil/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(datos),
    );
    if (response.statusCode == 200) {
      return Perfil.fromJson(json.decode(response.body));
    }
    throw Exception('Error actualizando perfil');
  }

  // --- Lesiones ---
  Future<List<Lesion>> getLesiones(String userId, {bool soloActivas = true}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/perfil/$userId/lesiones?solo_activas=$soloActivas'),
    );
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((l) => Lesion.fromJson(l)).toList();
    }
    throw Exception('Error obteniendo lesiones');
  }

  Future<Lesion> crearLesion(String userId, Map<String, dynamic> datos) async {
    final response = await http.post(
      Uri.parse('$baseUrl/perfil/$userId/lesiones'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(datos),
    );
    if (response.statusCode == 200) {
      return Lesion.fromJson(json.decode(response.body));
    }
    throw Exception('Error creando lesión');
  }

  Future<void> curarLesion(int lesionId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/perfil/lesiones/$lesionId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'activa': false}),
    );
    if (response.statusCode != 200) {
      throw Exception('Error actualizando lesión');
    }
  }

  // --- Objetivos ---
  Future<List<Objetivo>> getObjetivos(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/objetivos/$userId'));
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((o) => Objetivo.fromJson(o)).toList();
    }
    throw Exception('Error obteniendo objetivos');
  }

  Future<Objetivo> crearObjetivo(String userId, Map<String, dynamic> datos) async {
    final response = await http.post(
      Uri.parse('$baseUrl/objetivos/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(datos),
    );
    if (response.statusCode == 200) {
      return Objetivo.fromJson(json.decode(response.body));
    }
    throw Exception('Error creando objetivo');
  }

  Future<void> eliminarObjetivo(int objetivoId) async {
    final response = await http.delete(Uri.parse('$baseUrl/objetivos/$objetivoId'));
    if (response.statusCode != 200) {
      throw Exception('Error eliminando objetivo');
    }
  }

  // --- Plan guardado ---
  Future<Map<String, dynamic>?> getPlanActivo(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/planes/$userId/activo'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 404) {
      return null; // No hay plan activo
    }
    throw Exception('Error obteniendo plan');
  }

  Future<Map<String, dynamic>> getSesiones(String userId, {DateTime? desde, DateTime? hasta}) async {
    var uri = '$baseUrl/planes/$userId/sesiones';
    final params = <String>[];
    if (desde != null) params.add('desde=${desde.toIso8601String().split('T')[0]}');
    if (hasta != null) params.add('hasta=${hasta.toIso8601String().split('T')[0]}');
    if (params.isNotEmpty) uri += '?${params.join('&')}';
    
    final response = await http.get(Uri.parse(uri));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Error obteniendo sesiones');
  }

  Future<Map<String, dynamic>> getCalendario(String userId, {int? mes, int? anio}) async {
    var uri = '$baseUrl/planes/$userId/calendario';
    final params = <String>[];
    if (mes != null) params.add('mes=$mes');
    if (anio != null) params.add('anio=$anio');
    if (params.isNotEmpty) uri += '?${params.join('&')}';
    
    final response = await http.get(Uri.parse(uri));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Error obteniendo calendario');
  }

  Future<void> actualizarSesion(int sesionId, {String? estado, String? notas}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/planes/sesiones/$sesionId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        if (estado != null) 'estado': estado,
        if (notas != null) 'notas_atleta': notas,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Error actualizando sesión');
    }
  }

  Future<Map<String, dynamic>> reportarRPE(int sesionId, int rpe, {String? notas}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/planes/sesiones/$sesionId/rpe'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'rpe': rpe,
        if (notas != null) 'notas': notas,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Error reportando RPE');
  }

  Future<void> marcarVacaciones(String userId, DateTime inicio, DateTime fin) async {
    final response = await http.post(
      Uri.parse('$baseUrl/planes/$userId/vacaciones'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'fecha_inicio': inicio.toIso8601String().split('T')[0],
        'fecha_fin': fin.toIso8601String().split('T')[0],
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Error marcando vacaciones');
    }
  }

  Future<void> eliminarPlanActivo(String userId) async {
    await http.delete(Uri.parse('$baseUrl/planes/$userId/activo'));
  }

  // --- Vacaciones ---
  Future<List<Map<String, dynamic>>> getVacaciones(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/planes/$userId/vacaciones'));
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Error obteniendo vacaciones');
  }

  Future<Map<String, dynamic>> crearVacaciones(String userId, DateTime inicio, DateTime fin, {String? motivo}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/planes/$userId/vacaciones'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'fecha_inicio': inicio.toIso8601String().split('T')[0],
        'fecha_fin': fin.toIso8601String().split('T')[0],
        'motivo': motivo ?? 'Vacaciones',
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Error creando vacaciones');
  }

  Future<void> eliminarVacaciones(int vacacionesId, {bool restaurarSesiones = true}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/planes/vacaciones/$vacacionesId?restaurar_sesiones=$restaurarSesiones'),
    );
    if (response.statusCode != 200) {
      throw Exception('Error eliminando vacaciones');
    }
  }

  // --- Sincronización con Strava ---
  Future<Map<String, dynamic>> sincronizarConStrava(String userId) async {
    final response = await http.post(Uri.parse('$baseUrl/planes/$userId/sincronizar'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Necesitas reconectar con Strava');
    }
    throw Exception('Error sincronizando: ${response.body}');
  }

  Future<Map<String, dynamic>> getDetalleSesion(int sesionId) async {
    final response = await http.get(Uri.parse('$baseUrl/planes/sesiones/$sesionId/detalle'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Error obteniendo detalle de sesión');
  }

  /// Corrige manualmente los datos de una sesión (cuando Strava no es preciso)
  Future<Map<String, dynamic>> actualizarOverrideSesion(
    int sesionId, {
    double? distanciaKm,
    int? desnivelM,
    double? tiempoMin,
    int? fcMedia,
    String? notas,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/planes/sesiones/$sesionId/override'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        if (distanciaKm != null) 'distancia_km': distanciaKm,
        if (desnivelM != null) 'desnivel_m': desnivelM,
        if (tiempoMin != null) 'tiempo_min': tiempoMin,
        if (fcMedia != null) 'fc_media': fcMedia,
        if (notas != null) 'notas': notas,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Error actualizando datos de sesión');
  }

  /// Elimina las correcciones manuales y vuelve a usar datos de Strava
  Future<void> eliminarOverrideSesion(int sesionId) async {
    final response = await http.delete(Uri.parse('$baseUrl/planes/sesiones/$sesionId/override'));
    if (response.statusCode != 200) {
      throw Exception('Error eliminando correcciones');
    }
  }

  Future<Map<String, dynamic>> getResumenSemana(String userId, int semanaNumero) async {
    final response = await http.get(Uri.parse('$baseUrl/planes/$userId/resumen-semana/$semanaNumero'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Error obteniendo resumen de semana');
  }

  Future<Map<String, dynamic>> getResumenTodasSemanas(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/planes/$userId/resumen-semanas'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Error obteniendo resumen de semanas');
  }

  Future<Map<String, dynamic>> checkHealth() async {
    final response = await http.get(Uri.parse('$baseUrl/health'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Servidor no disponible');
  }

  // --- Nutrición ---
  Future<Map<String, dynamic>> getNutricion(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/nutricion/$userId'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Error obteniendo nutrición');
  }

  Future<Map<String, dynamic>?> getNutricionSemana(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/nutricion/$userId/semana'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 404) {
      return null;
    }
    throw Exception('Error obteniendo nutrición semanal');
  }

  Future<Map<String, dynamic>> regenerarNutricionSemana(String userId) async {
    final response = await http.post(Uri.parse('$baseUrl/nutricion/$userId/regenerar'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Error regenerando nutrición semanal');
  }
}