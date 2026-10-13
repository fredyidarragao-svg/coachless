import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/catalog.dart';
import '../core/engine.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../widgets/ui.dart';
import 'sheets.dart';

const onboardingSteps = [
  ('cuenta', 'Bienvenido'),
  ('datos', 'Sobre ti'),
  ('medidas', 'Peso y estatura'),
  ('habitos', 'Tus hábitos'),
  ('deportes', 'Deportes que practicas'),
  ('rutina', 'Tu rutina'),
  ('objetivos', 'Qué quieres trabajar'),
  ('equipos', 'Equipos que tienes'),
  ('reloj', 'Tu reloj o banda'),
  ('ubicacion', 'Tu ubicación'),
  ('resumen', 'Todo listo'),
];

/// Registro completo (editStep == null) o edición de una sola sección desde el perfil.
class OnboardingScreen extends StatefulWidget {
  final String? editStep;
  const OnboardingScreen({super.key, this.editStep});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late Profile d;
  int step = 0;
  bool googleOk = false, signingIn = false;
  String? error;
  final emailCtrl = TextEditingController();

  bool get editing => widget.editStep != null;
  String get stepId => editing ? widget.editStep! : onboardingSteps[step].$1;

  @override
  void initState() {
    super.initState();
    final st = context.read<AppState>();
    d = st.profile?.copy() ?? Profile(lang: I18n.lang);
    googleOk = editing;
    emailCtrl.text = d.email;
  }

  void refresh() => setState(() => I18n.lang = d.lang);

  String? validate() {
    switch (stepId) {
      case 'cuenta':
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(d.email) || !googleOk) return t('Escribe un correo válido y toca "Continuar con Google".');
      case 'datos':
        if (d.sex.isEmpty || d.age <= 0) return t('Elige hombre o mujer y escribe tu edad.');
      case 'medidas':
        if (d.weight <= 0 || d.height <= 0) return t('Escribe tu peso y estatura.');
      case 'rutina':
        if (d.routineDays.isEmpty) return t('Elige al menos un día de rutina.');
    }
    return null;
  }

  void finish() {
    final st = context.read<AppState>();
    if (d.isKid) {
      d.dietGoal = 'crecer';
    } else if (d.dietGoal == 'crecer') {
      d.dietGoal = 'mantener';
    }
    final old = st.profile;
    if (old == null || old.weight != d.weight) d.weights.add(WeightEntry(todayKey(), d.weight));
    if (!editing) d.lastCheck = todayKey();
    st.setProfile(d);
    if (editing) Navigator.pop(context);
  }

  void next() {
    final e = validate();
    if (e != null) return setState(() => error = e);
    setState(() {
      error = null;
      if (editing || step == onboardingSteps.length - 1) {
        finish();
      } else {
        step++;
      }
    });
  }

  Future<void> google() async {
    setState(() => signingIn = true);
    var acc = await AuthService.signIn();
    if (acc == null && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(emailCtrl.text.trim())) acc = AuthService.fromEmail(emailCtrl.text.trim());
    setState(() {
      signingIn = false;
      if (acc == null) {
        error = t('Escribe un correo válido.');
      } else {
        d.email = acc.email;
        emailCtrl.text = acc.email;
        if (d.firstName.isEmpty) d.firstName = acc.firstName;
        if (d.lastName.isEmpty) d.lastName = acc.lastName;
        googleOk = true;
        error = null;
      }
    });
  }

  Widget numField(String label, num value, void Function(String) on, {bool decimal = false}) => TextFormField(
        initialValue: value > 0 ? (value is double && value == value.roundToDouble() ? value.toInt().toString() : '$value') : '',
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(labelText: label),
        onChanged: (v) => setState(() => on(v.replaceAll(',', '.'))),
      );

  Widget label(String s) => Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(s, style: TextStyle(color: Palette.of(tc).muted, fontWeight: FontWeight.w600)));

  Widget content() {
    final p = Palette.of(tc);
    final kid = d.isKid;
    switch (stepId) {
      case 'cuenta':
        return vgap([
          HeroBox(children: [
            Text('Coach', style: display(tc, 18, color: Colors.white70)).wrapWith(Text('less', style: display(tc, 18, color: p.acc2))),
            Text(up(tc, t('Tu propio entrenador, sin pagar uno')), style: display(tc, 34, color: Colors.white)),
          ]),
          if (kIsWeb)
            Box(
              color: p.acc2.withValues(alpha: .12),
              child: Text(defaultTargetPlatform == TargetPlatform.iOS
                  ? t('Instálala en tu iPhone: en Safari toca Compartir y luego "Agregar a pantalla de inicio".')
                  : t('Instálala en tu celular: en el menú del navegador toca "Agregar a pantalla principal" o "Instalar app".')),
            ),
          label(t('Idioma')),
          Segmented(options: [for (final e in I18n.langs.entries) (e.key, e.value.$1)], value: d.lang, onChanged: (v) {
            d.lang = v;
            refresh();
          }),
          TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: t('Correo de Gmail'), hintText: 'tunombre@gmail.com'), onChanged: (v) {
            d.email = v.trim();
            googleOk = false;
          }),
          Btn(signingIn ? '…' : t('Continuar con Google'), icon: Icons.g_mobiledata_rounded, expand: true, onTap: signingIn ? null : google),
          if (googleOk)
            Box(child: vgap([
              Eyebrow(t('Datos tomados de Google')),
              Row(children: [
                Expanded(child: TextFormField(initialValue: d.firstName, decoration: InputDecoration(labelText: t('Nombre')), onChanged: (v) => d.firstName = v)),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(initialValue: d.lastName, decoration: InputDecoration(labelText: t('Apellido')), onChanged: (v) => d.lastName = v)),
              ]),
            ])),
        ], 14);
      case 'datos':
        return vgap([
          Row(children: [
            for (final s in [('m', 'Hombre', Palette.male), ('f', 'Mujer', Palette.female)]) ...[
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => d.sex = s.$1),
                  child: Box(
                    border: d.sex == s.$1 ? p.acc : null,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [CircleAvatar(radius: 9, backgroundColor: s.$3.acc), const SizedBox(width: 4), CircleAvatar(radius: 9, backgroundColor: s.$3.deep)]),
                      const SizedBox(height: 8),
                      Text(up(tc, t(s.$2)), style: display(tc, 22)),
                    ]),
                  ),
                ),
              ),
              if (s.$1 == 'm') const SizedBox(width: 10),
            ],
          ]),
          numField('${t('Edad')} (${t('si no está en tu cuenta de Google')})', d.age, (v) => d.age = int.tryParse(v) ?? 0),
          if (kid) Box(color: p.acc2.withValues(alpha: .12), child: Text('${t('Menor de 15 años:')} ${t('activamos el modo niños, con rutinas de juego y peso corporal, y sin dietas para bajar de peso.')}')),
        ], 14);
      case 'medidas':
        final imc = d.weight > 0 && d.height > 0 ? d.weight / ((d.height / 100) * (d.height / 100)) : 0.0;
        return vgap([
          Row(children: [
            Expanded(child: numField('${t('Peso')} (kg)', d.weight, (v) => d.weight = double.tryParse(v) ?? 0, decimal: true)),
            const SizedBox(width: 10),
            Expanded(child: numField('${t('Estatura')} (cm)', d.height, (v) => d.height = int.tryParse(v) ?? 0)),
          ]),
          if (imc > 0 && !kid) Box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t('Índice de masa corporal'), style: TextStyle(color: p.muted)), Text(imc.toStringAsFixed(1), style: display(tc, 40))])),
        ], 14);
      case 'habitos':
        return vgap([
          Row(children: [
            Expanded(child: DropdownButtonFormField(value: d.sleep, decoration: InputDecoration(labelText: t('Horas de sueño')), items: ['5', '6', '7', '8+'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => d.sleep = v!)),
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField(value: d.water, decoration: InputDecoration(labelText: t('Vasos de agua al día')), items: ['2', '3', '4', '5', '6', '8', '10+'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => d.water = v!)),
          ]),
          label(t('Comidas al día')),
          Segmented(options: const [(3, '3'), (4, '4'), (5, '5')], value: d.mealsPerDay, onChanged: (v) => setState(() => d.mealsPerDay = v)),
          label(t('Marca lo que aplica para ti')),
          Wrap(spacing: 8, runSpacing: 8, children: habits.map((h) => ChoiceChipX(t(h), d.habits.contains(h), () => setState(() => d.habits.contains(h) ? d.habits.remove(h) : d.habits.add(h)))).toList()),
        ], 12);
      case 'deportes':
        return vgap([
          Text(t('Los días de deporte no generan rutina. Si ese día no lo haces, la app te da una rutina de reemplazo.'), style: TextStyle(color: p.muted)),
          for (var i = 0; i < d.sports.length; i++)
            Box(child: vgap([
              Row(children: [
                Expanded(child: DropdownButtonFormField(value: d.sports[i].name, decoration: InputDecoration(labelText: t('Deporte')), items: sports.map((s) => DropdownMenuItem(value: s, child: Text(t(s)))).toList(), onChanged: (v) => d.sports[i].name = v!)),
                IconButton(onPressed: () => setState(() => d.sports.removeAt(i)), icon: const Icon(Icons.delete_outline_rounded)),
              ]),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (var j = 0; j < 7; j++) ChoiceChipX(I18n.dayName(j, short: true), d.sports[i].days.contains(j), () => setState(() => d.sports[i].days.contains(j) ? d.sports[i].days.remove(j) : (d.sports[i].days..add(j)..sort()))),
              ]),
              Row(children: [
                Expanded(child: numField(t('Minutos por sesión'), d.sports[i].minutes, (v) => d.sports[i].minutes = int.tryParse(v) ?? 60)),
                const SizedBox(width: 10),
                Expanded(child: DropdownButtonFormField(value: d.sports[i].intensity, decoration: InputDecoration(labelText: t('Intensidad')), items: intensities.map((s) => DropdownMenuItem(value: s, child: Text(t(s)))).toList(), onChanged: (v) => d.sports[i].intensity = v!)),
              ]),
            ])),
          Btn('+ ${t('Agregar deporte')}', onTap: () => setState(() => d.sports.add(Sport()))),
        ]);
      case 'rutina':
        final clash = d.routineDays.where((x) => sportsOn(d, x).isNotEmpty).toList();
        return vgap([
          label(t('Minutos por rutina')),
          Segmented(options: [for (final m in [20, 30, 40, 50, 60, 75, 90]) (m, '$m')], value: d.routineMinutes, onChanged: (v) => setState(() => d.routineMinutes = v)),
          label(t('Días de rutina')),
          Wrap(spacing: 8, runSpacing: 8, children: [for (var j = 0; j < 7; j++) ChoiceChipX(I18n.dayName(j), d.routineDays.contains(j), () => setState(() => d.routineDays.contains(j) ? d.routineDays.remove(j) : (d.routineDays..add(j)..sort())))]),
          if (clash.isNotEmpty) Box(color: p.acc2.withValues(alpha: .12), child: Text(t('{d}: también tienes deporte. Ese día solo verás la rutina si marcas que no hiciste el deporte.', {'d': clash.map(I18n.dayName).join(', ')}))),
        ]);
      case 'objetivos':
        final g = kid ? kidGoals : goals;
        return vgap([
          for (final part in bodyParts)
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(t(part), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Segmented(options: [for (final e in g.entries) (e.key, t(e.value))], value: d.parts[part] ?? 'no', onChanged: (v) => setState(() => d.parts[part] = v)),
            ]),
          if (kid)
            Box(color: p.acc2.withValues(alpha: .12), child: Text('${t('Plan de alimentación')}: ${t('Crecer sano')} (${t('fijo para menores de 15 años')}).'))
          else ...[
            Text(t('Objetivo de la dieta'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Wrap(spacing: 8, runSpacing: 8, children: dietGoals.entries.map((e) => ChoiceChipX(t(e.value), d.dietGoal == e.key, () => setState(() => d.dietGoal = e.key))).toList()),
          ],
        ], 14);
      case 'equipos':
        return vgap([
          Text(t('Si no tienes nada, la app usa ejercicios con tu peso corporal.'), style: TextStyle(color: p.muted)),
          Wrap(spacing: 8, runSpacing: 8, children: equipment.entries.where((e) => e.key != 'ninguno').map((e) => ChoiceChipX(t(e.value), d.equipment.contains(e.key), () => setState(() => d.equipment.contains(e.key) ? d.equipment.remove(e.key) : d.equipment.add(e.key)))).toList()),
        ]);
      case 'reloj':
        return vgap([
          if (d.watch.linked) Box(border: p.ok, child: Text('${t('Conectado')}: ${d.watch.model}')),
          WatchPicker(target: d, onLinked: () => setState(() {})),
          Text(t('¿No tienes reloj? Puedes continuar y anotar tus datos a mano.'), style: TextStyle(color: p.muted)),
        ]);
      case 'ubicacion':
        return LocationPicker(target: d, onChanged: () => setState(() {}));
      default:
        final tg = targetsFor(d);
        return vgap([
          HeroBox(children: [
            Eyebrow(kid ? t('Modo niños') : t(d.sex == 'f' ? 'Mujer' : 'Hombre'), color: Colors.white),
            Text(up(tc, '${d.firstName} ${d.lastName}'), style: display(tc, 32, color: Colors.white)),
            Text('${d.age} ${t('años')} · ${d.weight} kg · ${d.height} cm'),
          ]),
          Box(child: vgap([
            Text(t('Rutina de {m} min los días {d}.', {'m': d.routineMinutes, 'd': d.routineDays.map(I18n.dayName).join(', ')})),
            Text(t('{a} deporte(s) y {b} equipo(s) registrados.', {'a': d.sports.length, 'b': d.equipment.length})),
            Text(t('Meta diaria estimada: {k} kcal y {p} g de proteína.', {'k': I18n.fmt(tg.kcal), 'p': tg.protein})),
            Text('📍 ${placeOf(d).city}'),
          ], 8)),
        ]);
    }
  }

  late BuildContext tc;

  @override
  Widget build(BuildContext context) {
    final title = onboardingSteps.firstWhere((s) => s.$1 == stepId).$2;
    return Theme(
      data: buildTheme(d.theme),
      child: Builder(builder: (context) {
        tc = context;
        final p = Palette.of(context);
        return Scaffold(
          backgroundColor: Palette.of(context).bg,
          appBar: editing ? AppBar(backgroundColor: Colors.transparent, title: Text(t(title))) : null,
          body: SafeArea(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 30), children: [
              if (!editing) ...[
                Row(children: [for (var i = 0; i < onboardingSteps.length; i++) Expanded(child: Container(height: 5, margin: const EdgeInsets.symmetric(horizontal: 2), decoration: BoxDecoration(color: i <= step ? Palette.of(context).acc : Palette.of(context).line, borderRadius: BorderRadius.circular(9))))]),
                const SizedBox(height: 10),
                Eyebrow(t('Paso {a} de {b}', {'a': step + 1, 'b': onboardingSteps.length})),
                const SizedBox(height: 6),
                if (stepId != 'cuenta') Text(up(context, t(title)), style: display(context, 32)),
                const SizedBox(height: 14),
              ],
              content(),
              const SizedBox(height: 18),
              if (error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(error!, style: TextStyle(color: p.bad))),
              Row(children: [
                if (!editing) Expanded(child: Btn(t('Atrás'), onTap: step == 0 ? null : () => setState(() => step--))),
                if (!editing) const SizedBox(width: 10),
                Expanded(child: Btn(editing ? t('Guardar') : stepId == 'resumen' ? t('Crear mi plan') : t('Continuar'), kind: BtnKind.primary, onTap: next)),
              ]),
            ]),
          ),
        );
      }),
    );
  }
}

extension _Wrap on Widget {
  Widget wrapWith(Widget other) => Row(mainAxisSize: MainAxisSize.min, children: [this, other]);
}
