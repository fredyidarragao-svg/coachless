import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/engine.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import 'sheets.dart';

const _kidPhrases = ['¡Hoy vas a ser un súper héroe!', '¡Cada ejercicio te da una estrella!', '¡Vamos, campeón, tú puedes!', '¡Tus piernas son de cohete!', '¡Más fuerte que ayer!'];
const _kidIcons = {'Calentamiento': '🚀', 'Misión principal': '💪', 'Abdomen': '🛡️', 'Juego de energía': '⚡', 'Estiramiento': '🧘'};

class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final pr = st.profile!;
    final p = Palette.of(context);
    final sel = st.selected, mon = addDays(sel, -weekdayOf(sel)), today = todayKey();
    return vgap([
      Row(children: [
        IconButton(onPressed: () => st.select(addDays(sel, -7)), icon: Icon(Icons.chevron_left_rounded, color: p.acc2)),
        Expanded(child: Text(I18n.dateLong(dparse(sel)), textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 13))),
        IconButton(onPressed: () => st.select(addDays(sel, 7)), icon: Icon(Icons.chevron_right_rounded, color: p.acc2)),
      ]),
      Row(children: [
        for (var i = 0; i < 7; i++)
          Expanded(child: Builder(builder: (_) {
            final dk = addDays(mon, i), on = dk == sel, l = st.peek(dk);
            final done = l?.isDone ?? false;
            final dot = done ? p.ok : (l?.skip != null ? p.bad : sportsOn(pr, i).isNotEmpty ? p.acc2 : pr.routineDays.contains(i) ? p.acc : p.line);
            return GestureDetector(
              onTap: () => st.select(dk),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: on ? p.acc : p.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: on || dk == today ? p.acc : p.line)),
                child: Column(children: [
                  Text(I18n.dayName(i, short: true).substring(0, 2).toUpperCase(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: on ? Colors.white : p.muted)),
                  Text('${dparse(dk).day}', style: display(context, 20, color: on ? Colors.white : p.fg)),
                  if (pr.isKid && done) const Text('⭐', style: TextStyle(fontSize: 9)) else Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: on && !done ? Colors.white70 : dot)),
                ]),
              ),
            );
          })),
      ]),
    ], 6);
  }
}

class TrainScreen extends StatelessWidget {
  const TrainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final pr = st.profile!;
    final p = Palette.of(context);
    final dk = st.selected, wd = weekdayOf(dk), today = todayKey();
    final future = dk.compareTo(today) > 0;
    final sp = sportsOn(pr, wd);
    final l = st.log(dk);
    final spTxt = sp.map((x) => '${t(x.name)} · ${x.minutes} min · ${t('intensidad')} ${t(x.intensity).toLowerCase()}').join('\n');
    final w = <Widget>[const WeekStrip()];

    if (daysBetween(pr.lastCheck, today) >= 30) {
      w.add(Box(border: p.acc2, child: vgap([
        Eyebrow(t('Revisión mensual')),
        Text(t('Actualiza tu peso, tiempo de rutina y equipos'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        Text(t('Han pasado {n} días desde tu último ajuste.', {'n': daysBetween(pr.lastCheck, today)}), style: TextStyle(color: p.muted)),
        Btn(t('Actualizar ahora'), kind: BtnKind.primary, onTap: () => showSheet(context, (_) => const MonthlySheet())),
      ], 8)));
    }
    if (dk == today) w.add(const _WatchStats());

    if (l.other != null) {
      w.add(_OtherCard(l.other!));
    } else if (l.skip != null) {
      w.add(Box(border: p.bad, child: vgap([
        Eyebrow(t('Rutina no realizada'), color: p.bad),
        Text('${t('Motivo')}: ${t(l.skip!)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        Text(t(l.skip == 'Dolor o molestia' ? 'Descansa esa zona. Si el dolor sigue, consulta a un profesional de la salud antes de entrenar.' : 'Lo tendremos en cuenta para ajustar tu semana. Mañana seguimos.'), style: TextStyle(color: p.muted)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Btn(t('Deshacer'), onTap: () => st.update(() => l.skip = null)),
          Btn(t('Hice otra actividad'), onTap: () => showSheet(context, (_) => const OtherActivitySheet())),
        ]),
      ], 8)));
    } else if (sp.isNotEmpty) {
      if (l.sport == 'si') {
        w.add(HeroBox(children: [
          Eyebrow(t('Día de deporte'), color: Colors.white),
          Text(up(context, t('Deporte registrado')), style: display(context, 34, color: Colors.white)),
          Text(spTxt),
          Text('${t('Hoy no se genera rutina: tu deporte cubre el entrenamiento.')}${pr.isKid ? ' +3 ⭐' : ''}', style: const TextStyle(color: Colors.white70)),
          Btn(t('Cambiar respuesta'), onTap: () => st.update(() => l.sport = null)),
        ]));
      } else if (l.sport == 'no') {
        w.add(Box(child: vgap([
          Row(children: [Expanded(child: Eyebrow(t('Día de deporte'))), Btn(t('Cambiar'), kind: BtnKind.ghost, onTap: () => st.update(() => l.sport = null))]),
          Text(spTxt),
          Text(t('No hiciste el deporte, así que generamos una rutina de reemplazo.'), style: TextStyle(color: p.muted)),
        ], 6)));
        w.addAll(_routine(context, st, dk, !future));
      } else {
        w.add(HeroBox(children: [
          Eyebrow(t('Día de deporte'), color: Colors.white),
          Text(up(context, future ? t('Este día tienes deporte') : t('¿Hiciste tu deporte?')), style: display(context, 34, color: Colors.white)),
          Text(spTxt),
          if (future)
            Text(t('Ese día te preguntaremos si lo hiciste. Si no, te damos una rutina.'), style: const TextStyle(color: Colors.white70))
          else ...[
            Row(children: [
              Expanded(child: Btn(t('Sí, lo hice'), kind: BtnKind.ok, onTap: () => st.update(() => l.sport = 'si'))),
              const SizedBox(width: 10),
              Expanded(child: Btn(t('No, dame rutina'), onTap: () => st.update(() => l.sport = 'no'))),
            ]),
            Btn(t('Hice un deporte diferente'), expand: true, onTap: () => showSheet(context, (_) => const OtherActivitySheet())),
          ],
        ]));
      }
    } else if (pr.routineDays.contains(wd) || l.extra) {
      w.addAll(_routine(context, st, dk, !future));
    } else {
      w.add(HeroBox(children: [
        Eyebrow(t('Descanso'), color: Colors.white),
        Text(up(context, t('Hoy toca recuperar')), style: display(context, 34, color: Colors.white)),
        Text(t('Camina 20–30 minutos, hidrátate y estira. Si tienes energía, puedes entrenar igual.'), style: const TextStyle(color: Colors.white70)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Btn(t('Quiero entrenar hoy'), onTap: () => st.update(() => l.extra = true)),
          if (!future) Btn(t('Hice otra actividad'), onTap: () => showSheet(context, (_) => const OtherActivitySheet())),
        ]),
      ]));
    }
    if (pr.isKid && dk == today) w.add(const MedalsView());
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 110), children: _spaced(w, 16));
  }

  List<Widget> _routine(BuildContext context, AppState st, String dk, bool editable) {
    final pr = st.profile!;
    final p = Palette.of(context);
    final kid = pr.isKid;
    final r = generateRoutine(pr, dk);
    final l = st.log(dk);
    final all = r.all;
    final done = all.where((i) => l.done.contains(i.ex.id)).length;
    final pct = all.isEmpty ? 0.0 : done / all.length;
    final title = r.parts.map(t).join(' + ') + (r.blocks.any((b) => b.title == 'Abdomen') ? ' + ${t('Abdomen')}' : '');
    final out = <Widget>[];
    if (kid) {
      final phrase = pr.sports.any((s) => s.name == 'Patinaje') ? '¡A patinar más rápido que el viento!' : _kidPhrases[strHash(dk) % _kidPhrases.length];
      out.add(HeroBox(children: [
        Row(children: [
          const Text('🌟', style: TextStyle(fontSize: 64)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Eyebrow(t('Misión de hoy'), color: Colors.white),
            Text(title, style: display(context, 30, color: Colors.white)),
            Text(t(phrase), style: const TextStyle(fontWeight: FontWeight.w700)),
          ])),
        ]),
        Row(children: [Expanded(child: Text(t('Estrellas de hoy'), style: const TextStyle(fontWeight: FontWeight.w800))), Text('$done/${all.length}', style: const TextStyle(fontWeight: FontWeight.w800))]),
        Wrap(spacing: 3, children: [for (final i in all) Opacity(opacity: l.done.contains(i.ex.id) ? 1 : .3, child: const Text('⭐', style: TextStyle(fontSize: 22)))]),
        statRow([StatTile('${r.minutes}', t('minutos'), onHero: true), StatTile('${all.length}', t('ejercicios'), onHero: true), StatTile('${(pct * 100).round()}%', t('hechos'), onHero: true), StatTile('+3', t('al terminar'), onHero: true)]),
      ]));
    } else {
      out.add(HeroBox(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Eyebrow(t('Rutina del día'), color: Colors.white), const SizedBox(height: 4), Text(title.toUpperCase(), style: display(context, 36, color: Colors.white))])),
          const SizedBox(width: 12),
          ProgressRing(pct, label: '${(pct * 100).round()}%'),
        ]),
        statRow([StatTile('${r.minutes}', t('minutos'), onHero: true), StatTile('${all.length}', t('ejercicios'), onHero: true), StatTile('~${(r.minutes * 7.5).round()}', 'kcal', onHero: true), StatTile('$done', t('hechos'), onHero: true)]),
      ]));
    }
    if (r.lowSleep) out.add(Box(color: p.acc2.withValues(alpha: .12), child: Text('${t('Dormiste menos de 6 horas.')} ${t('Hoy la rutina tiene una serie menos por ejercicio para que recuperes.')}')));
    if (!editable) out.add(Box(color: p.acc2.withValues(alpha: .12), child: Text(t('Vista previa. Podrás marcar los ejercicios ese día.'))));
    for (var b = 0; b < r.blocks.length; b++) {
      final blk = r.blocks[b];
      out.add(vgap([
        Row(children: [
          Container(width: 32, height: 32, alignment: Alignment.center, decoration: BoxDecoration(color: p.raised, borderRadius: BorderRadius.circular(10), border: Border.all(color: p.line)), child: Text(kid ? (_kidIcons[blk.title] ?? '⭐') : '${b + 1}', style: display(context, 17, color: p.acc2))),
          const SizedBox(width: 10),
          Expanded(child: Text(t(blk.title), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          Text('${blk.minutes} min${blk.sub.isNotEmpty ? ' · ${blk.sub}' : ''}', style: TextStyle(color: p.muted, fontSize: 12)),
        ]),
        for (final it in blk.items) _ExerciseCard(it, dk, editable),
      ], 10));
    }
    if (!editable) return out;
    if (l.complete) {
      out.add(HeroBox(align: CrossAxisAlignment.center, children: [
        Text(kid ? '🏆' : '✅', style: const TextStyle(fontSize: 64)),
        Text(up(context, kid ? t('¡Misión cumplida!') : t('Rutina completada')), textAlign: TextAlign.center, style: display(context, 32, color: Colors.white)),
        if (kid) Text(t('Ganaste {n} estrellas hoy', {'n': l.stars}), style: const TextStyle(fontWeight: FontWeight.w800)),
        Btn(t('Desmarcar'), onTap: () => st.update(() => l.complete = false)),
      ]));
    } else {
      out.add(vgap([
        Btn(kid ? t('¡Terminé mi misión!') : t('Terminé mi rutina'), kind: BtnKind.primary, expand: true, onTap: () => st.update(() {
              l.complete = true;
              l.skip = null;
            })),
        Row(children: [
          Expanded(child: Btn(t('No hice la rutina'), onTap: () => showSheet(context, (_) => const SkipSheet()))),
          const SizedBox(width: 10),
          Expanded(child: Btn(t('Hice otra actividad'), onTap: () => showSheet(context, (_) => const OtherActivitySheet()))),
        ]),
      ], 10));
    }
    return out;
  }
}

List<Widget> _spaced(List<Widget> w, double g) => [for (var i = 0; i < w.length; i++) ...[if (i > 0) SizedBox(height: g), w[i]]];

class _ExerciseCard extends StatelessWidget {
  final RoutineItem it;
  final String day;
  final bool editable;
  const _ExerciseCard(this.it, this.day, this.editable);
  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final p = Palette.of(context);
    final kid = st.profile!.isKid;
    final l = st.log(day);
    final on = l.done.contains(it.ex.id);
    return Opacity(
      opacity: on && !kid ? .6 : 1,
      child: Box(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          GestureDetector(onTap: () => showSheet(context, (_) => ExerciseSheet(it.ex, rx: it.rx)), child: ExerciseImage(it.ex, width: 104, height: 84)),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => showSheet(context, (_) => ExerciseSheet(it.ex, rx: it.rx)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it.ex.name, style: TextStyle(fontWeight: FontWeight.w700, decoration: on && !kid ? TextDecoration.lineThrough : null)),
                const SizedBox(height: 3),
                Text(it.rx, style: display(context, 16, color: kid ? p.deep : p.acc2)),
                const SizedBox(height: 4),
                kid
                    ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFFFF0B8), borderRadius: BorderRadius.circular(99)), child: Text(on ? t('¡Estrella ganada!') : '+1 ⭐', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFB57A00))))
                    : Wrap(spacing: 6, runSpacing: 4, children: [Pill(t(it.ex.part)), if (it.ex.eq != 'ninguno') Pill(t(_eqName(it.ex.eq)), color: p.acc2)]),
              ]),
            ),
          ),
          GestureDetector(
            onTap: editable ? () => st.update(() => on ? l.done.remove(it.ex.id) : l.done.add(it.ex.id)) : null,
            child: Opacity(
              opacity: editable ? 1 : .35,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: on ? (kid ? const Color(0xFFFFC93C) : p.ok) : p.bg2, border: Border.all(color: on ? (kid ? const Color(0xFFD99A00) : p.ok) : p.line, width: 2)),
                child: kid && on ? const Text('⭐', style: TextStyle(fontSize: 20)) : Icon(Icons.check_rounded, color: on ? const Color(0xFF06150E) : p.muted),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

String _eqName(String k) => const {
      'mancuernas': 'Mancuernas', 'barra': 'Barra y discos', 'banco': 'Banco', 'rueda': 'Rueda abdominal', 'barrafija': 'Barra de dominadas', 'bici': 'Bicicleta estática',
      'eliptica': 'Elíptica', 'caminadora': 'Caminadora', 'remo': 'Máquina de remo', 'cuerda': 'Cuerda para saltar', 'kettlebell': 'Kettlebell', 'bandas': 'Bandas elásticas',
      'fitball': 'Fitball', 'balon': 'Balón medicinal', 'step': 'Step', 'trx': 'TRX / suspensión', 'paralelas': 'Paralelas', 'gym': 'Gimnasio (poleas y máquinas)',
    }[k] ??
    k;

class _WatchStats extends StatelessWidget {
  const _WatchStats();
  @override
  Widget build(BuildContext context) {
    final pr = context.watch<AppState>().profile!;
    final p = Palette.of(context);
    final w = pr.watch, d = w.data;
    if (d == null) {
      return Box(child: vgap([
        Text(t('Conecta tu reloj o banda'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        Text(t('Pasos, pulso, calorías y sueño ajustan tu rutina del día.'), style: TextStyle(color: p.muted)),
        Row(children: [
          Btn(t('Elegir mi reloj'), kind: BtnKind.primary, onTap: () => showSheet(context, (_) => const WatchSheet())),
          const SizedBox(width: 10),
          Btn(t('Ingresar a mano'), onTap: () => showSheet(context, (_) => const ManualDataSheet())),
        ]),
      ], 8));
    }
    return vgap([
      SectionTitle(t('Tu día'), trailing: Btn('${w.linked ? (w.model ?? '') : t('Manual')} · ${t('Editar')}', kind: BtnKind.ghost, onTap: () => showSheet(context, (_) => const ManualDataSheet()))),
      statRow([
        StatTile(I18n.fmt(d.steps), t('Pasos'), icon: Icons.directions_walk_rounded, iconColor: p.acc),
        StatTile('${d.restingHr}', t('Pulso reposo'), icon: Icons.favorite_rounded, iconColor: const Color(0xFFFF6B8A)),
        StatTile(I18n.fmt(d.activeKcal), t('kcal activas'), icon: Icons.local_fire_department_rounded, iconColor: p.acc2),
        StatTile('${d.sleepHours} h', t('Sueño'), icon: Icons.nightlight_round, iconColor: const Color(0xFF9B8CFF)),
      ]),
    ], 8);
  }
}

class _OtherCard extends StatelessWidget {
  final OtherActivity o;
  const _OtherCard(this.o);
  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    final kid = st.profile!.isKid;
    return HeroBox(children: [
      Eyebrow(t('Actividad registrada'), color: Colors.white),
      Text(up(context, t(o.name)), style: display(context, 34, color: Colors.white)),
      statRow([
        StatTile('${o.minutes}', t('minutos'), onHero: true),
        StatTile(o.kcal > 0 ? '${o.kcal}' : '—', 'kcal', onHero: true),
        StatTile(o.avgHr != null ? '${o.avgHr}' : '—', t('pulso medio'), onHero: true),
        StatTile(kid ? '+2 ⭐' : t(o.intensity), kid ? t('estrellas') : t('intensidad'), onHero: true),
      ]),
      Text('${o.source.isNotEmpty ? t('Datos tomados de {x}', {'x': o.source}) : t('Ingreso manual')} · ${t('Esta actividad reemplaza la rutina del día.')}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
      Btn(t('Cambiar respuesta'), onTap: () => st.update(() => st.log(st.selected).other = null)),
    ]);
  }
}

class MedalsView extends StatelessWidget {
  const MedalsView({super.key});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final p = Palette.of(context);
    return vgap([
      SectionTitle(t('Mis medallas'), trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFFFC93C), borderRadius: BorderRadius.circular(99), boxShadow: const [BoxShadow(color: Color(0xFFD99A00), offset: Offset(0, 4))]), child: Text('⭐ ${st.totalStars}', style: display(context, 18, color: const Color(0xFF5A3A00))))),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: .85,
        children: [
          for (final m in st.medals)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: m.won ? p.acc2 : p.line, width: 2), boxShadow: [BoxShadow(color: m.won ? p.acc2.withValues(alpha: .6) : p.line, offset: const Offset(0, 4))]),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Opacity(opacity: m.won ? 1 : .3, child: Text(m.emoji, style: const TextStyle(fontSize: 34))),
                const SizedBox(height: 4),
                Text(t(m.name), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                Text(t(m.desc), textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, color: p.muted)),
              ]),
            ),
        ],
      ),
    ], 10);
  }
}

