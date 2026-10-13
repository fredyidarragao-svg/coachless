/// Datos del cliente y su historial. Todo se guarda como JSON en el teléfono;
/// en la fase con servidor se sincroniza con la cuenta de Google.
library;

String dkey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime dparse(String k) {
  final p = k.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

String todayKey() => dkey(DateTime.now());
String addDays(String k, int n) => dkey(dparse(k).add(Duration(days: n)));
int weekdayOf(String k) => dparse(k).weekday - 1; // 0 = lunes
int daysBetween(String a, String b) => dparse(b).difference(dparse(a)).inDays;

class Sport {
  String name;
  List<int> days;
  int minutes;
  String intensity;
  Sport({this.name = 'Fútbol', List<int>? days, this.minutes = 60, this.intensity = 'Media'}) : days = days ?? [];
  factory Sport.fromJson(Map j) => Sport(name: j['n'], days: List<int>.from(j['dias']), minutes: j['min'], intensity: j['int']);
  Map<String, dynamic> toJson() => {'n': name, 'dias': days, 'min': minutes, 'int': intensity};
}

class WatchData {
  int steps, restingHr, activeKcal;
  double sleepHours;
  String source, date;
  WatchData({this.steps = 0, this.restingHr = 0, this.activeKcal = 0, this.sleepHours = 0, this.source = '', String? date}) : date = date ?? todayKey();
  factory WatchData.fromJson(Map j) => WatchData(
      steps: j['steps'] ?? 0, restingHr: j['hr'] ?? 0, activeKcal: j['kcal'] ?? 0, sleepHours: (j['sleep'] ?? 0).toDouble(), source: j['src'] ?? '', date: j['d']);
  Map<String, dynamic> toJson() => {'steps': steps, 'hr': restingHr, 'kcal': activeKcal, 'sleep': sleepHours, 'src': source, 'd': date};
}

/// Muestra tomada del reloj con su hora exacta: es la evidencia del día.
class WatchSample {
  final DateTime at;
  final int steps, restingHr, activeKcal;
  final double sleepHours;
  final String source;
  WatchSample({required this.at, required this.steps, required this.restingHr, required this.activeKcal, required this.sleepHours, required this.source});
  factory WatchSample.fromJson(Map j) => WatchSample(
      at: DateTime.parse(j['at']), steps: j['steps'] ?? 0, restingHr: j['hr'] ?? 0, activeKcal: j['kcal'] ?? 0, sleepHours: (j['sleep'] ?? 0).toDouble(), source: j['src'] ?? '');
  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'steps': steps, 'hr': restingHr, 'kcal': activeKcal, 'sleep': sleepHours, 'src': source};
}

/// Supermercado real encontrado cerca del usuario (OpenStreetMap).
class NearbyStore {
  final String name, website;
  final double km, priceFactor;
  NearbyStore({required this.name, required this.km, this.website = '', this.priceFactor = 1});
  factory NearbyStore.fromJson(Map j) => NearbyStore(name: j['n'], km: (j['km'] as num).toDouble(), website: j['web'] ?? '', priceFactor: (j['f'] as num?)?.toDouble() ?? 1);
  Map<String, dynamic> toJson() => {'n': name, 'km': km, 'web': website, 'f': priceFactor};
}

class WatchLink {
  String? route; // hc, hk, api o null si no está vinculado
  String? brand, model;
  String os;
  WatchData? data;
  WatchLink({this.route, this.brand, this.model, this.os = 'android', this.data});
  bool get linked => route != null;
  factory WatchLink.fromJson(Map? j) => j == null
      ? WatchLink()
      : WatchLink(route: j['route'], brand: j['brand'], model: j['model'], os: j['os'] ?? 'android', data: j['data'] == null ? null : WatchData.fromJson(j['data']));
  Map<String, dynamic> toJson() => {'route': route, 'brand': brand, 'model': model, 'os': os, 'data': data?.toJson()};
}

class WeightEntry {
  final String date;
  final double kg;
  WeightEntry(this.date, this.kg);
  Map<String, dynamic> toJson() => {'d': date, 'w': kg};
}

class Profile {
  String email, firstName, lastName, sex; // sex: m / f
  int age;
  double weight;
  int height;
  String lang, place, store;
  double budgetCop;
  bool located;
  String sleep, water;
  int mealsPerDay;
  List<String> habits;
  List<Sport> sports;
  int routineMinutes;
  List<int> routineDays;
  Map<String, String> parts;
  String dietGoal;
  List<String> equipment;
  WatchLink watch;
  List<WeightEntry> weights;
  String lastCheck;
  List<NearbyStore> nearby;
  String nearbyDate;

  Profile({
    this.email = '', this.firstName = '', this.lastName = '', this.sex = '', this.age = 0, this.weight = 0, this.height = 0,
    this.lang = 'es', this.place = 'mzl', this.store = '', this.budgetCop = 30000, this.located = false,
    this.sleep = '7', this.water = '6', this.mealsPerDay = 5, List<String>? habits, List<Sport>? sports,
    this.routineMinutes = 45, List<int>? routineDays, Map<String, String>? parts, this.dietGoal = 'mantener',
    List<String>? equipment, WatchLink? watch, List<WeightEntry>? weights, String? lastCheck, List<NearbyStore>? nearby, this.nearbyDate = '',
  })  : habits = habits ?? [], sports = sports ?? [], routineDays = routineDays ?? [0, 2, 4],
        parts = parts ?? {for (final p in ['Pecho', 'Espalda', 'Hombros', 'Brazos', 'Abdomen', 'Piernas', 'Glúteos', 'Pantorrillas']) p: 'no'},
        equipment = equipment ?? [], watch = watch ?? WatchLink(), weights = weights ?? [], lastCheck = lastCheck ?? todayKey(), nearby = nearby ?? [];

  bool get isKid => age > 0 && age < 15;
  String get theme => isKid ? 'k' : (sex == 'f' ? 'f' : 'm');
  String get initials => '${firstName.isNotEmpty ? firstName[0] : '?'}${lastName.isNotEmpty ? lastName[0] : ''}';
  bool get complete => email.isNotEmpty && sex.isNotEmpty && age > 0 && weight > 0 && height > 0;

  factory Profile.fromJson(Map j) => Profile(
        email: j['email'], firstName: j['firstName'], lastName: j['lastName'], sex: j['sex'], age: j['age'],
        weight: (j['weight'] as num).toDouble(), height: j['height'], lang: j['lang'] ?? 'es', place: j['place'] ?? 'mzl',
        store: j['store'] ?? '', budgetCop: (j['budget'] as num?)?.toDouble() ?? 30000, located: j['located'] ?? false,
        sleep: j['sleep'] ?? '7', water: j['water'] ?? '6', mealsPerDay: j['meals'] ?? 5, habits: List<String>.from(j['habits'] ?? []),
        sports: ((j['sports'] ?? []) as List).map((s) => Sport.fromJson(s)).toList(), routineMinutes: j['rMin'] ?? 45,
        routineDays: List<int>.from(j['rDays'] ?? [0, 2, 4]), parts: Map<String, String>.from(j['parts'] ?? {}), dietGoal: j['diet'] ?? 'mantener',
        equipment: List<String>.from(j['equipment'] ?? []), watch: WatchLink.fromJson(j['watch']),
        weights: ((j['weights'] ?? []) as List).map((w) => WeightEntry(w['d'], (w['w'] as num).toDouble())).toList(),
        lastCheck: j['lastCheck'],
        nearby: ((j['nearby'] ?? []) as List).map((e) => NearbyStore.fromJson(e)).toList(),
        nearbyDate: j['nearbyDate'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'email': email, 'firstName': firstName, 'lastName': lastName, 'sex': sex, 'age': age, 'weight': weight, 'height': height,
        'lang': lang, 'place': place, 'store': store, 'budget': budgetCop, 'located': located, 'sleep': sleep, 'water': water,
        'meals': mealsPerDay, 'habits': habits, 'sports': sports.map((s) => s.toJson()).toList(), 'rMin': routineMinutes,
        'rDays': routineDays, 'parts': parts, 'diet': dietGoal, 'equipment': equipment, 'watch': watch.toJson(),
        'weights': weights.map((w) => w.toJson()).toList(), 'lastCheck': lastCheck,
        'nearby': nearby.map((e) => e.toJson()).toList(), 'nearbyDate': nearbyDate,
      };

  Profile copy() => Profile.fromJson(toJson());
}

class OtherActivity {
  final String name, intensity, source;
  final int minutes, kcal;
  final int? avgHr;
  OtherActivity({required this.name, required this.minutes, required this.intensity, required this.kcal, this.avgHr, this.source = ''});
  factory OtherActivity.fromJson(Map j) => OtherActivity(name: j['n'], minutes: j['min'], intensity: j['int'], kcal: j['kcal'], avgHr: j['hr'], source: j['src'] ?? '');
  Map<String, dynamic> toJson() => {'n': name, 'min': minutes, 'int': intensity, 'kcal': kcal, 'hr': avgHr, 'src': source};
}

class DayLog {
  Set<String> done;
  bool complete, extra;
  String? sport; // 'si' / 'no'
  String? skip; // motivo
  OtherActivity? other;
  Map<String, String> meals; // franja → id de receta elegida
  List<WatchSample> samples; // muestras del reloj tomadas ese día
  Map<String, String> swaps; // ejercicio original → ejercicio elegido para reemplazarlo
  DayLog({Set<String>? done, this.complete = false, this.extra = false, this.sport, this.skip, this.other, Map<String, String>? meals, List<WatchSample>? samples, Map<String, String>? swaps})
      : done = done ?? {}, meals = meals ?? {}, samples = samples ?? [], swaps = swaps ?? {};
  WatchSample? get lastSample => samples.isEmpty ? null : samples.last;
  bool get isDone => complete || sport == 'si' || other != null;
  int get stars => done.length + (complete ? 3 : 0) + (sport == 'si' ? 3 : 0) + (other != null ? 2 : 0);
  factory DayLog.fromJson(Map j) => DayLog(
      done: Set<String>.from(j['done'] ?? []), complete: j['complete'] ?? false, extra: j['extra'] ?? false, sport: j['sport'], skip: j['skip'],
      other: j['other'] == null ? null : OtherActivity.fromJson(j['other']), meals: Map<String, String>.from(j['meals'] ?? {}),
      samples: ((j['samples'] ?? []) as List).map((e) => WatchSample.fromJson(e)).toList(),
      swaps: Map<String, String>.from(j['swaps'] ?? {}));
  Map<String, dynamic> toJson() => {
        'done': done.toList(), 'complete': complete, 'extra': extra, 'sport': sport, 'skip': skip, 'other': other?.toJson(), 'meals': meals,
        'samples': samples.map((e) => e.toJson()).toList(),
        'swaps': swaps,
      };
}
