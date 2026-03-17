import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  String? _userId;
  String? _athleteName;
  bool _isAuthenticated = false;
  bool _initialized = false;

  bool get isAuthenticated => _isAuthenticated;
  bool get initialized => _initialized;
  String? get userId => _userId;
  String? get athleteName => _athleteName;

  AuthService() {
    _loadSavedAuth();
  }

  Future<void> _loadSavedAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('user_id');
      _athleteName = prefs.getString('athlete_name');
      _isAuthenticated = _userId != null && _userId!.isNotEmpty;
      debugPrint('Auth loaded: userId=$_userId, authenticated=$_isAuthenticated');
    } catch (e) {
      debugPrint('Error loading auth: $e');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> setAuthenticated({
    required String userId,
    required String athleteName,
  }) async {
    _userId = userId;
    _athleteName = athleteName;
    _isAuthenticated = true;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('athlete_name', athleteName);
    debugPrint('Auth saved: userId=$userId');
    notifyListeners();
  }

  Future<void> logout() async {
    _userId = null;
    _athleteName = null;
    _isAuthenticated = false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('athlete_name');
    notifyListeners();
  }
}
