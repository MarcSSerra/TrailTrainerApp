# Trail Trainer App

App Flutter para entrenamiento de trail running con IA.

## Requisitos

- Flutter SDK >= 3.0.0
- Backend corriendo en `http://localhost:8080`

## Instalación

```bash
# Instalar Flutter (macOS)
brew install --cask flutter

# Verificar instalación
flutter doctor

# Instalar dependencias
cd TrailTrainerApp
flutter pub get

# Ejecutar en modo debug
flutter run
```

## Estructura

```
lib/
├── main.dart              # Entry point
├── models/                # Modelos de datos
│   ├── actividad_model.dart
│   └── plan_model.dart
├── screens/               # Pantallas
│   ├── login_screen.dart
│   ├── home_screen.dart
│   ├── actividades_screen.dart
│   └── plan_screen.dart
└── services/              # Servicios API
    ├── api_service.dart
    └── auth_service.dart
```

## Funcionalidades

- Conexión con Strava OAuth
- Ver actividades recientes
- Generar plan de entrenamiento con IA
- Vista semanal del plan con ejercicios detallados
