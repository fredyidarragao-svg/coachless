import 'dart:math';

import 'catalog.dart';
import 'i18n.dart';
import 'models.dart';

int strHash(String s) {
  var h = 0x811C9DC5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

// ------------------------------------------------------------------
// Rutinas
// ------------------------------------------------------------------
class RoutineItem {
  final Exercise ex;
  final String rx;
  RoutineItem(this.ex, this.rx);
}

class RoutineBlock {
  final String title;
  final int minutes;
  final List<RoutineItem> items;
  final String sub;
  RoutineBlock(this.title, this.minutes, this.items, [this.sub = '']);
}

class Routine {
  final List<RoutineBlock> blocks;
  final List<String> parts;
  final int minutes;
  final bool lowSleep;
  Routine(this.blocks, this.parts, this.minutes, this.lowSleep);
  List<RoutineItem> get all => blocks.expand((b) => b.items).toList();
}

final _iso = RegExp(r'Plancha|Hollow|isométric|Colgarse|Paseo|Pallof');

bool _kidOk(Exercise e) =>
    e.lib != 'barra' && e.eq != 'gym' && e.eq != 'paralelas' && e.level < 3 && !RegExp(r'Peso muerto|Turkish|Cargada|Molino').hasMatch(e.es);

String prescription(Exercise e, String? goal, bool kid, bool low, String kind) {
  String s;
  final iso = _iso.hasMatch(e.es);
  if (kind == 'warm') {
    s = t('3 min suave');
  } else if (kind == 'fin') {
    s = kid
        ? t('6 min jugando')
        : RegExp(r'zona 2|continu|Caminata|Trote|Escaladora').hasMatch(e.es)
            ? t('12 min a ritmo cómodo')
            : t('8–10 min · 30 s fuerte / 30 s suave');
  } else if (kind == 'cool') {
    s = t('30 s por lado');
  } else if (kid) {
    s = iso ? '3 × 20 s' : '3 × 10–12 · ${t('técnica primero')}';
  } else if (goal == 'masa') {
    s = iso ? '4 × 40 s' : '4 × 8–10 · ${t('descanso {n} s', {'n': 90})}';
  } else if (goal == 'disminuir') {
    s = iso ? '3 × 30 s' : '3 × 15–20 · ${t('circuito')}';
  } else {
    s = iso ? '3 × 30 s' : '3 × 12–15 · ${t('descanso {n} s', {'n': 60})}';
  }
  if (low && RegExp(r'^[34] ×').hasMatch(s)) s = '${int.parse(s[0]) - 1}${s.substring(1)}';
  return s;
}

List<Exercise> _pick(List<Exercise> pool, int n, Random rng, Set<String> used, [bool Function(Exercise)? prefer]) {
  var pp = pool.where((e) => !used.contains(e.id)).toList();
  if (prefer != null) {
    final pr = pp.where(prefer).toList();
    if (pr.length >= n) pp = pr;
  }
  final out = <Exercise>[];
  for (var i = 0; i < n && pp.isNotEmpty; i++) {
    final j = rng.nextInt(pp.length);
    out.add(pp[j]);
    used.add(pp[j].id);
    pp.removeAt(j);
  }
  return out;
}

Routine generateRoutine(Profile p, String day) {
  final kid = p.isKid;
  final rng = Random(strHash(day + p.email));
  final have = {'ninguno', ...p.equipment};
  bool ok(Exercise e) => have.contains(e.eq) && (!kid || _kidOk(e));
  final wd = weekdayOf(day);
  final days = [...p.routineDays]..sort();
  final n = max(1, days.length);
  var idx = days.indexOf(wd);
  if (idx < 0) idx = wd % n;

  var targets = bodyParts.where((x) => x != 'Abdomen' && (p.parts[x] ?? 'no') != 'no').toList();
  if (targets.isEmpty) targets = ['Piernas', 'Pecho', 'Espalda'];
  List<String> dayParts;
  if (targets.length <= n) {
    dayParts = [targets[idx % targets.length]];
    if (p.routineMinutes >= 45 && targets.length > 1) dayParts.add(targets[(idx + 1) % targets.length]);
  } else {
    dayParts = [for (var i = 0; i < targets.length; i++) if (i % n == idx % n) targets[i]];
  }

  final m = p.routineMinutes;
  final w = p.watch.data;
  final low = w != null && w.sleepHours > 0 && w.sleepHours < 6 && w.date == todayKey() && day == todayKey();
  final abd = (p.parts['Abdomen'] ?? 'no') != 'no' ? p.parts['Abdomen'] : null;
  final doAbs = abd != null && (n <= 3 || idx % 2 == 0);
  final lose = !kid && (p.parts.values.contains('disminuir') || p.dietGoal == 'perder');
  final warmM = m >= 40 ? 7 : 5, coolM = 4, absM = doAbs ? (m >= 45 ? 8 : 6) : 0;
  final finM = (lose && m >= 35) ? (m >= 60 ? 12 : 8) : (kid ? 4 : 0);
  final mainM = max(8, m - warmM - coolM - absM - finM);
  String gp(String x) => p.parts[x] ?? 'tonificar';
  final per = kid ? 4.0 : dayParts.map((x) => {'masa': 6.0, 'tonificar': 4.5, 'disminuir': 4.0}[gp(x)] ?? 5.0).reduce((a, b) => a + b) / dayParts.length;
  final count = (mainM / per).round().clamp(2, 9);
  final used = <String>{};
  final blocks = <RoutineBlock>[];

  final wpool = Catalog.exercises.where((e) => e.lib == 'cardio' && e.flag == 'w' && ok(e)).toList();
  final warm = [..._pick(wpool, 1, rng, used, (e) => e.eq != 'ninguno'), ..._pick(wpool, 1, rng, used, (e) => e.eq == 'ninguno')];
  blocks.add(RoutineBlock('Calentamiento', warmM, warm.map((e) => RoutineItem(e, prescription(e, null, kid, low, 'warm'))).toList()));

  final main = <RoutineItem>[];
  final cnt = <String, int>{};
  for (var i = 0; i < count; i++) {
    final part = dayParts[i % dayParts.length];
    cnt[part] = (cnt[part] ?? 0) + 1;
    final ps = part == 'Brazos' ? [cnt[part]! % 2 == 1 ? 'Bíceps' : 'Tríceps'] : [part];
    final g = gp(part);
    final pool = Catalog.exercises.where((e) => const ['mancuernas', 'barra', 'corporal', 'maquinas'].contains(e.lib) && ps.contains(e.part) && ok(e)).toList();
    bool Function(Exercise)? pref;
    if (kid) {
      pref = (e) => e.lib == 'corporal' || e.lib == 'mancuernas';
    } else if (g == 'masa') {
      pref = (e) => e.lib != 'corporal';
    } else if (g == 'disminuir') {
      pref = (e) => e.lib == 'corporal' || e.eq == 'kettlebell' || e.eq == 'bandas';
    }
    var got = _pick(pool, 1, rng, used, (e) => (pref == null || pref(e)) && e.hasImage);
    if (got.isEmpty) got = _pick(pool, 1, rng, used, pref);
    if (got.isNotEmpty) main.add(RoutineItem(got.first, prescription(got.first, g, kid, low, 'main')));
  }
  blocks.add(RoutineBlock(kid ? 'Misión principal' : 'Bloque principal', mainM, main, dayParts.map(t).join(' · ')));

  if (doAbs) {
    final ap = Catalog.exercises.where((e) => (e.lib == 'abd' || e.part == 'Abdomen') && ok(e)).toList();
    final ai = _pick(ap, m >= 45 ? 3 : 2, rng, used, (e) => e.eq != 'ninguno');
    blocks.add(RoutineBlock('Abdomen', absM, ai.map((e) => RoutineItem(e, prescription(e, abd, kid, low, 'main'))).toList()));
  }
  if (finM > 0) {
    final fp = Catalog.exercises.where((e) => e.lib == 'cardio' && e.flag == 'q' && ok(e) && (!kid || e.level < 2)).toList();
    final fi = _pick(fp, 1, rng, used, (e) => e.eq != 'ninguno');
    blocks.add(RoutineBlock(kid ? 'Juego de energía' : 'Quema de grasa', finM, fi.map((e) => RoutineItem(e, prescription(e, null, kid, low, 'fin'))).toList()));
  }
  final cp = Catalog.exercises.where((e) => e.part == 'Estiramiento').toList();
  blocks.add(RoutineBlock('Estiramiento', coolM, _pick(cp, 3, rng, used).map((e) => RoutineItem(e, prescription(e, null, kid, low, 'cool'))).toList()));
  return Routine(blocks, dayParts, m, low);
}

List<Sport> sportsOn(Profile p, int wd) => p.sports.where((s) => s.days.contains(wd)).toList();

// ------------------------------------------------------------------
// Dieta
// ------------------------------------------------------------------
class Targets {
  final int kcal, protein;
  Targets(this.kcal, this.protein);
}

Targets targetsFor(Profile p) {
  final w = p.weight > 0 ? p.weight : 70.0, h = p.height > 0 ? p.height : 170, a = p.age > 0 ? p.age : 30;
  final wk = p.sports.fold<int>(0, (s, x) => s + x.minutes * x.days.length) + p.routineMinutes * p.routineDays.length;
  final act = min(1.8, 1.3 + wk / 1500 * .3);
  if (p.isKid) return Targets(((1000 + a * 100) * act / 1.4 / 10).round() * 10, w.round());
  final bmr = 10 * w + 6.25 * h - 5 * a + (p.sex == 'f' ? -161 : 5);
  final tdee = bmr * act;
  final adj = {'perder': -450, 'mantener': 0, 'ganar': 400, 'masa': 250}[p.dietGoal] ?? 0;
  final kcal = (max(bmr * 1.05, tdee + adj) / 10).round() * 10;
  final pk = {'perder': 1.6, 'mantener': 1.2, 'ganar': 1.5, 'masa': 1.8}[p.dietGoal] ?? 1.2;
  return Targets(kcal, (w * pk).round());
}

List<String> slotsFor(Profile p) => p.mealsPerDay <= 3
    ? ['desayuno', 'almuerzo', 'cena']
    : p.mealsPerDay == 4
        ? ['desayuno', 'almuerzo', 'onces', 'cena']
        : ['desayuno', 'media', 'almuerzo', 'onces', 'cena'];

List<Food> foodCandidates(Profile p, String slot, {bool all = false}) {
  final tag = {'perder': 'p', 'ganar': 'g', 'masa': 'm'}[p.dietGoal];
  final base = Catalog.foods.where((f) => f.slot == slotType[slot] && !(p.isKid && f.has('x'))).toList();
  if (all) return base;
  final tt = p.isKid ? base.where((f) => f.has('k')).toList() : tag != null ? base.where((f) => f.has(tag)).toList() : base;
  return tt.isNotEmpty ? tt : base;
}

Place placeOf(Profile p) => Catalog.places[p.place] ?? Catalog.places['mzl']!;
Store storeOf(Profile p) {
  final pl = placeOf(p);
  return pl.stores.where((s) => s.name == p.store).firstOrNull ?? pl.byDistance.first;
}

class MenuItem {
  final String slot;
  final Food food;
  MenuItem(this.slot, this.food);
}

class DayMenu {
  final List<MenuItem> items;
  final Targets targets;
  final double factor, mult, costCop;
  final int kcal, protein, carbs, fat;
  final Store store;
  DayMenu(this.items, this.targets, this.factor, this.mult, this.costCop, this.kcal, this.protein, this.carbs, this.fat, this.store);
}

DayMenu dayMenu(Profile p, String day, Map<String, String> chosen) {
  final items = slotsFor(p).map((s) {
    var id = chosen[s];
    if (id == null || !Catalog.foodById.containsKey(id)) {
      final c = foodCandidates(p, s);
      id = c[strHash(day + s + p.email) % c.length].id;
    }
    return MenuItem(s, Catalog.foodById[id]!);
  }).toList();
  final tg = targetsFor(p);
  final sumK = items.fold<int>(0, (a, x) => a + x.food.kcal);
  final fac = ((tg.kcal / sumK * 20).round() / 20).clamp(.7, 1.6).toDouble();
  final st = storeOf(p);
  double sum(int Function(Food) f) => items.fold<double>(0, (a, x) => a + f(x.food) * fac);
  return DayMenu(items, tg, fac, st.priceFactor, items.fold<double>(0, (a, x) => a + x.food.costCop * st.priceFactor * fac),
      (sumK * fac).round(), sum((f) => f.protein).round(), sum((f) => f.carbs).round(), sum((f) => f.fat).round(), st);
}

/// Convierte un costo base (en pesos colombianos) a la moneda local y lo formatea.
String money(double cop, Profile p) {
  final pl = placeOf(p);
  final v = cop * pl.rate;
  final isCop = pl.currency == 'COP';
  final val = isCop ? (v / 100).round() * 100.0 : v;
  return NumberFormatCache.currency(pl.currency, isCop ? 0 : 2).format(val);
}

class NumberFormatCache {
  static final _c = <String, dynamic>{};
  static dynamic currency(String cur, int digits) =>
      _c['${I18n.locale}$cur$digits'] ??= _CurrencyFmt(cur, digits);
}

class _CurrencyFmt {
  final String cur;
  final int digits;
  _CurrencyFmt(this.cur, this.digits);
  String format(double v) {
    final sym = {'COP': '\$', 'MXN': '\$', 'USD': 'US\$', 'EUR': '€', 'BRL': 'R\$'}[cur] ?? cur;
    final s = I18n.num(double.parse(v.toStringAsFixed(digits)));
    return cur == 'EUR' ? '$s $sym' : '$sym $s';
  }
}

// ------------------------------------------------------------------
// Reloj: entrenamientos detectados (simulados hasta conectar el reloj real)
// ------------------------------------------------------------------
const _wtypes = ['Caminata', 'Ciclismo', 'Running', 'Fútbol', 'Natación', 'Baile', 'Gimnasio', 'Patinaje'];
List<OtherActivity> simulatedWorkouts(Profile p, String day) {
  if (!p.watch.linked) return [];
  final h = strHash(day + p.email + (p.watch.model ?? ''));
  final n = 1 + h % 2;
  return List.generate(n, (i) {
    final ty = _wtypes[(h >> (i * 4)) % _wtypes.length];
    final mins = 25 + ((h >> (i * 3 + 5)) % 50);
    final hr = 105 + ((h >> (i * 2 + 9)) % 45);
    return OtherActivity(name: ty, minutes: mins, avgHr: hr, kcal: (mins * (hr - 60) / 8).round(), intensity: hr > 140 ? 'Alta' : hr > 120 ? 'Media' : 'Baja', source: p.watch.model ?? '');
  });
}

String? routeFor(WatchBrand w, String os) {
  if (w.brand == 'Apple' && os != 'ios') return null;
  return w.routes.where((r) => r == 'api' || (os == 'ios' ? r == 'hk' : r == 'hc')).firstOrNull;
}
