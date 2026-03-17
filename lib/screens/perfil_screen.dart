import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/perfil_model.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  Perfil? _perfil;
  List<Lesion> _lesiones = [];
  bool _loading = true;
  bool _editando = false;

  final _nombreCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();
  final _alturaCtrl = TextEditingController();
  final _fcMaxCtrl = TextEditingController();
  final _fcReposoCtrl = TextEditingController();
  DateTime? _fechaNacimiento;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthService>();
    if (auth.userId == null) return;

    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final perfil = await api.getPerfil(auth.userId!);
      final lesiones = await api.getLesiones(auth.userId!);
      
      setState(() {
        _perfil = perfil;
        _lesiones = lesiones;
        _nombreCtrl.text = perfil.nombre ?? '';
        _pesoCtrl.text = perfil.pesoKg?.toString() ?? '';
        _alturaCtrl.text = perfil.alturaCm?.toString() ?? '';
        _fcMaxCtrl.text = perfil.fcMaxima?.toString() ?? '';
        _fcReposoCtrl.text = perfil.fcReposo?.toString() ?? '';
        _fechaNacimiento = perfil.fechaNacimiento;
      });
    } catch (e) {
      // Perfil nuevo, no existe aún
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _guardarPerfil() async {
    final auth = context.read<AuthService>();
    if (auth.userId == null) return;

    try {
      final api = context.read<ApiService>();
      await api.updatePerfil(auth.userId!, {
        'nombre': _nombreCtrl.text,
        'peso_kg': double.tryParse(_pesoCtrl.text),
        'altura_cm': int.tryParse(_alturaCtrl.text),
        'fc_maxima': int.tryParse(_fcMaxCtrl.text),
        'fc_reposo': int.tryParse(_fcReposoCtrl.text),
        'fecha_nacimiento': _fechaNacimiento?.toIso8601String().split('T')[0],
      });
      setState(() => _editando = false);
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _mostrarDialogoLesion() {
    final zonaCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    int severidad = 2;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nueva Lesión'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: zonaCtrl,
                decoration: const InputDecoration(labelText: 'Zona (ej: rodilla derecha)'),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 16),
              const Text('Severidad:'),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('Leve')),
                  ButtonSegment(value: 2, label: Text('Moderada')),
                  ButtonSegment(value: 3, label: Text('Grave')),
                ],
                selected: {severidad},
                onSelectionChanged: (s) => setDialogState(() => severidad = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                final auth = context.read<AuthService>();
                final api = context.read<ApiService>();
                await api.crearLesion(auth.userId!, {
                  'zona': zonaCtrl.text,
                  'descripcion': descCtrl.text,
                  'fecha_inicio': DateTime.now().toIso8601String().split('T')[0],
                  'severidad': severidad,
                });
                Navigator.pop(ctx);
                _loadData();
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Perfil
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Mi Perfil', style: Theme.of(context).textTheme.titleLarge),
                      IconButton(
                        icon: Icon(_editando ? Icons.close : Icons.edit),
                        onPressed: () => setState(() => _editando = !_editando),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_editando) ...[
                    TextField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _pesoCtrl, decoration: const InputDecoration(labelText: 'Peso (kg)'), keyboardType: TextInputType.number)),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: _alturaCtrl, decoration: const InputDecoration(labelText: 'Altura (cm)'), keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _fcMaxCtrl, decoration: const InputDecoration(labelText: 'FC Máx'), keyboardType: TextInputType.number)),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: _fcReposoCtrl, decoration: const InputDecoration(labelText: 'FC Reposo'), keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: Text(_fechaNacimiento != null 
                          ? 'Nacimiento: ${DateFormat('dd/MM/yyyy').format(_fechaNacimiento!)}'
                          : 'Fecha de nacimiento'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _fechaNacimiento ?? DateTime(1990),
                          firstDate: DateTime(1940),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) setState(() => _fechaNacimiento = date);
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _guardarPerfil, child: const Text('Guardar')),
                  ] else ...[
                    _buildInfoRow('Nombre', _perfil?.nombre ?? '-'),
                    _buildInfoRow('Edad', _perfil?.edad != null ? '${_perfil!.edad} años' : '-'),
                    _buildInfoRow('Peso', _perfil?.pesoKg != null ? '${_perfil!.pesoKg} kg' : '-'),
                    _buildInfoRow('Altura', _perfil?.alturaCm != null ? '${_perfil!.alturaCm} cm' : '-'),
                    _buildInfoRow('IMC', _perfil?.imc != null ? '${_perfil!.imc}' : '-'),
                    _buildInfoRow('FC Máxima', _perfil?.fcMaxima != null ? '${_perfil!.fcMaxima} bpm' : '-'),
                    _buildInfoRow('FC Reposo', _perfil?.fcReposo != null ? '${_perfil!.fcReposo} bpm' : '-'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Lesiones
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Lesiones Activas', style: Theme.of(context).textTheme.titleLarge),
                      IconButton(icon: const Icon(Icons.add), onPressed: _mostrarDialogoLesion),
                    ],
                  ),
                  if (_lesiones.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Sin lesiones activas 💪'),
                    )
                  else
                    ..._lesiones.map((l) => ListTile(
                      leading: Icon(
                        Icons.healing,
                        color: l.severidad == 3 ? Colors.red : l.severidad == 2 ? Colors.orange : Colors.yellow,
                      ),
                      title: Text(l.zona),
                      subtitle: Text('${l.severidadTexto} · ${l.diasLesionado} días'),
                      trailing: TextButton(
                        onPressed: () async {
                          final api = context.read<ApiService>();
                          await api.curarLesion(l.id);
                          _loadData();
                        },
                        child: const Text('Curada'),
                      ),
                    )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _pesoCtrl.dispose();
    _alturaCtrl.dispose();
    _fcMaxCtrl.dispose();
    _fcReposoCtrl.dispose();
    super.dispose();
  }
}
