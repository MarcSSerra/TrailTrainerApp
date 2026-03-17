import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/perfil_model.dart';

class ObjetivosScreen extends StatefulWidget {
  const ObjetivosScreen({super.key});

  @override
  State<ObjetivosScreen> createState() => _ObjetivosScreenState();
}

class _ObjetivosScreenState extends State<ObjetivosScreen> {
  List<Objetivo> _objetivos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadObjetivos();
  }

  Future<void> _loadObjetivos() async {
    final auth = context.read<AuthService>();
    if (auth.userId == null) return;

    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final objetivos = await api.getObjetivos(auth.userId!);
      setState(() => _objetivos = objetivos);
    } catch (e) {
      // Sin objetivos
    } finally {
      setState(() => _loading = false);
    }
  }

  void _mostrarDialogoObjetivo() {
    final nombreCtrl = TextEditingController();
    final distanciaCtrl = TextEditingController();
    final desnivelCtrl = TextEditingController();
    final tiempoCtrl = TextEditingController();
    DateTime fecha = DateTime.now().add(const Duration(days: 90));
    int prioridad = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nuevo Objetivo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre de la carrera'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text('Fecha: ${DateFormat('dd/MM/yyyy').format(fecha)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: fecha,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (date != null) setDialogState(() => fecha = date);
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: distanciaCtrl,
                        decoration: const InputDecoration(labelText: 'Distancia (km)'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: desnivelCtrl,
                        decoration: const InputDecoration(labelText: 'Desnivel (m)'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: tiempoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tiempo objetivo',
                    hintText: 'ej: 5:30:00',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Prioridad:'),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('Principal')),
                    ButtonSegment(value: 2, label: Text('Secundario')),
                  ],
                  selected: {prioridad},
                  onSelectionChanged: (s) => setDialogState(() => prioridad = s.first),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                final auth = context.read<AuthService>();
                final api = context.read<ApiService>();
                await api.crearObjetivo(auth.userId!, {
                  'nombre': nombreCtrl.text,
                  'fecha': fecha.toIso8601String().split('T')[0],
                  'distancia_km': double.tryParse(distanciaCtrl.text),
                  'desnivel_m': int.tryParse(desnivelCtrl.text),
                  'tiempo_objetivo': tiempoCtrl.text.isNotEmpty ? tiempoCtrl.text : null,
                  'prioridad': prioridad,
                });
                Navigator.pop(ctx);
                _loadObjetivos();
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: _objetivos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.flag_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No tienes objetivos'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _mostrarDialogoObjetivo,
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir carrera'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadObjetivos,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _objetivos.length,
                itemBuilder: (ctx, i) {
                  final obj = _objetivos[i];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: obj.prioridad == 1 
                            ? Theme.of(context).colorScheme.primary 
                            : Colors.grey,
                        child: Icon(
                          Icons.flag,
                          color: obj.prioridad == 1 ? Colors.white : Colors.white70,
                        ),
                      ),
                      title: Text(obj.nombre),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${DateFormat('dd MMM yyyy').format(obj.fecha)} · '
                            '${obj.semanasRestantes} semanas',
                          ),
                          if (obj.distanciaKm != null || obj.desnivelM != null)
                            Text(
                              '${obj.distanciaKm ?? "?"}km · D+${obj.desnivelM ?? "?"}m',
                              style: const TextStyle(fontSize: 12),
                            ),
                          if (obj.tiempoObjetivo != null || obj.tiempoEstimado != null)
                            Row(
                              children: [
                                if (obj.tiempoObjetivo != null)
                                  Text(
                                    '🎯 ${obj.tiempoObjetivo}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                if (obj.tiempoObjetivo != null && obj.tiempoEstimado != null)
                                  const Text(' · ', style: TextStyle(fontSize: 12)),
                                if (obj.tiempoEstimado != null)
                                  Text(
                                    '📊 Est: ${obj.tiempoEstimado}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Eliminar objetivo'),
                              content: Text('¿Eliminar "${obj.nombre}"?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            final api = context.read<ApiService>();
                            await api.eliminarObjetivo(obj.id);
                            _loadObjetivos();
                          }
                        },
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: _objetivos.isNotEmpty
          ? FloatingActionButton(
              onPressed: _mostrarDialogoObjetivo,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
