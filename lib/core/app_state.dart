import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/health_service.dart';
import 'i18n.dart';
import 'models.dart';

/// Estado global: perfil del cliente y su historial diario.
class AppState extends ChangeNotifier {
  static const _kProfile = 'coachless.profile';
  static const _kLogs = 'coachless.logs';
  static const _kShop = 'coachless.shop';
  final Set<String> shopChecked = {};

  SharedPreferences? _prefs;
  Profile? profile;
  final Map<String, DayLog> _logs = {};
  String selected = todayKey();
  int tab = 0;

  bool get registered => profile != null && profile!.complete;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!.getString(_kProfile);
    if (p != null) {
      try {
        profile = Profile.fromJson(json.decode(p));
        I18n.lang = profile!.lang;
      } catch (_) {
        profile = null;
      }
    }
    shopChecked.addAll(_prefs!.getStringList(_kShop) ?? []);
    final l = _prefs!.getString(_kLogs);
    if (l != null) {
      try {
        (json.decode(l) as Map).forEach((k, v) => _logs[k] = DayLog.fromJson(v));
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    if (profile != null) await _prefs?.setString(_kProfile, json.encode(profile!.toJson()));
    await _prefs?.setString(_kLogs, json.encode(_logs.map((k, v) => MapEntry(k, v.toJson()))));
    await _prefs?.setStringList(_kShop, shopChecked.toList());
  }

  void update([VoidCallback? fn]) {
    fn?.call();
    if (profile != null) I18n.lang = profile!.lang;
    _save();
    notifyListeners();
  }

  void setProfile(Profile p) {
    profile = p;
    update();
  }

  void setLang(String l) {
    I18n.lang = l;
    if (profile != null) profile!.lang = l;
    update();
  }

  DayLog log(String day) => _logs.putIfAbsent(day, () => DayLog());
  Map<String, DayLog> get logs => _logs;

  void toggleShop(String key) => update(() => shopChecked.contains(key) ? shopChecked.remove(key) : shopChecked.add(key));
  DayLog? peek(String day) => _logs[day];

  /// Toma una muestra del reloj en este momento y la guarda como evidencia del día.
  /// Lee Health Connect / Apple Salud; si el reloj no está conectado por esa vía, guarda los datos ingresados a mano.
  /// Devuelve null si no se pudo leer.
  Future<WatchSample?> takeSample() async {
    final p = profile;
    if (p == null) return null;
    final w = p.watch;
    WatchData? d;
    if (w.route == 'hc' || w.route == 'hk') d = await HealthService.today(w.model ?? '', bmr: p.bmr);
    d ??= (w.data != null && w.data!.date == todayKey()) ? w.data : null;
    if (d == null) return null;
    final sample = WatchSample(at: DateTime.now(), steps: d.steps, restingHr: d.restingHr, activeKcal: d.activeKcal, sleepHours: d.sleepHours, source: d.source.isNotEmpty ? d.source : (w.model ?? 'Ingreso manual'));
    update(() {
      w.data = d;
      log(todayKey()).samples.add(sample);
    });
    return sample;
  }

  void select(String day) {
    selected = day;
    notifyListeners();
  }

  void setTab(int i) {
    tab = i;
    notifyListeners();
  }

  // ---- recompensas (modo niños) y racha ----
  int get totalStars => _logs.values.fold(0, (a, l) => a + l.stars);

  int get streak {
    var n = 0;
    final today = todayKey();
    for (var i = 0; i < 90; i++) {
      final l = _logs[addDays(today, -i)];
      if (l != null && l.isDone) {
        n++;
      } else if (i > 0) {
        break;
      }
    }
    return n;
  }

  List<Medal> get medals {
    final missions = _logs.values.where((l) => l.complete).length;
    final sportsDone = _logs.values.where((l) => l.sport == 'si' || l.other != null).length;
    final stars = totalStars;
    return [
      Medal('🚀', 'Primera misión', 'Completa 1 misión', missions >= 1),
      Medal('⭐', 'Coleccionista', 'Gana 25 estrellas', stars >= 25),
      Medal('🔥', 'Racha de fuego', '3 días seguidos', streak >= 3),
      Medal('⚽', 'Deportista', 'Registra 3 deportes', sportsDone >= 3),
      Medal('🏅', 'Súper estrella', 'Gana 75 estrellas', stars >= 75),
      Medal('🏆', 'Campeón', 'Completa 10 misiones', missions >= 10),
    ];
  }

  Future<void> signOut() async {
    profile = null;
    _logs.clear();
    await _prefs?.clear();
    notifyListeners();
  }
}

class Medal {
  final String emoji, name, desc;
  final bool won;
  Medal(this.emoji, this.name, this.desc, this.won);
}
