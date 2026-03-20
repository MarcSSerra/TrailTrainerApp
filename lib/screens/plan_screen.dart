import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/plan_model.dart';
import '../models/perfil_model.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  Map<String, dynamic>? _planActivo;
  List<dynamic> _sesiones = [];
  List<Map<String, dynamic>> _vacaciones = [];
  List<Map<String, dynamic>> _resumenSemanas = [];
  bool _loading = true;
  bool _generando = false;
  bool _sincronizando = false;
  String? _error;
  int _semanaSeleccionada = 1;
  
  // Para vista calendario
  DateTime _mesActual = DateTime.now();
  List<dynamic> _eventosCalendario = [];

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    final auth = context.read<AuthService>();
    if (auth.userId == null) return;

    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final plan = await api.getPlanActivo(auth.userId!);
      
      // Cargar vacaciones siempre
      final vacaciones = await api.getVacaciones(auth.userId!);
      
      if (plan != null) {
        final sesionesData = await api.getSesiones(auth.userId!);
        final calendario = await api.getCalendario(
          auth.userId!,
          mes: _mesActual.month,
          anio: _mesActual.year,
        );
        
        // Cargar resumen de semanas
        List<Map<String, dynamic>> resumenSemanas = [];
        try {
          final resumen = await api.getResumenTodasSemanas(auth.userId!);
          resumenSemanas = List<Map<String, dynamic>>.from(resumen['semanas'] ?? []);
        } catch (e) {
          // Ignorar si falla
        }
        
        // Determinar semana actual
        final sesiones = sesionesData['sesiones'] ?? [];
        int semanaActual = 1;
        if (sesiones.isNotEmpty) {
          final hoy = DateTime.now();
          for (var s in sesiones) {
            final fecha = DateTime.parse(s['fecha']);
            if (fecha.isAfter(hoy.subtract(const Duration(days: 1)))) {
              semanaActual = s['semana_numero'] ?? 1;
              break;
            }
          }
        }
        
        setState(() {
          _planActivo = plan;
          _sesiones = sesiones;
          _eventosCalendario = calendario['eventos'] ?? [];
          _vacaciones = vacaciones;
          _resumenSemanas = resumenSemanas;
          _semanaSeleccionada = semanaActual;
        });
      } else {
        setState(() {
          _planActivo = null;
          _vacaciones = vacaciones;
        });
      }
    } catch (e) {
      setState(() => _planActivo = null);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _generarPlan() async {
    final auth = context.read<AuthService>();
    if (auth.userId == null) return;

    setState(() {
      _generando = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final response = await api.generarPlan(userId: auth.userId!);

      if (response.success) {
        await _loadPlan();
      } else {
        setState(() => _error = response.message ?? 'Error generando plan');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _generando = false);
    }
  }

  Future<void> _marcarSesion(int sesionId, String estado) async {
    try {
      final api = context.read<ApiService>();
      await api.actualizarSesion(sesionId, estado: estado);
      await _loadPlan();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _mostrarDialogoVacaciones() {
    DateTime inicio = DateTime.now().add(const Duration(days: 1));
    DateTime fin = DateTime.now().add(const Duration(days: 8));
    String motivo = 'Vacaciones';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Añadir vacaciones'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Motivo'),
                onChanged: (v) => motivo = v,
                controller: TextEditingController(text: motivo),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text('Desde: ${DateFormat('dd/MM/yyyy').format(inicio)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: inicio,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setDialogState(() {
                      inicio = date;
                      if (fin.isBefore(inicio)) {
                        fin = inicio.add(const Duration(days: 1));
                      }
                    });
                  }
                },
              ),
              ListTile(
                title: Text('Hasta: ${DateFormat('dd/MM/yyyy').format(fin)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: fin.isBefore(inicio) ? inicio : fin,
                    firstDate: inicio,
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) setDialogState(() => fin = date);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                final auth = context.read<AuthService>();
                final api = context.read<ApiService>();
                await api.crearVacaciones(auth.userId!, inicio, fin, motivo: motivo);
                Navigator.pop(ctx);
                _loadPlan();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vacaciones añadidas'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarVacaciones() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🏖️ Vacaciones programadas'),
        content: SizedBox(
          width: double.maxFinite,
          child: _vacaciones.isEmpty
              ? const Text('No hay vacaciones programadas')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _vacaciones.length,
                  itemBuilder: (ctx, i) {
                    final vac = _vacaciones[i];
                    return ListTile(
                      leading: const Icon(Icons.beach_access, color: Colors.orange),
                      title: Text(vac['motivo'] ?? 'Vacaciones'),
                      subtitle: Text(
                        '${vac['fecha_inicio']} - ${vac['fecha_fin']} (${vac['dias']} días)',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final api = context.read<ApiService>();
                          await api.eliminarVacaciones(vac['id']);
                          Navigator.pop(ctx);
                          _loadPlan();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vacaciones eliminadas')),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _mostrarDialogoVacaciones();
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  Future<void> _sincronizarConStrava() async {
    final auth = context.read<AuthService>();
    if (auth.userId == null) return;

    setState(() => _sincronizando = true);
    try {
      final api = context.read<ApiService>();
      final resultado = await api.sincronizarConStrava(auth.userId!);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${resultado['mensaje']}'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadPlan();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _sincronizando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_planActivo == null) {
      return _buildNoPlan();
    }

    return _buildPlanView();
  }

  Widget _buildNoPlan() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.calendar_month, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No tienes un plan activo',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Genera un plan personalizado basado en tu perfil, historial y objetivos.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Mostrar vacaciones programadas
          if (_vacaciones.isNotEmpty) ...[
            Card(
              color: Colors.orange.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.beach_access, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Vacaciones programadas', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._vacaciones.map((v) => Text(
                      '• ${v['fecha_inicio']} - ${v['fecha_fin']}: ${v['motivo'] ?? 'Vacaciones'}',
                      style: const TextStyle(fontSize: 13),
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Botón gestionar vacaciones
          OutlinedButton.icon(
            onPressed: _mostrarVacaciones,
            icon: const Icon(Icons.beach_access),
            label: Text(_vacaciones.isEmpty ? 'Añadir vacaciones' : 'Gestionar vacaciones'),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          FilledButton.icon(
            onPressed: _generando ? null : _generarPlan,
            icon: _generando
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(_generando ? 'Generando...' : 'Generar Plan con IA'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanView() {
    final plan = _planActivo!;
    final progreso = plan['progreso_pct'] ?? 0.0;
    
    // Filtrar sesiones de la semana seleccionada
    final sesionesSemana = _sesiones.where((s) => s['semana_numero'] == _semanaSeleccionada).toList();
    
    // Obtener resumen de la semana seleccionada
    final resumenSemana = _resumenSemanas.isNotEmpty 
        ? _resumenSemanas.firstWhere(
            (r) => r['semana'] == _semanaSeleccionada,
            orElse: () => {},
          )
        : null;

    return RefreshIndicator(
      onRefresh: _loadPlan,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Header del plan
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(plan['nombre'] ?? 'Mi Plan', 
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      // Botón sincronizar Strava
                      IconButton(
                        icon: _sincronizando 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.sync, color: Colors.deepOrange),
                        onPressed: _sincronizando ? null : _sincronizarConStrava,
                        tooltip: 'Sincronizar con Strava',
                      ),
                      PopupMenuButton(
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'vacaciones', child: Text('🏖️ Gestionar vacaciones')),
                          const PopupMenuItem(value: 'regenerar', child: Text('🔄 Regenerar plan')),
                        ],
                        onSelected: (value) async {
                          if (value == 'vacaciones') {
                            _mostrarVacaciones();
                          } else if (value == 'regenerar') {
                            final auth = context.read<AuthService>();
                            final api = context.read<ApiService>();
                            await api.eliminarPlanActivo(auth.userId!);
                            await _loadPlan(); // Recargar para mostrar vacaciones
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progreso / 100),
                  const SizedBox(height: 4),
                  Text('${plan['sesiones_completadas']}/${plan['sesiones_total']} sesiones · ${progreso.toStringAsFixed(0)}%'),
                ],
              ),
            ),
            
            // Selector de semana
            if (_resumenSemanas.isNotEmpty) ...[
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  itemCount: _resumenSemanas.length,
                  itemBuilder: (ctx, i) {
                    final semana = _resumenSemanas[i];
                    final isSelected = semana['semana'] == _semanaSeleccionada;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text('S${semana['semana']}'),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _semanaSeleccionada = semana['semana']),
                      ),
                    );
                  },
                ),
              ),
              
              // Resumen de la semana
              if (resumenSemana != null && resumenSemana.isNotEmpty)
                _buildResumenSemana(resumenSemana),
            ],
            
            // Lista de sesiones de la semana
            if (sesionesSemana.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text('No hay sesiones esta semana'),
              )
            else
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: sesionesSemana.map((s) => _buildSesionCard(s)).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenSemana(Map<String, dynamic> resumen) {
    final planificado = resumen['planificado'] as Map<String, dynamic>?;
    final completado = resumen['completado'] as Map<String, dynamic>?;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (resumen['objetivo'] != null && resumen['objetivo'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '🎯 ${resumen['objetivo']}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          // Planificado
          Row(
            children: [
              const Text('📋 Plan: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              Text(
                '${planificado?['horas'] ?? 0}h · ${planificado?['km'] ?? 0}km · Carga ${planificado?['carga'] ?? 0}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Completado
          Row(
            children: [
              const Text('✅ Real: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.green)),
              Text(
                '${completado?['horas'] ?? 0}h · ${completado?['km'] ?? 0}km · ${completado?['sesiones'] ?? 0}/${planificado?['sesiones'] ?? 0} sesiones',
                style: TextStyle(fontSize: 12, color: Colors.green[700]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Barra de progreso
          LinearProgressIndicator(
            value: (resumen['progreso_pct'] ?? 0) / 100,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
          ),
          const SizedBox(height: 4),
          Text(
            '${resumen['progreso_pct'] ?? 0}% completado',
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSesionCard(Map<String, dynamic> sesion) {
    final fecha = DateTime.parse(sesion['fecha']);
    final esHoy = fecha.day == DateTime.now().day && 
                  fecha.month == DateTime.now().month &&
                  fecha.year == DateTime.now().year;
    final esPasada = fecha.isBefore(DateTime.now()) && !esHoy;
    final estado = sesion['estado'] ?? 'pendiente';
    final strava = sesion['strava'] as Map<String, dynamic>?;
    final justificacion = sesion['justificacion'] as String?;
    final duracionMin = sesion['duracion_min'] as int?;
    final distanciaKm = sesion['distancia_km'];
    final cargaEstimada = sesion['carga_estimada'] as int?;
    
    Color estadoColor;
    IconData estadoIcon;
    switch (estado) {
      case 'completada':
        estadoColor = Colors.green;
        estadoIcon = strava != null ? Icons.directions_run : Icons.check_circle;
        break;
      case 'saltada':
        estadoColor = Colors.orange;
        estadoIcon = Icons.cancel;
        break;
      default:
        estadoColor = esHoy ? Colors.blue : (esPasada ? Colors.red : Colors.grey);
        estadoIcon = esHoy ? Icons.today : Icons.circle_outlined;
    }

    return Card(
      color: esHoy ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ExpansionTile(
        leading: Icon(estadoIcon, color: estadoColor),
        title: Row(
          children: [
            Expanded(child: Text(sesion['tipo_sesion'] ?? 'Entrenamiento')),
            if (strava != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Strava', style: TextStyle(fontSize: 10, color: Colors.deepOrange)),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(
              '${sesion['dia_semana']} ${DateFormat('dd/MM').format(fecha)}'
              '${esHoy ? " · HOY" : ""}',
            ),
            const Spacer(),
            // Métricas rápidas
            if (duracionMin != null && duracionMin > 0)
              Text(' ${duracionMin}min', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            if (distanciaKm != null && distanciaKm > 0)
              Text(' · ${distanciaKm}km', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            if (cargaEstimada != null && cargaEstimada > 0)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: _getCargaColor(cargaEstimada).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('$cargaEstimada', style: TextStyle(fontSize: 10, color: _getCargaColor(cargaEstimada))),
              ),
          ],
        ),
        trailing: estado == 'pendiente'
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => _marcarSesion(sesion['id'], 'completada'),
                    tooltip: 'Completada',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.orange),
                    onPressed: () => _marcarSesion(sesion['id'], 'saltada'),
                    tooltip: 'Saltar',
                  ),
                ],
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Justificación del entrenamiento
                if (justificacion != null && justificacion.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lightbulb_outline, color: Colors.blue, size: 18),
                            SizedBox(width: 8),
                            Text('¿Por qué este entrenamiento?', 
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(justificacion, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Datos reales (Strava o manual) si existen
                if (strava != null || sesion['real'] != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.deepOrange.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.directions_run, color: Colors.deepOrange, size: 18),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text('Datos reales', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                            ),
                            // Botón editar
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              color: Colors.deepOrange,
                              tooltip: 'Corregir datos',
                              onPressed: () => _mostrarDialogoEditarDatos(sesion),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Mostrar valores reales (override si existe, sino strava)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStravaMetric('📏', '${(sesion['real']?['distancia_km'] ?? strava?['distancia_km'])?.toStringAsFixed(2) ?? '-'} km'),
                            _buildStravaMetric('⛰️', '${sesion['real']?['desnivel_m'] ?? strava?['desnivel_m'] ?? '-'} m'),
                            _buildStravaMetric('⏱️', _formatTiempo(sesion['real']?['tiempo_min'] ?? strava?['tiempo_min'])),
                            if ((sesion['real']?['fc_media'] ?? strava?['fc_media']) != null)
                              _buildStravaMetric('❤️', '${sesion['real']?['fc_media'] ?? strava?['fc_media']} bpm'),
                          ],
                        ),
                        // Indicador de datos corregidos
                        if (sesion['real']?['tiene_override'] == true) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit_note, size: 14, color: Colors.blue),
                                const SizedBox(width: 4),
                                Text(
                                  'Datos corregidos${sesion['real']?['override_notas'] != null ? ': ${sesion['real']['override_notas']}' : ''}',
                                  style: const TextStyle(fontSize: 11, color: Colors.blue),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (estado == 'completada') ...[
                  // Sesión completada sin datos - permitir añadir manualmente
                  OutlinedButton.icon(
                    onPressed: () => _mostrarDialogoEditarDatos(sesion),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Añadir datos reales'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepOrange,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // RPE - mostrar si existe o permitir reportar
                if (estado == 'completada') ...[
                  _buildRPESection(sesion),
                  const SizedBox(height: 12),
                ],
                if (sesion['calentamiento'] != null) ...[
                  const Text('Calentamiento:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(sesion['calentamiento']),
                  const SizedBox(height: 8),
                ],
                if ((sesion['bloques'] as List?)?.isNotEmpty ?? false) ...[
                  const Text('Ejercicios:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...((sesion['bloques'] as List).map((b) {
                    final nombre = b['nombre'] ?? b.toString();
                    final series = b['series'] ?? '';
                    final reps = b['repeticiones'] ?? '';
                    final tiempo = b['tiempo_ejecucion'] ?? '';
                    final descanso = b['tiempo_descanso'];
                    
                    String detalle = '• $nombre';
                    if (series != '' || reps != '') {
                      detalle += ': ${series}x$reps';
                    }
                    if (tiempo != '') {
                      detalle += ' $tiempo';
                    }
                    if (descanso != null && descanso != '' && descanso != '0') {
                      detalle += ' (desc: $descanso)';
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(detalle),
                    );
                  })),
                  const SizedBox(height: 8),
                ],
                if (sesion['vuelta_calma'] != null) ...[
                  const Text('Vuelta a la calma:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(sesion['vuelta_calma']),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getCargaColor(int carga) {
    if (carga <= 3) return Colors.green;
    if (carga <= 5) return Colors.orange;
    if (carga <= 7) return Colors.deepOrange;
    return Colors.red;
  }

  Widget _buildRPESection(Map<String, dynamic> sesion) {
    final rpe = sesion['rpe_usuario'] as int?;
    final cargaReal = sesion['carga_real'] as int?;
    
    if (rpe != null) {
      // Mostrar RPE ya reportado
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purple.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.psychology, color: Colors.purple, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Esfuerzo percibido (RPE): $rpe/10', 
                      style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.purple)),
                  if (cargaReal != null)
                    Text('Carga real: $cargaReal', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 18, color: Colors.purple),
              onPressed: () => _mostrarDialogoRPE(sesion, rpeActual: rpe),
              tooltip: 'Editar RPE',
            ),
          ],
        ),
      );
    }
    
    // Permitir reportar RPE
    return OutlinedButton.icon(
      onPressed: () => _mostrarDialogoRPE(sesion),
      icon: const Icon(Icons.psychology, size: 16),
      label: const Text('¿Cómo te sentiste? Reportar RPE'),
      style: OutlinedButton.styleFrom(foregroundColor: Colors.purple),
    );
  }

  void _mostrarDialogoRPE(Map<String, dynamic> sesion, {int? rpeActual}) {
    int rpeSeleccionado = rpeActual ?? 5;
    final notasController = TextEditingController();
    
    final descripciones = {
      1: 'Muy muy fácil',
      2: 'Fácil',
      3: 'Moderado',
      4: 'Algo difícil',
      5: 'Difícil',
      6: 'Más difícil',
      7: 'Muy difícil',
      8: 'Muy muy difícil',
      9: 'Casi máximo',
      10: 'Máximo esfuerzo',
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('🧠 ¿Cómo te sentiste?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'RPE (Rating of Perceived Exertion)\nEscala del 1 al 10',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Slider visual
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$rpeSeleccionado', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.purple)),
                  const Text('/10', style: TextStyle(fontSize: 24, color: Colors.grey)),
                ],
              ),
              Text(
                descripciones[rpeSeleccionado] ?? '',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Slider(
                value: rpeSeleccionado.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: Colors.purple,
                onChanged: (v) => setDialogState(() => rpeSeleccionado = v.round()),
              ),
              // Botones rápidos
              Wrap(
                spacing: 4,
                children: List.generate(10, (i) {
                  final val = i + 1;
                  return ChoiceChip(
                    label: Text('$val'),
                    selected: rpeSeleccionado == val,
                    onSelected: (_) => setDialogState(() => rpeSeleccionado = val),
                    selectedColor: Colors.purple.withOpacity(0.3),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notasController,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  hintText: 'ej: Piernas cansadas, buen ritmo...',
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                final api = context.read<ApiService>();
                await api.reportarRPE(
                  sesion['id'],
                  rpeSeleccionado,
                  notas: notasController.text.isNotEmpty ? notasController.text : null,
                );
                Navigator.pop(ctx);
                _loadPlan();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ RPE $rpeSeleccionado registrado'),
                    backgroundColor: Colors.purple,
                  ),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoEditarDatos(Map<String, dynamic> sesion) {
    final strava = sesion['strava'] as Map<String, dynamic>?;
    final real = sesion['real'] as Map<String, dynamic>?;
    
    // Valores actuales (override si existe, sino strava)
    final distanciaController = TextEditingController(
      text: (real?['distancia_km'] ?? strava?['distancia_km'])?.toStringAsFixed(2) ?? '',
    );
    final desnivelController = TextEditingController(
      text: (real?['desnivel_m'] ?? strava?['desnivel_m'])?.toString() ?? '',
    );
    final tiempoController = TextEditingController(
      text: (real?['tiempo_min'] ?? strava?['tiempo_min'])?.toStringAsFixed(1) ?? '',
    );
    final fcController = TextEditingController(
      text: (real?['fc_media'] ?? strava?['fc_media'])?.toString() ?? '',
    );
    final notasController = TextEditingController(
      text: real?['override_notas'] ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('✏️ Corregir datos'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Corrige los datos si Strava no los registró correctamente.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: distanciaController,
                decoration: const InputDecoration(
                  labelText: 'Distancia (km)',
                  hintText: 'ej: 8.53',
                  prefixIcon: Icon(Icons.straighten),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: desnivelController,
                decoration: const InputDecoration(
                  labelText: 'Desnivel (m)',
                  hintText: 'ej: 450',
                  prefixIcon: Icon(Icons.terrain),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tiempoController,
                decoration: const InputDecoration(
                  labelText: 'Tiempo (minutos)',
                  hintText: 'ej: 52.5 (52min 30seg)',
                  prefixIcon: Icon(Icons.timer),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fcController,
                decoration: const InputDecoration(
                  labelText: 'FC media (bpm)',
                  hintText: 'ej: 145',
                  prefixIcon: Icon(Icons.favorite),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notasController,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  hintText: 'ej: GPS falló, medido con mapa',
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          // Botón restaurar (solo si hay override)
          if (real?['tiene_override'] == true)
            TextButton(
              onPressed: () async {
                final api = context.read<ApiService>();
                await api.eliminarOverrideSesion(sesion['id']);
                Navigator.pop(ctx);
                _loadPlan();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Datos restaurados de Strava'), backgroundColor: Colors.blue),
                );
              },
              child: const Text('Restaurar Strava', style: TextStyle(color: Colors.grey)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final api = context.read<ApiService>();
              await api.actualizarOverrideSesion(
                sesion['id'],
                distanciaKm: double.tryParse(distanciaController.text),
                desnivelM: int.tryParse(desnivelController.text),
                tiempoMin: double.tryParse(tiempoController.text),
                fcMedia: int.tryParse(fcController.text),
                notas: notasController.text.isNotEmpty ? notasController.text : null,
              );
              Navigator.pop(ctx);
              _loadPlan();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Datos corregidos'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _buildStravaMetric(String emoji, String value) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  String _formatTiempo(double? minutos) {
    if (minutos == null) return '-';
    final horas = (minutos / 60).floor();
    final mins = (minutos % 60).round();
    if (horas > 0) {
      return '${horas}h ${mins}m';
    }
    return '${mins}m';
  }
}
