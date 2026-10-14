import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;

import 'package:health/health.dart';

import '../core/models.dart';

/// Lee los datos del reloj a través de Health Connect (Android) o Apple Salud (iPhone).
/// Las apps de los fabricantes (Mi Fitness, Zepp, Samsung Health, Garmin Connect…)
/// escriben ahí sus datos; Coachless solo los lee con permiso del usuario.
class HealthService {
  static final Health _health = Health();
  static bool _configured = false;

  static List<HealthDataType> get _types => [
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.RESTING_HEART_RATE,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        (defaultTargetPlatform == TargetPlatform.iOS) ? HealthDataType.SLEEP_ASLEEP : HealthDataType.SLEEP_SESSION,
        HealthDataType.WORKOUT,
        HealthDataType.WEIGHT,
        HealthDataType.BODY_FAT_PERCENTAGE,
      ];

  static Future<void> _ensure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// En Android verifica que Health Connect esté instalado.
  static Future<bool> available() async {
    try {
      await _ensure();
      if ((defaultTargetPlatform == TargetPlatform.android)) return await _health.isHealthConnectAvailable();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> installHealthConnect() async {
    try {
      await _health.installHealthConnect();
    } catch (_) {}
  }

  static Future<bool> requestPermissions() async {
    try {
      await _ensure();
      final types = _types;
      return await _health.requestAuthorization(types, permissions: types.map((_) => HealthDataAccess.READ).toList());
    } catch (_) {
      return false;
    }
  }

  /// Resumen de hoy: pasos, pulso en reposo, calorías activas y horas de sueño de anoche.
  static Future<WatchData?> today(String source) async {
    try {
      await _ensure();
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(midnight, now) ?? 0;
      final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.RESTING_HEART_RATE, HealthDataType.HEART_RATE, HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: midnight,
        endTime: now,
      );
      double kcal = 0, hrSum = 0;
      int hrN = 0;
      double? resting;
      for (final p in points) {
        final v = p.value;
        if (v is! NumericHealthValue) continue;
        final n = v.numericValue.toDouble();
        if (p.type == HealthDataType.ACTIVE_ENERGY_BURNED) kcal += n;
        if (p.type == HealthDataType.RESTING_HEART_RATE) resting = n;
        if (p.type == HealthDataType.HEART_RATE) {
          hrSum += n;
          hrN++;
        }
      }
      final sleepType = (defaultTargetPlatform == TargetPlatform.iOS) ? HealthDataType.SLEEP_ASLEEP : HealthDataType.SLEEP_SESSION;
      final sleep = await _health.getHealthDataFromTypes(types: [sleepType], startTime: midnight.subtract(const Duration(hours: 12)), endTime: now);
      final sleepMin = sleep.fold<double>(0, (a, p) => a + p.dateTo.difference(p.dateFrom).inMinutes);
      return WatchData(
        steps: steps,
        restingHr: (resting ?? (hrN > 0 ? hrSum / hrN : 0)).round(),
        activeKcal: kcal.round(),
        sleepHours: double.parse((sleepMin / 60).toStringAsFixed(1)),
        source: source,
      );
    } catch (_) {
      return null;
    }
  }

  /// Entrenamientos registrados por el reloj en un día.
  static Future<List<OtherActivity>> workouts(DateTime day, String source) async {
    try {
      await _ensure();
      final start = DateTime(day.year, day.month, day.day);
      final pts = await _health.getHealthDataFromTypes(types: [HealthDataType.WORKOUT], startTime: start, endTime: start.add(const Duration(days: 1)));
      return pts.map((p) {
        final v = p.value;
        final mins = p.dateTo.difference(p.dateFrom).inMinutes;
        var name = 'Gimnasio';
        int kcal = (mins * 6).round();
        if (v is WorkoutHealthValue) {
          name = _sportName(v.workoutActivityType.name);
          kcal = v.totalEnergyBurned ?? kcal;
        }
        return OtherActivity(name: name, minutes: mins, intensity: mins > 60 ? 'Alta' : 'Media', kcal: kcal, source: source);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Última lectura de báscula (peso y % de grasa) guardada en Health Connect / Apple Salud en los últimos 30 días.
  static Future<(double?, double?)> latestBodyComposition() async {
    try {
      await _ensure();
      final now = DateTime.now();
      final pts = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WEIGHT, HealthDataType.BODY_FAT_PERCENTAGE],
        startTime: now.subtract(const Duration(days: 30)),
        endTime: now,
      );
      double? w, f;
      DateTime? tw, tf;
      for (final p in pts) {
        final v = p.value;
        if (v is! NumericHealthValue) continue;
        final n = v.numericValue.toDouble();
        if (p.type == HealthDataType.WEIGHT && (tw == null || p.dateFrom.isAfter(tw))) {
          w = n;
          tw = p.dateFrom;
        }
        if (p.type == HealthDataType.BODY_FAT_PERCENTAGE && (tf == null || p.dateFrom.isAfter(tf))) {
          f = n <= 1 ? n * 100 : n;
          tf = p.dateFrom;
        }
      }
      return (w, f);
    } catch (_) {
      return (null, null);
    }
  }

  static String _sportName(String type) {
    final t = type.toUpperCase();
    if (t.contains('RUN')) return 'Running';
    if (t.contains('WALK')) return 'Caminata';
    if (t.contains('BIK') || t.contains('CYCL')) return 'Ciclismo';
    if (t.contains('SWIM')) return 'Natación';
    if (t.contains('SOCCER') || t.contains('FOOTBALL')) return 'Fútbol';
    if (t.contains('DANC')) return 'Baile';
    if (t.contains('YOGA')) return 'Yoga';
    if (t.contains('SKAT')) return 'Patinaje';
    if (t.contains('BASKET')) return 'Baloncesto';
    if (t.contains('TENNIS')) return 'Tenis';
    if (t.contains('MARTIAL') || t.contains('BOX')) return 'Artes marciales';
    return 'Gimnasio';
  }
}
