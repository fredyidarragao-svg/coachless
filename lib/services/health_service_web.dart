import '../core/models.dart';
import 'health_report.dart';

/// Versión web: el navegador no puede leer Health Connect ni Apple Salud.
class HealthService {
  static HealthReport? lastReport;
  static Future<bool> available() async => false;
  static Future<void> installHealthConnect() async {}
  static Future<bool> requestPermissions() async => false;
  static Future<WatchData?> today(String source, {double bmr = 1650}) async => null;
  static Future<List<OtherActivity>> workouts(DateTime day, String source) async => [];
  static Future<(double?, double?)> latestBodyComposition() async => (null, null);
}
