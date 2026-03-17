import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/actividad_model.dart';

class ActividadesScreen extends StatefulWidget {
  const ActividadesScreen({super.key});

  @override
  State<ActividadesScreen> createState() => _ActividadesScreenState();
}

class _ActividadesScreenState extends State<ActividadesScreen> {
  List<Actividad>? _actividades;
  bool _loading = true;
  String? _error;
  int _dias = 7;

  @override
  void initState() {
    super.initState();
    _loadActividades();
  }

  Future<void> _loadActividades() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiService>();
      final auth = context.read<AuthService>();
      final acts = await api.getActividades(dias: _dias, userId: auth.userId);
      setState(() => _actividades = acts);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  IconData _getIconForType(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'run':
        return Icons.directions_run;
      case 'ride':
        return Icons.directions_bike;
      case 'weighttraining':
        return Icons.fitness_center;
      case 'swim':
        return Icons.pool;
      default:
        return Icons.sports;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('Últimos '),
              DropdownButton<int>(
                value: _dias,
                items: [7, 14, 30].map((d) => DropdownMenuItem(
                  value: d,
                  child: Text('$d días'),
                )).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _dias = v);
                    _loadActividades();
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadActividades,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_actividades == null || _actividades!.isEmpty) {
      return const Center(child: Text('No hay actividades'));
    }

    return RefreshIndicator(
      onRefresh: _loadActividades,
      child: ListView.builder(
        itemCount: _actividades!.length,
        itemBuilder: (ctx, i) {
          final act = _actividades![i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(_getIconForType(act.tipo)),
              ),
              title: Text(act.nombre),
              subtitle: Text(
                '${DateFormat('dd/MM').format(act.fecha)} · '
                '${act.distanciaKm.toStringAsFixed(1)} km · '
                '${act.tiempoFormateado}',
              ),
              trailing: act.desnivelM > 0
                  ? Text('+${act.desnivelM.round()}m')
                  : null,
            ),
          );
        },
      ),
    );
  }
}
