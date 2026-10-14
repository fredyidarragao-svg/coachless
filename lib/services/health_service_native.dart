import 'dart:math';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;

import 'package:health/health.dart';

import '../core/models.dart';
import 'health_report.dart';

/// Lee los datos del reloj a través de Health Connect (Android) o Apple Salud (iPhone).
/// Las apps de los fabricantes (Mi Fitness, Zepp, Samsung Health, Garmin Connect…)
/// escriben ahí sus datos; Coachless solo los lee con permiso del usuario.
///
/// Cada fabricante escribe tipos distintos: por ejemplo Mi Fitness envía calorías TOTALES
/// y pulso por muestras, pero no "calorías activas" ni "pulso en reposo". Por eso cada
/// métrica tiene una alternativa calculada.
class HealthService {
  static final Health _health = Health();
  static bool _configured = false;
  static HealthReport? lastReport;

  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  static List<HealthDataType> get _types => [
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.RESTING_HEART_RATE,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        if (!_ios) HealthDataType.TOTAL_CALORIES_BURNED,
        if (_ios) HealthDataType.SLEEP_ASLEEP,
        if (!_ios) HealthDataType.SLEEP_SESSION,
        if (!_ios) HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
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
      if (!_ios) return await _health.isHealthConnectAvailable();
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

  /// Si falta algún permiso (por ejemplo tras una actualización que lee datos nuevos), lo vuelve a pedir.
  static Future<bool> _ensurePermissions() async {
    try {
      final types = _types;
      final has = await _health.hasPermissions(types, permissions: types.map((_) => HealthDataAccess.READ).toList());
      if (has == true) return true;
      // En iPhone Apple Salud nunca revela si hay permiso de lectura (devuelve null): se pide una vez y se sigue.
      return await requestPermissions() || _ios;
    } catch (_) {
      return true;
    }
  }

  /// Lee un tipo sin que un fallo en él dañe los demás.
  static Future<List<HealthDataPoint>> _read(HealthDataType type, DateTime from, DateTime to) async {
    try {
      return await _health.getHealthDataFromTypes(types: [type], startTime: from, endTime: to);
    } catch (_) {
      return [];
    }
  }

  static double _num(HealthDataPoint p) {
    final v = p.value;
    return v is NumericHealthValue ? v.numericValue.toDouble() : 0;
  }

  /// Suma la duración de intervalos de tiempo sin contar dos veces lo que se solapa
  /// (varias apps pueden escribir el mismo sueño).
  static int _mergedMinutes(Iterable<HealthDataPoint> pts) {
    final iv = pts.map((p) => [p.dateFrom, p.dateTo]).where((x) => x[1].isAfter(x[0])).toList()..sort((a, b) => a[0].compareTo(b[0]));
    var total = 0;
    DateTime? s, e;
    for (final x in iv) {
      if (e == null || x[0].isAfter(e)) {
        if (s != null) total += e!.difference(s).inMinutes;
        s = x[0];
        e = x[1];
      } else if (x[1].isAfter(e)) {
        e = x[1];
      }
    }
    if (s != null) total += e!.difference(s).inMinutes;
    return total;
  }

  /// Resumen de hoy: pasos, pulso en reposo, calorías activas y horas de sueño de anoche.
  /// [bmr] = metabolismo basal diario del usuario, para calcular calorías activas desde las totales.
  static Future<WatchData?> today(String source, {double bmr = 1650}) async {
    try {
      await _ensure();
      final perms = await _ensurePermissions();
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      // Pasos
      var steps = 0;
      try {
        steps = await _health.getTotalStepsInInterval(midnight, now) ?? 0;
      } catch (_) {}
      if (steps == 0) {
        steps = (await _read(HealthDataType.STEPS, midnight, now)).fold<double>(0, (a, p) => a + _num(p)).round();
      }

      // Pulso en reposo: el dato del reloj si lo envía; si no, se estima con el 10 % más bajo
      // de las mediciones de pulso de las últimas 24 horas (casi siempre durante el sueño).
      double resting = 0;
      final rhr = await _read(HealthDataType.RESTING_HEART_RATE, now.subtract(const Duration(days: 2)), now);
      if (rhr.isNotEmpty) {
        rhr.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        resting = _num(rhr.first);
      }
      if (resting <= 0) {
        final hr = (await _read(HealthDataType.HEART_RATE, now.subtract(const Duration(hours: 24)), now)).map(_num).where((v) => v >= 30 && v <= 220).toList()..sort();
        if (hr.isNotEmpty) {
          final n = max(1, (hr.length * .1).round());
          resting = hr.take(n).reduce((a, b) => a + b) / n;
        }
      }

      // Calorías activas: las del reloj; si solo envía totales, se resta el gasto basal de las horas transcurridas.
      var kcal = (await _read(HealthDataType.ACTIVE_ENERGY_BURNED, midnight, now)).fold<double>(0, (a, p) => a + _num(p));
      if (kcal <= 0 && !_ios) {
        final hours = now.difference(midnight).inMinutes / 60;
        final total = (await _read(HealthDataType.TOTAL_CALORIES_BURNED, midnight, now)).fold<double>(0, (a, p) => a + _num(p));
        if (total > 0) kcal = max(0.0, total - bmr * hours / 24);
      }

      // Sueño de anoche: de las 6 p. m. de ayer a ahora. Primero la sesión completa; si el reloj
      // solo envía etapas (ligero, profundo, REM), se suman sin solapes.
      final from = midnight.subtract(const Duration(hours: 6));
      var sleepPts = await _read(_ios ? HealthDataType.SLEEP_ASLEEP : HealthDataType.SLEEP_SESSION, from, now);
      if (sleepPts.isEmpty) {
        sleepPts = [
          for (final t in [if (!_ios) HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_LIGHT, HealthDataType.SLEEP_DEEP, HealthDataType.SLEEP_REM]) ...await _read(t, from, now),
        ];
      }
      final sleepMin = _mergedMinutes(sleepPts);

      lastReport = HealthReport(steps: steps > 0, heart: resting > 0, calories: kcal > 0, sleep: sleepMin > 0, permissions: perms);
      return WatchData(
        steps: steps,
        restingHr: resting.round(),
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
