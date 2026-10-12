import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../core/catalog.dart';
import '../core/engine.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../services/health_service.dart';
import '../services/location_service.dart';
import '../widgets/ui.dart';

Future<void> openYoutube(String q) => launchUrl(Uri.parse('https://www.youtube.com/results?search_query=${Uri.encodeComponent(q)}'), mode: LaunchMode.externalApplication);

// ---------------------------------------------------------------- ejercicio
class ExerciseSheet extends StatefulWidget {
  final Exercise ex;
  final String rx;
  const ExerciseSheet(this.ex, {super.key, this.rx = ''});
  @override
  State<ExerciseSheet> createState() => _ExerciseSheetState();
}

class _ExerciseSheetState extends State<ExerciseSheet> {
  int frame = 0;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    if (widget.ex.hasImage) timer = Timer.periodic(const Duration(milliseconds: 1100), (_) => setState(() => frame = 1 - frame));
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.ex;
    final p = Palette.of(context);
    return vgap([
      AspectRatio(
        aspectRatio: 3 / 2,
        child: Stack(fit: StackFit.expand, children: [
          AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: ExerciseImage(e, key: ValueKey(frame), frame: frame, radius: 18)),
          if (e.hasImage) Positioned(left: 10, bottom: 10, child: Pill(t('Inicio y final del movimiento'), color: p.acc2)),
        ]),
      ),
      Eyebrow('${t(libraries[e.lib]!)} · ${t(e.part)}'),
      Text(up(context, e.name), style: display(context, 30)),
      Wrap(spacing: 6, runSpacing: 6, children: [
        Pill(t(equipment[e.eq]!)),
        Pill(t(levels[e.level]), color: p.acc2),
        if (widget.rx.isNotEmpty) Pill(widget.rx, color: p.ok),
      ]),
      Text(t(e.part == 'Estiramiento' ? tips['stretch']! : tips[e.lib]!)),
      Btn(t('Ver técnica en YouTube'), kind: BtnKind.primary, icon: Icons.play_arrow_rounded, expand: true, onTap: () => openYoutube('${e.en} exercise proper form')),
    ], 14);
  }
}

// ---------------------------------------------------------------- receta
class FoodSheet extends StatelessWidget {
  final Food f;
  const FoodSheet(this.f, {super.key});
  @override
  Widget build(BuildContext context) {
    final prof = context.read<AppState>().profile!;
    final pl = placeOf(prof);
    final p = Palette.of(context);
    final slot = {'desayuno': 'Desayuno', 'snack': 'Media mañana o merienda', 'almuerzo': 'Almuerzo', 'cena': 'Cena'}[f.slot]!;
    return vgap([
      Row(children: [
        Plate(f.emoji),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Eyebrow('${t(slot)} · ${f.minutes} min'), Text(up(context, f.name), style: display(context, 26))])),
      ]),
      statRow([StatTile('${f.kcal}', 'kcal'), StatTile('${f.protein} g', t('Proteína')), StatTile('${f.carbs} g', t('Carbohidratos')), StatTile('${f.fat} g', t('Grasa'))]),
      Wrap(spacing: 6, runSpacing: 6, children: [
        if (f.has('p')) Pill(t('Bajar de peso'), color: p.acc2),
        if (f.has('m')) Pill(t('Ganar masa muscular'), color: p.acc2),
        if (f.has('g')) Pill(t('Subir de peso'), color: p.acc2),
        if (f.has('v')) Pill(t('Vegetariano'), color: p.ok),
      ]),
      if (I18n.lang != 'es') Text(t('Los ingredientes y pasos se traducirán en la versión final.'), style: TextStyle(color: p.muted, fontSize: 12)),
      Text(t('Ingredientes (1 porción)'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ...f.ingredients.map((i) => Text('•  $i')),
      Text(t('Preparación'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ...f.steps.asMap().entries.map((s) => Text('${s.key + 1}. ${s.value}')),
      Text('${t('Costo por porción cerca de ti')} · ${pl.city}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ...pl.byDistance.map((s) => Row(children: [
            Expanded(child: Text(s.name)),
            Text('${I18n.fmt(s.km)} km', style: TextStyle(color: p.muted)),
            const SizedBox(width: 16),
            SizedBox(width: 110, child: Text(money(f.costCop * s.priceFactor, prof), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
          ])),
      Text(t('Precios estimados para validar el diseño.'), style: TextStyle(color: p.muted, fontSize: 12)),
      Btn(t('Ver preparación en YouTube'), icon: Icons.play_arrow_rounded, expand: true, onTap: () => openYoutube('${f.en} recipe')),
    ], 12);
  }
}

// ---------------------------------------------------------------- cambiar plato
class SwapSheet extends StatefulWidget {
  final String slot;
  const SwapSheet(this.slot, {super.key});
  @override
  State<SwapSheet> createState() => _SwapSheetState();
}

class _SwapSheetState extends State<SwapSheet> {
  String sort = 'precio';
  bool veg = false, all = false;
  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final prof = st.profile!;
    final p = Palette.of(context);
    final menu = dayMenu(prof, st.selected, st.log(st.selected).meals);
    final cur = menu.items.firstWhere((i) => i.slot == widget.slot).food;
    var list = foodCandidates(prof, widget.slot, all: all);
    if (veg) list = list.where((f) => f.has('v')).toList();
    final key = {'precio': (Food f) => f.costCop, 'proteina': (Food f) => -f.protein, 'kcal': (Food f) => f.kcal}[sort]!;
    list.sort((a, b) => key(a).compareTo(key(b)));
    final rest = menu.costCop - cur.costCop * menu.mult * menu.factor;
    return vgap([
      Eyebrow('${t(slotNames[widget.slot]!)} · ${I18n.dateLong(dparse(st.selected))}'),
      Text(up(context, t('Cambiar plato')), style: display(context, 28)),
      Text(t('Precios en {s}', {'s': menu.store.name}), style: TextStyle(color: p.muted, fontSize: 12)),
      Segmented(options: [('precio', t('Más barato')), ('proteina', t('Más proteína')), ('kcal', t('Menos calorías'))], value: sort, onChanged: (v) => setState(() => sort = v)),
      Wrap(spacing: 8, children: [ChoiceChipX(t('Vegetariano'), veg, () => setState(() => veg = !veg)), ChoiceChipX(t('Incluir otros objetivos'), all, () => setState(() => all = !all))]),
      ...list.map((f) {
        final cost = f.costCop * menu.mult * menu.factor;
        final over = rest + cost > prof.budgetCop;
        return Box(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Plate(f.emoji, size: 54),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => showSheet(context, (_) => FoodSheet(f)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${(f.kcal * menu.factor).round()} kcal · ${(f.protein * menu.factor).round()} g ${t('prot')} · ${money(cost, prof)}', style: TextStyle(color: p.muted, fontSize: 12)),
                  if (over) Padding(padding: const EdgeInsets.only(top: 4), child: Pill(t('supera presupuesto'), color: p.bad)),
                ]),
              ),
            ),
            f.id == cur.id
                ? Pill(t('Actual'), color: p.ok)
                : Btn(t('Elegir'), kind: BtnKind.primary, onTap: () {
                    st.update(() => st.log(st.selected).meals[widget.slot] = f.id);
                    Navigator.pop(context);
                  }),
          ]),
        );
      }),
    ], 10);
  }
}

// ---------------------------------------------------------------- reloj
class WatchPicker extends StatefulWidget {
  /// Perfil donde se guarda el reloj (el perfil real o el borrador del registro).
  final Profile target;
  final VoidCallback onLinked;
  const WatchPicker({super.key, required this.target, required this.onLinked});
  @override
  State<WatchPicker> createState() => _WatchPickerState();
}

class _WatchPickerState extends State<WatchPicker> {
  late String os = Platform.isIOS ? 'ios' : 'android';
  String? brand, model;
  bool busy = false;
  String? error;

  Future<void> connect(WatchBrand w, String route) async {
    setState(() {
      busy = true;
      error = null;
    });
    final tg = widget.target;
    WatchData? data;
    if (route == 'hc' || route == 'hk') {
      if (route == 'hc' && !await HealthService.available()) {
        await HealthService.installHealthConnect();
        setState(() {
          busy = false;
          error = t('Instala Health Connect desde Google Play y vuelve a intentarlo.');
        });
        return;
      }
      final ok = await HealthService.requestPermissions();
      if (!ok) {
        setState(() {
          busy = false;
          error = t('No se otorgaron los permisos. Puedes intentarlo de nuevo o ingresar tus datos a mano.');
        });
        return;
      }
      data = await HealthService.today(model!);
    }
    tg.watch = WatchLink(route: route, brand: w.brand, model: model, os: os, data: data ?? WatchData(source: model!));
    widget.onLinked();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final children = <Widget>[
      Segmented(options: [('android', '${t('Celular')} Android'), ('ios', '${t('Celular')} iPhone')], value: os, onChanged: (v) => setState(() => os = v)),
    ];
    if (brand == null) {
      children.addAll([
        Text(t('Elige la marca de tu reloj o banda.'), style: TextStyle(color: p.muted)),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.05,
          children: [
            for (final w in Catalog.watches)
              InkWell(
                onTap: () => setState(() => brand = w.brand),
                child: Box(
                  padding: const EdgeInsets.all(8),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 44, height: 44, alignment: Alignment.center, decoration: BoxDecoration(color: w.color, borderRadius: BorderRadius.circular(13)), child: Text(w.brand == 'Otra marca' ? '+' : w.brand.substring(0, 2).toUpperCase(), style: display(context, 17, color: Colors.white))),
                    const SizedBox(height: 7),
                    Text(t(w.brand), textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
          ],
        ),
        Text(t('El catálogo de marcas y modelos se actualiza desde el servidor sin publicar una nueva versión de la app.'), style: TextStyle(color: p.muted, fontSize: 12)),
      ]);
    } else {
      final w = Catalog.brand(brand)!;
      final app = w.app.isEmpty ? t('App de tu reloj') : w.app;
      if (model == null) {
        children.addAll([
          Align(alignment: Alignment.centerLeft, child: Btn('‹ ${t('Marcas')}', kind: BtnKind.ghost, onTap: () => setState(() => brand = null))),
          for (final m in w.models)
            InkWell(
              onTap: () => setState(() => model = m),
              child: Box(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  Container(width: 38, height: 38, decoration: BoxDecoration(color: w.color, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.watch_rounded, color: Colors.white, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t(m), style: const TextStyle(fontWeight: FontWeight.w700)), Text(app, style: TextStyle(color: p.muted, fontSize: 12))])),
                  const Icon(Icons.chevron_right_rounded),
                ]),
              ),
            ),
        ]);
      } else {
        final route = routeFor(w, os);
        children.addAll([
          Align(alignment: Alignment.centerLeft, child: Btn('‹ ${t('Modelos')}', kind: BtnKind.ghost, onTap: () => setState(() => model = null))),
          Box(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: w.color, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.watch_rounded, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t(model!), style: const TextStyle(fontWeight: FontWeight.w800)), Text('$app${route != null ? ' · ${t(routeNames[route]!)}' : ''}', style: TextStyle(color: p.muted, fontSize: 12))])),
            ]),
          ),
        ]);
        if (route == null) {
          children.add(Box(color: p.acc2.withValues(alpha: .12), child: Text(t('Este reloj solo funciona con iPhone. Cambia a "Celular iPhone" o ingresa tus datos a mano.'))));
        } else {
          final step2 = {
            'hc': t('En {a}, activa la sincronización con Health Connect.', {'a': app}),
            'hk': t('En {a}, activa la opción de compartir datos con Apple Salud.', {'a': app}),
            'api': t('Inicia sesión con tu cuenta de {a} para autorizar a Coachless.', {'a': app}),
          }[route]!;
          final steps = [t('Abre {a} y verifica que tu reloj esté sincronizado.', {'a': app}), step2, t('Acepta los permisos de pasos, pulso, calorías, sueño y entrenamientos.')];
          children.addAll([
            for (var i = 0; i < steps.length; i++)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(radius: 14, backgroundColor: p.acc, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                const SizedBox(width: 12),
                Expanded(child: Text(steps[i])),
              ]),
            Wrap(spacing: 6, runSpacing: 6, children: ['Pasos', 'Pulso', 'Calorías', 'Sueño', 'Entrenamientos'].map((x) => Pill(t(x), color: p.ok)).toList()),
            if (error != null) Text(error!, style: TextStyle(color: p.bad)),
            if (route == 'api') Text(t('La conexión directa con la cuenta del fabricante se activa en la siguiente fase. Por ahora quedará registrado tu reloj.'), style: TextStyle(color: p.muted, fontSize: 12)),
            Btn(busy ? t('Conectando…') : t('Conectar {m}', {'m': t(model!)}), kind: BtnKind.primary, expand: true, onTap: busy ? null : () => connect(w, route)),
          ]);
        }
      }
    }
    return vgap(children, 10);
  }
}

class WatchSheet extends StatelessWidget {
  const WatchSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    return vgap([
      Text(up(context, t('Vincular reloj o banda')), style: display(context, 28)),
      WatchPicker(target: st.profile!, onLinked: () {
        st.update();
        Navigator.pop(context);
      }),
    ]);
  }
}

// ---------------------------------------------------------------- datos manuales
class ManualDataSheet extends StatefulWidget {
  const ManualDataSheet({super.key});
  @override
  State<ManualDataSheet> createState() => _ManualDataSheetState();
}

class _ManualDataSheetState extends State<ManualDataSheet> {
  late final WatchData d;
  @override
  void initState() {
    super.initState();
    final w = context.read<AppState>().profile!.watch.data;
    d = WatchData(steps: w?.steps ?? 0, restingHr: w?.restingHr ?? 65, activeKcal: w?.activeKcal ?? 0, sleepHours: w?.sleepHours ?? 7);
  }

  Widget field(String label, num value, ValueChanged<String> on) => Expanded(
        child: TextFormField(initialValue: '$value', keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: label), onChanged: on),
      );

  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    return vgap([
      Text(up(context, t('Datos de hoy')), style: display(context, 28)),
      Text(t('Útil si no tienes reloj o quieres corregir un dato.')),
      Row(children: [field(t('Pasos'), d.steps, (v) => d.steps = int.tryParse(v) ?? 0), const SizedBox(width: 10), field(t('Pulso reposo'), d.restingHr, (v) => d.restingHr = int.tryParse(v) ?? 0)]),
      Row(children: [field(t('kcal activas'), d.activeKcal, (v) => d.activeKcal = int.tryParse(v) ?? 0), const SizedBox(width: 10), field(t('Horas de sueño'), d.sleepHours, (v) => d.sleepHours = double.tryParse(v.replaceAll(',', '.')) ?? 0)]),
      Btn(t('Guardar'), kind: BtnKind.primary, expand: true, onTap: () {
        final w = st.profile!.watch;
        d.source = w.linked ? (w.model ?? '') : 'Ingreso manual';
        st.update(() => w.data = d);
        Navigator.pop(context);
      }),
    ], 14);
  }
}

// ---------------------------------------------------------------- otra actividad
class OtherActivitySheet extends StatefulWidget {
  const OtherActivitySheet({super.key});
  @override
  State<OtherActivitySheet> createState() => _OtherActivitySheetState();
}

class _OtherActivitySheetState extends State<OtherActivitySheet> {
  String name = 'Caminata', intensity = 'Media';
  int minutes = 45;
  List<OtherActivity>? detected;

  @override
  void initState() {
    super.initState();
    final st = context.read<AppState>();
    final sp = sportsOn(st.profile!, weekdayOf(st.selected));
    if (sp.isNotEmpty) name = sp.first.name;
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    final st = context.read<AppState>();
    final w = st.profile!.watch;
    if (!w.linked) return setState(() => detected = []);
    List<OtherActivity> list = [];
    if (w.route == 'hc' || w.route == 'hk') list = await HealthService.workouts(dparse(st.selected), w.model ?? '');
    if (list.isEmpty && w.route == 'api') list = simulatedWorkouts(st.profile!, st.selected);
    if (mounted) setState(() => detected = list);
  }

  void save(OtherActivity a) {
    final st = context.read<AppState>();
    st.update(() {
      final l = st.log(st.selected);
      l.other = a;
      l.skip = null;
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    final p = Palette.of(context);
    final linked = st.profile!.watch.linked;
    return vgap([
      Eyebrow(I18n.dateLong(dparse(st.selected))),
      Text(up(context, t('Hice otra actividad')), style: display(context, 28)),
      Text(t('Registra lo que hiciste en lugar de la rutina. Cuenta como día cumplido.'), style: TextStyle(color: p.muted)),
      Text(t('Detectado por tu reloj'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      if (!linked)
        Box(child: Row(children: [
          Expanded(child: Text(t('Vincula tu reloj para traer la actividad automáticamente.'))),
          Btn(t('Elegir mi reloj'), onTap: () {
            Navigator.pop(context);
            showSheet(context, (_) => const WatchSheet());
          }),
        ]))
      else if (detected == null)
        const Center(child: CircularProgressIndicator())
      else if (detected!.isEmpty)
        Text(t('Tu reloj no registró entrenamientos hoy.'), style: TextStyle(color: p.muted))
      else
        ...detected!.map((w) => Box(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Icon(Icons.favorite_rounded, color: p.acc),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t(w.name), style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${w.minutes} min · ${w.kcal} kcal${w.avgHr != null ? ' · ${t('pulso medio')} ${w.avgHr}' : ''} · ${w.source}', style: TextStyle(color: p.muted, fontSize: 12)),
                ])),
                Btn(t('Usar'), kind: BtnKind.primary, onTap: () => save(w)),
              ]),
            )),
      Box(
        child: vgap([
          Text(t('O ingrésala a mano'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          DropdownButtonFormField<String>(
            value: {...sports, 'Caminata', 'Gimnasio'}.contains(name) ? name : 'Caminata',
            decoration: InputDecoration(labelText: t('Actividad')),
            items: {...sports, 'Caminata', 'Gimnasio'}.map((s) => DropdownMenuItem(value: s, child: Text(t(s)))).toList(),
            onChanged: (v) => setState(() => name = v!),
          ),
          Row(children: [
            Expanded(child: TextFormField(initialValue: '$minutes', keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('Minutos')), onChanged: (v) => minutes = int.tryParse(v) ?? 30)),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: intensity,
                decoration: InputDecoration(labelText: t('Intensidad')),
                items: intensities.map((s) => DropdownMenuItem(value: s, child: Text(t(s)))).toList(),
                onChanged: (v) => setState(() => intensity = v!),
              ),
            ),
          ]),
          Btn(t('Guardar actividad'), kind: BtnKind.primary, expand: true, onTap: () => save(OtherActivity(name: name, minutes: minutes, intensity: intensity, kcal: (minutes * ({'Baja': 4, 'Media': 7, 'Alta': 10}[intensity] ?? 6)).round()))),
        ]),
      ),
    ], 12);
  }
}

// ---------------------------------------------------------------- no hice la rutina
class SkipSheet extends StatefulWidget {
  const SkipSheet({super.key});
  @override
  State<SkipSheet> createState() => _SkipSheetState();
}

class _SkipSheetState extends State<SkipSheet> {
  String? reason;
  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    final p = Palette.of(context);
    return vgap([
      Eyebrow(I18n.dateLong(dparse(st.selected))),
      Text(up(context, t('No hice la rutina')), style: display(context, 28)),
      Text(t('Cuéntanos por qué. Así ajustamos tu plan sin castigarte.'), style: TextStyle(color: p.muted)),
      Wrap(spacing: 8, runSpacing: 8, children: skipReasons.map((r) => ChoiceChipX(t(r), reason == r, () => setState(() => reason = r))).toList()),
      if (st.profile!.isKid) Box(color: p.acc2.withValues(alpha: .12), child: Text('${t('¡No pasa nada! Mañana ganamos más estrellas.')} ⭐')),
      Btn(t('Registrar'), kind: BtnKind.primary, expand: true, onTap: reason == null
          ? null
          : () {
              st.update(() {
                final l = st.log(st.selected);
                l.skip = reason;
                l.complete = false;
              });
              Navigator.pop(context);
            }),
    ], 14);
  }
}

// ---------------------------------------------------------------- revisión mensual
class MonthlySheet extends StatefulWidget {
  const MonthlySheet({super.key});
  @override
  State<MonthlySheet> createState() => _MonthlySheetState();
}

class _MonthlySheetState extends State<MonthlySheet> {
  late double weight;
  late int minutes;
  late List<int> days;
  late List<String> eq;
  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().profile!;
    weight = p.weight;
    minutes = p.routineMinutes;
    days = [...p.routineDays];
    eq = [...p.equipment];
  }

  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    final p = Palette.of(context);
    return vgap([
      Eyebrow(t('Revisión mensual')),
      Text(up(context, t('¿Qué cambió este mes?')), style: display(context, 28)),
      TextFormField(initialValue: '$weight', keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: '${t('Peso actual')} (kg)'), onChanged: (v) => weight = double.tryParse(v.replaceAll(',', '.')) ?? weight),
      Text(t('Minutos por rutina'), style: TextStyle(color: p.muted)),
      Segmented(options: [for (final m in [20, 30, 40, 50, 60, 75, 90]) (m, '$m')], value: minutes, onChanged: (v) => setState(() => minutes = v)),
      Text(t('Días de rutina'), style: TextStyle(color: p.muted)),
      Wrap(spacing: 8, runSpacing: 8, children: [for (var d = 0; d < 7; d++) ChoiceChipX(I18n.dayName(d, short: true), days.contains(d), () => setState(() => days.contains(d) ? days.remove(d) : days.add(d)))]),
      Text(t('¿Compraste equipos nuevos?'), style: TextStyle(color: p.muted)),
      Wrap(spacing: 8, runSpacing: 8, children: equipment.entries.where((e) => e.key != 'ninguno').map((e) => ChoiceChipX(t(e.value), eq.contains(e.key), () => setState(() => eq.contains(e.key) ? eq.remove(e.key) : eq.add(e.key)))).toList()),
      Btn(t('Guardar y ajustar mi plan'), kind: BtnKind.primary, expand: true, onTap: () {
        st.update(() {
          final pr = st.profile!;
          pr.weight = weight;
          pr.weights.add(WeightEntry(todayKey(), weight));
          pr.routineMinutes = minutes;
          pr.routineDays = days..sort();
          pr.equipment = eq;
          pr.lastCheck = todayKey();
        });
        Navigator.pop(context);
      }),
    ], 12);
  }
}

// ---------------------------------------------------------------- idioma
class LanguageSheet extends StatelessWidget {
  final ValueChanged<String> onPick;
  const LanguageSheet({super.key, required this.onPick});
  @override
  Widget build(BuildContext context) => vgap([
        Text(up(context, t('Idioma')), style: display(context, 28)),
        for (final e in I18n.langs.entries)
          Btn(e.value.$1, kind: I18n.lang == e.key ? BtnKind.primary : BtnKind.normal, expand: true, onTap: () {
            onPick(e.key);
            Navigator.pop(context);
          }),
        Text(t('La app final incluirá más idiomas y la traducción completa de recetas.'), style: TextStyle(color: Palette.of(context).muted, fontSize: 12)),
      ], 10);
}

// ---------------------------------------------------------------- ubicación
class LocationPicker extends StatefulWidget {
  final Profile target;
  final VoidCallback onChanged;
  const LocationPicker({super.key, required this.target, required this.onChanged});
  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  bool busy = false;
  String? msg;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final tg = widget.target;
    return vgap([
      Text(t('Usamos tu ubicación para mostrar los supermercados más cercanos, la moneda local y el costo de cada receta.'), style: TextStyle(color: p.muted)),
      Btn(busy ? t('Buscando…') : t('Usar mi ubicación'), kind: BtnKind.primary, icon: Icons.place_rounded, expand: true, onTap: busy
          ? null
          : () async {
              setState(() => busy = true);
              final k = await LocationService.nearestPlace();
              setState(() {
                busy = false;
                if (k != null) {
                  tg.place = k;
                  tg.located = true;
                  tg.store = '';
                  msg = t('Ubicación detectada: {c}.', {'c': Catalog.places[k]!.city});
                } else {
                  msg = t('No pudimos obtener tu ubicación. Elige tu ciudad en la lista.');
                }
              });
              widget.onChanged();
            }),
      if (msg != null) Text(msg!),
      Text(t('O elige tu ciudad'), style: TextStyle(color: p.muted)),
      for (final pl in Catalog.places.values)
        InkWell(
          onTap: () {
            setState(() {
              tg.place = pl.key;
              tg.located = false;
              tg.store = '';
            });
            widget.onChanged();
          },
          child: Box(
            border: tg.place == pl.key ? p.acc : null,
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Icon(Icons.place_rounded, color: p.acc),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(pl.city, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${t(pl.country)} · ${pl.currency} · ${pl.stores.take(3).map((s) => s.name).join(', ')}', style: TextStyle(color: p.muted, fontSize: 12)),
              ])),
            ]),
          ),
        ),
    ], 10);
  }
}

class LocationSheet extends StatelessWidget {
  const LocationSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    return vgap([
      Text(up(context, t('Tu ubicación')), style: display(context, 28)),
      LocationPicker(target: st.profile!, onChanged: () => st.update()),
    ]);
  }
}
