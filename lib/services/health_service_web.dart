import '../core/models.dart';

/// Versión web: el navegador no puede leer Health Connect ni Apple Salud.
class HealthService {
  static Future<bool> available() async => false;
  static Future<void> installHealthConnect() async {}
  static Future<bool> requestPermissions() async => false;
  static Future<WatchData?> today(String source) async => null;
  static Future<List<OtherActivity>> workouts(DateTime day, String source) async => [];
}
