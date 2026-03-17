import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class NutricionScreen extends StatefulWidget {
  const NutricionScreen({super.key});

  @override
  State<NutricionScreen> createState() => _NutricionScreenState();
}

class _NutricionScreenState extends State<NutricionScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _nutricion;
  Map<String, dynamic>? _planSemanal;
  bool _loading = true;
  bool _generandoPlan = false;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNutricion();
    _loadPlanSemanal(); // Cargar plan guardado al inicio
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNutricion() async {
    final auth = context.read<AuthService>();
    if (auth.userId == null) return;

    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final nutricion = await api.getNutricion(auth.userId!);
      setState(() {
        _nutricion = nutricion;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadPlanSemanal() async {
    final auth = context.read<AuthService>();
    if (auth.userId == null) return;

    try {
      final api = context.read<ApiService>();
      final plan = await api.getNutricionSemana(auth.userId!);
      if (plan != null) {
        setState(() => _planSemanal = plan);
      }
    } catch (e) {
      // No hay plan guardado, no es error
    }
  }

  Future<void> _generarPlanSemanal({bool regenerar = false}) async {
    final auth = context.read<AuthService>();
    if (auth.userId == null) return;

    print('DEBUG: _generarPlanSemanal llamado con regenerar=$regenerar');

    setState(() {
      _generandoPlan = true;
      _error = null;
    });
    
    try {
      final api = context.read<ApiService>();
      final plan = regenerar 
          ? await api.regenerarNutricionSemana(auth.userId!)
          : await api.getNutricionSemana(auth.userId!);
      print('DEBUG: Plan recibido: ${plan != null}');
      setState(() => _planSemanal = plan);
    } catch (e) {
      print('DEBUG: Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _generandoPlan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _nutricion == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadNutricion, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.pie_chart), text: 'Resumen'),
            Tab(icon: Icon(Icons.calendar_today), text: 'Plan Semanal'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildResumen(),
              _buildPlanSemanal(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResumen() {
    if (_nutricion == null) {
      return const Center(child: Text('Sin datos de nutrición'));
    }

    final n = _nutricion!;
    return RefreshIndicator(
      onRefresh: _loadNutricion,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Macros principales
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🎯 Objetivos Diarios Base', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildMacroRow('🔥 Calorías', '${n['calorias_objetivo']} kcal', Colors.orange),
                  _buildMacroRow('🥩 Proteínas', '${n['proteinas_g']}g', Colors.red),
                  _buildMacroRow('🍞 Carbohidratos', '${n['carbohidratos_g']}g', Colors.amber),
                  _buildMacroRow('🥑 Grasas', '${n['grasas_g']}g', Colors.green),
                  _buildMacroRow('💧 Hidratación', '${n['hidratacion_litros']}L', Colors.blue),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Timing de comidas
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⏰ Timing Nutricional', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildTimingTile('🏃 Pre-entreno', n['pre_entreno'] ?? 'No especificado'),
                  _buildTimingTile('💪 Post-entreno', n['post_entreno'] ?? 'No especificado'),
                  _buildTimingTile('🏁 Día de carrera', n['dia_carrera'] ?? 'No especificado'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Suplementos
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💊 Suplementos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...((n['suplementos'] as List?) ?? []).map((s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(s.toString())),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Nota para generar plan personalizado
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.auto_awesome, size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    'Para un plan nutricional personalizado día a día, ve a la pestaña "Plan Semanal"',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSemanal() {
    if (_planSemanal == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Genera un plan nutricional personalizado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'El agente nutricionista analizará tu plan de entrenamiento y creará recomendaciones específicas para cada día.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _generandoPlan ? null : _generarPlanSemanal,
                icon: _generandoPlan
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome),
                label: Text(_generandoPlan ? 'Generando...' : 'Generar Plan Nutricional'),
              ),
            ],
          ),
        ),
      );
    }

    final plan = _planSemanal!['plan'] as Map<String, dynamic>;
    final dias = (plan['dias'] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _generarPlanSemanal,
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          // Resumen del plan
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📋 Resumen Semanal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(plan['resumen'] ?? 'Plan nutricional personalizado'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip('🔥 ${plan['calorias_promedio']} kcal/día', Colors.orange),
                      _buildChip('🥩 ${plan['proteinas_g_dia']}g prot', Colors.red),
                      _buildChip('🍞 ${plan['carbohidratos_g_dia']}g carbs', Colors.amber),
                      _buildChip('💧 ${plan['hidratacion_litros_dia']}L agua', Colors.blue),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          // Alimentos clave
          if ((plan['alimentos_clave'] as List?)?.isNotEmpty ?? false)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🥗 Alimentos Clave', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: (plan['alimentos_clave'] as List).map((a) => 
                        Chip(label: Text(a.toString(), style: const TextStyle(fontSize: 12)))
                      ).toList(),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),

          // Plan día a día
          ...dias.map((dia) => _buildDiaCard(dia as Map<String, dynamic>)),
          
          // Suplementos
          if ((plan['suplementos'] as List?)?.isNotEmpty ?? false)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💊 Suplementos Recomendados', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...((plan['suplementos'] as List).map((s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• $s'),
                    ))),
                  ],
                ),
              ),
            ),
          
          // Botón regenerar
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: _generandoPlan ? null : () => _generarPlanSemanal(regenerar: true),
              icon: _generandoPlan 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              label: Text(_generandoPlan ? 'Regenerando...' : 'Regenerar Plan'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiaCard(Map<String, dynamic> dia) {
    return Card(
      child: ExpansionTile(
        leading: _getIconForSession(dia['tipo_sesion'] ?? ''),
        title: Text(dia['dia'] ?? 'Día'),
        subtitle: Text(dia['tipo_sesion'] ?? 'Sin sesión'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Macros del día
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMiniMacro('🔥', '${dia['calorias']}', 'kcal'),
                    _buildMiniMacro('🥩', '${dia['proteinas_g']}', 'g prot'),
                    _buildMiniMacro('🍞', '${dia['carbohidratos_g']}', 'g carbs'),
                    _buildMiniMacro('💧', '${dia['hidratacion_litros']}', 'L'),
                  ],
                ),
                const Divider(height: 24),
                
                // Comidas
                if (dia['desayuno'] != null) _buildComida('🌅 Desayuno', dia['desayuno']),
                if (dia['comida'] != null) _buildComida('🍽️ Comida', dia['comida']),
                if (dia['cena'] != null) _buildComida('🌙 Cena', dia['cena']),
                if (dia['snacks'] != null) _buildComida('🍎 Snacks', dia['snacks']),
                
                // Pre/Post entreno si aplica
                if (dia['pre_entreno'] != null) ...[
                  const Divider(height: 16),
                  _buildComida('🏃 Pre-entreno', dia['pre_entreno']),
                ],
                if (dia['post_entreno'] != null)
                  _buildComida('💪 Post-entreno', dia['post_entreno']),
                
                // Notas
                if (dia['notas'] != null) ...[
                  const Divider(height: 16),
                  Text(
                    dia['notas'],
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMacro(String emoji, String value, String unit) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(unit, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildComida(String titulo, String contenido) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(contenido, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildMacroRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimingTile(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }

  Icon _getIconForSession(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('descanso') || t.contains('vacaciones')) {
      return const Icon(Icons.bed, color: Colors.grey);
    } else if (t.contains('tirada') || t.contains('trail')) {
      return const Icon(Icons.terrain, color: Colors.green);
    } else if (t.contains('series') || t.contains('fartlek')) {
      return const Icon(Icons.speed, color: Colors.orange);
    } else if (t.contains('fuerza') || t.contains('gimnasio')) {
      return const Icon(Icons.fitness_center, color: Colors.purple);
    } else if (t.contains('carrera')) {
      return const Icon(Icons.emoji_events, color: Colors.amber);
    }
    return const Icon(Icons.directions_run, color: Colors.blue);
  }
}
