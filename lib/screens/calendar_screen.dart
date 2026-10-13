import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/engine.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

/// Calendario de evidencias: qué se entrenó cada día y las muestras del reloj con su hora.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime month;
  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    month = DateTime(n.year, n.month);
  }

  /// Estado del día para pintar el calendario.
  (Color?, String) status(BuildContext c, Profile pr, DayLog? l, String dk) {
    final p = Palette.of(c);
    if (l == null) return (null, '');
    if (l.complete) return (p.ok, pr.isKid ? '⭐' : '✓');
    if (l.sport == 'si') return (p.acc2, '⚽');
    if (l.other != null) return (p.acc2, '★');
    if (l.skip != null) return (p.bad, '✕');
    return (null, '');
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final pr = st.profile!;
    final p = Palette.of(context);
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1;
    final today = todayKey();
    var trained = 0, samples = 0, skipped = 0;
    for (var d = 1; d <= days; d++) {
      final l = st.peek(dkey(DateTime(month.year, month.month, d)));
      if (l == null) continue;
      if (l.isDone) trained++;
      if (l.skip != null) skipped++;
      samples += l.samples.length;
    }
    final title = DateFormat('MMMM y', I18n.locale).format(month);

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(t('Calendario y evidencias'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        Row(children: [
          IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: Icon(Icons.chevron_left_rounded, color: p.acc2)),
          Expanded(child: Text(up(context, title[0].toUpperCase() + title.substring(1)), textAlign: TextAlign.center, style: display(context, 26))),
          IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: Icon(Icons.chevron_right_rounded, color: p.acc2)),
        ]),
        const SizedBox(height: 8),
        statRow([StatTile('$trained', t('días cumplidos')), StatTile('$skipped', t('días sin entrenar')), StatTile('$samples', t('muestras del reloj'))]),
        const SizedBox(height: 14),
        Row(children: [for (var i = 0; i < 7; i++) Expanded(child: Text(I18n.dayName(i, short: true).substring(0, 2).toUpperCase(), textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 11, fontWeight: FontWeight.w800)))]),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: .78,
          children: [
            for (var i = 0; i < lead; i++) const SizedBox(),
            for (var d = 1; d <= days; d++)
              Builder(builder: (_) {
                final dk = dkey(DateTime(month.year, month.month, d));
                final l = st.peek(dk);
                final (col, mark) = status(context, pr, l, dk);
                final n = l?.samples.length ?? 0;
                return GestureDetector(
                  onTap: () => showSheet(context, (_) => _DayDetail(dk)),
                  child: Container(
                    decoration: BoxDecoration(
                      color: col == null ? p.surface : col.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: dk == today ? p.acc : (col ?? p.line), width: dk == today ? 2 : 1),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                      Text('$d', style: display(context, 17)),
                      Text(mark, style: TextStyle(color: col, fontWeight: FontWeight.w900, fontSize: 14)),
                      if (n > 0) Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.watch_rounded, size: 10, color: p.acc), Text('$n', style: TextStyle(fontSize: 10, color: p.acc, fontWeight: FontWeight.w800))]) else const SizedBox(height: 12),
                    ]),
                  ),
                );
              }),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 14, runSpacing: 6, children: [
          _legend(p.ok, pr.isKid ? '⭐ ${t('Rutina')}' : '✓ ${t('Rutina')}'),
          _legend(p.acc2, '⚽ ${t('Deporte')}'),
          _legend(p.acc2, '★ ${t('Otra actividad')}'),
          _legend(p.bad, '✕ ${t('Sin entrenar')}'),
          _legend(p.acc, '⌚ ${t('Muestras del reloj')}'),
        ]),
      ]),
    );
  }

  Widget _legend(Color c, String s) => Text(s, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12.5));
}

class _DayDetail extends StatelessWidget {
  final String day;
  const _DayDetail(this.day);
  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final pr = st.profile!;
    final p = Palette.of(context);
    final l = st.peek(day);
    final sp = sportsOn(pr, weekdayOf(day));
    final lines = <Widget>[];
    if (l == null || (!l.isDone && l.skip == null && l.samples.isEmpty && l.done.isEmpty)) {
      lines.add(Text(t('Sin registros este día.'), style: TextStyle(color: p.muted)));
    } else {
      if (l.complete) {
        final r = generateRoutine(pr, day);
        lines.add(_row(context, Icons.check_circle_rounded, p.ok, t('Rutina completada'), '${r.parts.map(t).join(' + ')} · ${l.done.length}/${r.all.length} ${t('ejercicios')}'));
      } else if (l.done.isNotEmpty) {
        lines.add(_row(context, Icons.timelapse_rounded, p.acc2, t('Rutina parcial'), '${l.done.length} ${t('ejercicios')}'));
      }
      if (l.sport == 'si') lines.add(_row(context, Icons.sports_soccer_rounded, p.acc2, t('Deporte registrado'), sp.map((s) => '${t(s.name)} · ${s.minutes} min').join(', ')));
      if (l.other != null) {
        final o = l.other!;
        lines.add(_row(context, Icons.directions_run_rounded, p.acc2, '${t('Otra actividad')}: ${t(o.name)}', '${o.minutes} min · ${o.kcal} kcal${o.avgHr != null ? ' · ${t('pulso medio')} ${o.avgHr}' : ''}${o.source.isNotEmpty ? ' · ${o.source}' : ''}'));
      }
      if (l.skip != null) lines.add(_row(context, Icons.cancel_rounded, p.bad, t('Rutina no realizada'), '${t('Motivo')}: ${t(l.skip!)}'));
      if (l.samples.isNotEmpty) {
        lines.add(Padding(padding: const EdgeInsets.only(top: 6), child: Text(t('Muestras del reloj'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))));
        for (final s in l.samples) {
          lines.add(Box(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Text(TimeOfDay.fromDateTime(s.at).format(context), style: display(context, 20, color: p.acc)),
              const SizedBox(width: 12),
              Expanded(
                child: Text('${I18n.fmt(s.steps)} ${t('pasos')} · ${s.restingHr} ${t('lpm')} · ${I18n.fmt(s.activeKcal)} kcal · ${s.sleepHours} h ${t('sueño')}\n${s.source}', style: const TextStyle(fontSize: 12.5)),
              ),
            ]),
          ));
        }
      }
    }
    return vgap([
      Eyebrow(I18n.dateLong(dparse(day))),
      Text(up(context, t('Evidencia del día')), style: display(context, 28)),
      ...lines,
    ], 10);
  }

  Widget _row(BuildContext c, IconData i, Color col, String title, String sub) => Box(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Icon(i, color: col),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), Text(sub, style: TextStyle(color: Palette.of(c).muted, fontSize: 12.5))])),
        ]),
      );
}

