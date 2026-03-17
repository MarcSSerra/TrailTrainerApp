import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'actividades_screen.dart';
import 'plan_screen.dart';
import 'perfil_screen.dart';
import 'objetivos_screen.dart';
import 'nutricion_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _screens = const [
    ActividadesScreen(),
    ObjetivosScreen(),
    PlanScreen(),
    NutricionScreen(),
    PerfilScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${auth.athleteName ?? "Atleta"}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.directions_run),
            label: 'Actividades',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag),
            label: 'Objetivos',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: 'Mi Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant),
            label: 'Nutrición',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
