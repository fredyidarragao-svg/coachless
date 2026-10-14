import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/engine.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../services/health_service.dart';
import '../widgets/ui.dart';

String _n(double v, [int d = 1]) => I18n.fmt(double.parse(v.toStringAsFixed(d)));

Color _levelColor(Palette p, int level) => switch (level) { 0 => p.acc2, 1 => p.ok, 2 => p.acc2, _ => p.bad };

/// Registro de una medición corporal: peso, medidas con cinta y (opcional) báscula de bioimpedancia.
class BodyScanSheet extends StatefulWidget {
  const BodyScanSheet({super.key});
  @override
  State<BodyScanSheet> createState() => _BodyScanSheetState();
}

class _BodyScanSheetState extends State<BodyScanSheet> {
  late double weight;
  double? neck, waist, hip, chest, arm, thigh, fat, muscle, water, bone, visceral;
  int? bmr, mage;
  bool scale = false, reading = false;
  String? msg;
  int formKey = 0;

  @override
  void initState() {
    super.initState();
    final pr = context.read<AppState>().profile!;
    weight = pr.weight;
    final last = pr.scans.isEmpty ? null : pr.scans.last;
    neck = last?.neck;
    waist = last?.waist;
    hip = last?.hip;
    chest = last?.chest;
    arm = last?.arm;
    thigh = last?.thigh;
  }

  double? _p(String v) => double.tryParse(v.replaceAll(',', '.'));

  Widget field(String label, num? value, ValueChanged<String> on, {String? help}) => TextFormField(
        key: ValueKey('$label$formKey'),
        initialValue: value == null ? '' : '$value',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, helperText: help, helperMaxLines: 2),
        onChanged: (v) => setState(() => on(v)),
      );

  Widget pair(Widget a, Widget b) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);

  Future<void> readScale() async {
    setState(() {
      reading = true;
      msg = null;
    });
    await HealthService.requestPermissions();
    final (w, f) = await HealthService.latestBodyComposition();
    setState(() {
      reading = false;
      if (w == null && f == null) {
        msg = t('No encontramos lecturas de báscula en los últimos 30 días. Sincroniza la app de tu báscula o escribe los valores a mano.');
      } else {
        if (w != null) weight = double.parse(w.toStringAsFixed(1));
        if (f != null) fat = double.parse(f.toStringAsFixed(1));
        scale = fat != null || scale;
        formKey++;
        msg = t('Datos leídos de tu báscula.');
      }
    });
  }

  void save() {
    final st = context.read<AppState>();
    final pr = st.profile!;
    final scan = BodyScan(
      date: todayKey(), weight: weight, height: pr.height, neck: neck, waist: waist, hip: hip, chest: chest, arm: arm, thigh: thigh,
      fatPct: scale ? fat : null, muscleKg: scale ? muscle : null, waterPct: scale ? water : null, boneKg: scale ? bone : null,
      visceral: scale ? visceral : null, bmr: scale ? bmr : null, metabolicAge: scale ? mage : null,
      source: scale && fat != null ? t('Báscula de bioimpedancia') : 'medidas',
    );
    st.update(() {
      pr.scans.removeWhere((s) => s.date == scan.date);
      pr.scans.add(scan);
      if (weight > 0 && weight != pr.weight) {
        pr.weight = weight;
        pr.weights.add(WeightEntry(todayKey(), weight));
      }
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final pr = context.read<AppState>().profile!;
    final female = pr.sex == 'f';
    final canSave = weight > 0 && ((neck != null && waist != null && (!female || hip != null)) || (scale && fat != null));
    final preview = canSave
        ? analyzeBody(pr, BodyScan(date: todayKey(), weight: weight, height: pr.height, neck: neck, waist: waist, hip: hip, fatPct: scale ? fat : null))
        : null;
    return vgap([
      Eyebrow(t('Composición corporal')),
      Text(up(context, t('Nueva medición')), style: display(context, 28)),
      Box(
        color: p.acc.withValues(alpha: .1),
        child: vgap([
          Text(t('Cómo medir con cinta métrica'), style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('• ${t('Mídete en la mañana, en ayunas y después de ir al baño.')}'),
          Text('• ${t('Cuello: justo debajo de la nuez, con la cinta un poco inclinada hacia adelante.')}'),
          Text(female ? '• ${t('Cintura: en la parte más estrecha del abdomen.')}' : '• ${t('Cintura: a la altura del ombligo, sin meter el abdomen.')}'),
          Text('• ${t('Cadera: en la parte más ancha de los glúteos.')}'),
          Text('• ${t('Cinta ajustada pero sin apretar la piel. Usa siempre centímetros.')}'),
        ], 4),
      ),
      field('${t('Peso')} (kg)', weight, (v) => weight = _p(v) ?? weight),
      pair(field('${t('Cuello')} (cm)', neck, (v) => neck = _p(v)), field('${t('Cintura')} (cm)', waist, (v) => waist = _p(v))),
      pair(field('${t('Cadera')} (cm)${female ? ' *' : ''}', hip, (v) => hip = _p(v)), field('${t('Pecho')} (cm)', chest, (v) => chest = _p(v))),
      pair(field('${t('Brazo')} (cm)', arm, (v) => arm = _p(v), help: t('Opcional, para ver tu progreso')), field('${t('Muslo')} (cm)', thigh, (v) => thigh = _p(v), help: t('Opcional, para ver tu progreso'))),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: scale,
        activeColor: p.acc,
        onChanged: (v) => setState(() => scale = v),
        title: Text(t('Tengo báscula de bioimpedancia'), style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(t('Xiaomi, Huawei, Renpho, Omron, InBody u otra que mida grasa corporal.'), style: TextStyle(color: p.muted, fontSize: 12)),
      ),
      if (!kIsWeb) Btn(reading ? t('Leyendo…') : t('Leer de mi báscula (Health Connect / Apple Salud)'), icon: Icons.monitor_weight_rounded, expand: true, onTap: reading ? null : readScale),
      if (msg != null) Text(msg!, style: TextStyle(color: p.muted)),
      if (scale) ...[
        pair(field('${t('Grasa corporal')} (%)', fat, (v) => fat = _p(v)), field('${t('Masa muscular')} (kg)', muscle, (v) => muscle = _p(v))),
        pair(field('${t('Agua corporal')} (%)', water, (v) => water = _p(v)), field('${t('Masa ósea')} (kg)', bone, (v) => bone = _p(v))),
        pair(field(t('Grasa visceral (nivel)'), visceral, (v) => visceral = _p(v)), field('${t('Metabolismo basal')} (kcal)', bmr, (v) => bmr = int.tryParse(v))),
        field(t('Edad metabólica'), mage, (v) => mage = int.tryParse(v)),
      ],
      if (preview?.fatPct != null)
        Box(
          border: p.acc,
          child: Row(children: [
            Text('${_n(preview!.fatPct!)} %', style: display(context, 30, color: _levelColor(p, preview.fatRate!.level))),
            const SizedBox(width: 12),
            Expanded(child: Text('${t('Grasa corporal')} · ${t(preview.fatRate!.label)}\n${preview.fromScale ? t('Valor de tu báscula') : t('Estimado con tus medidas')}', style: const TextStyle(fontSize: 13))),
          ]),
        ),
      if (!canSave) Text(female ? t('Para el análisis necesitamos peso, cuello, cintura y cadera, o el porcentaje de grasa de tu báscula.') : t('Para el análisis necesitamos peso, cuello y cintura, o el porcentaje de grasa de tu báscula.'), style: TextStyle(color: p.muted, fontSize: 12.5)),
      Btn(t('Guardar y analizar'), kind: BtnKind.primary, expand: true, onTap: canSave ? save : null),
    ], 12);
  }
}

/// Resultados del análisis en el perfil.
class BodyCompositionCard extends StatelessWidget {
  const BodyCompositionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final pr = st.profile!;
    final p = Palette.of(context);
    if (pr.isKid) {
      return Box(child: vgap([
        Text(t('Composición corporal'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        Text(t('En menores de 15 años la composición corporal se evalúa con tablas de crecimiento del pediatra. Aquí registramos peso y estatura para ver cómo creces.'), style: TextStyle(color: p.muted)),
      ], 8));
    }
    final scans = [...pr.scans]..sort((a, b) => a.date.compareTo(b.date));
    if (scans.isEmpty) {
      return Box(
        border: p.acc,
        child: vgap([
          Row(children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(color: p.acc, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.accessibility_new_rounded, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('Análisis de composición corporal'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(t('Grasa, masa magra, agua y riesgo por cintura con tu peso y tus medidas, o con tu báscula de bioimpedancia.'), style: TextStyle(color: p.muted, fontSize: 12.5)),
            ])),
          ]),
          Btn(t('Hacer mi primera medición'), kind: BtnKind.primary, expand: true, onTap: () => showSheet(context, (_) => const BodyScanSheet())),
        ], 10),
      );
    }
    final a = analyzeBody(pr, scans.last);
    final prev = scans.length > 1 ? analyzeBody(pr, scans[scans.length - 2]) : null;
    String delta(double? now, double? before, String unit) {
      if (now == null || before == null) return '';
      final d = now - before;
      if (d.abs() < .05) return '=';
      return '${d > 0 ? '+' : ''}${_n(d)} $unit';
    }

    Widget metric(String label, String value, {Rated? rate, String? sub}) => Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: p.muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(value, style: display(context, 21)),
            if (rate != null) Text(t(rate.label), style: TextStyle(color: _levelColor(p, rate.level), fontSize: 11.5, fontWeight: FontWeight.w800)),
            if (sub != null) Text(sub, style: TextStyle(color: p.muted, fontSize: 11)),
          ]),
        );

    final cells = <Widget>[
      metric(t('Masa grasa'), a.fatKg == null ? '—' : '${_n(a.fatKg!)} kg', sub: delta(a.fatKg, prev?.fatKg, 'kg')),
      metric(t('Masa magra'), a.leanKg == null ? '—' : '${_n(a.leanKg!)} kg', sub: delta(a.leanKg, prev?.leanKg, 'kg')),
      metric(t('IMC'), _n(a.bmi), rate: a.bmiRate),
      metric(t('Cintura / estatura'), a.whtr == null ? '—' : _n(a.whtr!, 2), rate: a.whtrRate),
      if (a.whr != null) metric(t('Cintura / cadera'), _n(a.whr!, 2), rate: a.whrRate),
      metric(t('Agua corporal'), a.waterPct == null ? '—' : '${_n(a.waterPct!)} %', sub: a.fromScale && a.scan.waterPct != null ? null : t('estimado')),
      metric(t('Metabolismo basal'), a.bmr == null ? '—' : '${I18n.fmt(a.bmr!)} kcal'),
      if (a.ffmi != null) metric(t('Índice de masa magra'), _n(a.ffmi!), sub: 'FFMI'),
      if (a.muscleKg != null) metric(t('Masa muscular'), '${_n(a.muscleKg!)} kg'),
      if (a.boneKg != null) metric(t('Masa ósea'), '${_n(a.boneKg!)} kg'),
      if (a.visceral != null) metric(t('Grasa visceral'), _n(a.visceral!, 0), rate: a.visceralRate),
      if (a.metabolicAge != null) metric(t('Edad metabólica'), '${a.metabolicAge} ${t('años')}'),
    ];

    final hist = scans.length > 6 ? scans.sublist(scans.length - 6) : scans;
    final fats = hist.map((s) => analyzeBody(pr, s).fatPct).toList();
    final maxF = fats.whereType<double>().fold<double>(1, max);

    return Box(
      child: vgap([
        Row(children: [
          Expanded(child: Text(t('Composición corporal'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          Text(I18n.dateLong(dparse(a.scan.date)), style: TextStyle(color: p.muted, fontSize: 12)),
        ]),
        if (a.fatPct != null) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${_n(a.fatPct!)} %', style: display(context, 44, color: _levelColor(p, a.fatRate!.level))),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${t('Grasa corporal')} · ${t(a.fatRate!.label)}${prev?.fatPct != null ? '\n${delta(a.fatPct, prev!.fatPct, '%')} ${t('desde la medición anterior')}' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
          _FatScale(fat: a.fatPct!, female: pr.sex == 'f', target: a.targetFat),
        ],
        Text(a.fromScale ? '${t('Fuente')}: ${a.scan.source}' : t('Estimado con tus medidas (método de la Marina de EE. UU.). Una báscula de bioimpedancia o un estudio profesional dan valores más precisos.'), style: TextStyle(color: p.muted, fontSize: 11.5)),
        GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.75, children: cells),
        Box(
          color: p.acc2.withValues(alpha: .1),
          child: Text(
            [
              t('Peso saludable para tu estatura: {a}–{b} kg.', {'a': _n(a.idealMin), 'b': _n(a.idealMax)}),
              if (a.targetFat != null && a.fatPct != null)
                a.fatPct! > a.targetFat! + 1
                    ? t('Para tu objetivo apunta a cerca de {f} % de grasa: unos {k} kg menos de grasa, manteniendo tu masa magra.', {'f': _n(a.targetFat!, 0), 'k': _n(a.scan.weight * (a.fatPct! - a.targetFat!) / 100)})
                    : t('Tu porcentaje de grasa está en el rango de tu objetivo. Enfócate en mantener o ganar masa magra.'),
            ].join('\n'),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        if (fats.whereType<double>().length > 1) ...[
          Text(t('Evolución de la grasa corporal'), style: const TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(
            height: 84,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < hist.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text(fats[i] == null ? '' : _n(fats[i]!), style: TextStyle(fontSize: 10, color: p.muted, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Container(height: fats[i] == null ? 3 : max(4.0, 50 * fats[i]! / maxF), decoration: BoxDecoration(color: i == hist.length - 1 ? p.acc : p.acc.withValues(alpha: .45), borderRadius: BorderRadius.circular(5))),
                      const SizedBox(height: 4),
                      Text('${dparse(hist[i].date).day}/${dparse(hist[i].date).month}', style: TextStyle(fontSize: 10, color: p.muted)),
                    ]),
                  ),
                ),
            ]),
          ),
        ],
        Btn(t('Nueva medición'), kind: BtnKind.primary, icon: Icons.straighten_rounded, expand: true, onTap: () => showSheet(context, (_) => const BodyScanSheet())),
        Text(t('Repite la medición cada 2 a 4 semanas, a la misma hora y en las mismas condiciones.'), style: TextStyle(color: p.muted, fontSize: 11.5)),
      ], 10),
    );
  }
}

/// Barra de rangos de grasa corporal con la posición actual y el objetivo.
class _FatScale extends StatelessWidget {
  final double fat;
  final bool female;
  final double? target;
  const _FatScale({required this.fat, required this.female, this.target});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final cuts = female ? [10.0, 14.0, 21.0, 25.0, 32.0, 45.0] : [2.0, 6.0, 14.0, 18.0, 25.0, 40.0];
    final cols = [p.acc2, p.ok, p.ok.withValues(alpha: .7), p.acc2, p.bad];
    final labels = ['Muy bajo', 'Atlético', 'En forma', 'Aceptable', 'Alto'];
    double pos(double v) => ((v - cuts.first) / (cuts.last - cuts.first)).clamp(0.0, 1.0);
    return LayoutBuilder(builder: (c, bc) {
      final w = bc.maxWidth;
      return SizedBox(
        height: 46,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Row(children: [
              for (var i = 0; i < 5; i++)
                Expanded(
                  flex: ((cuts[i + 1] - cuts[i]) * 10).round(),
                  child: Container(height: 10, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: BoxDecoration(color: cols[i], borderRadius: BorderRadius.circular(5))),
                ),
            ]),
          ),
          if (target != null) Positioned(left: w * pos(target!) - 1, top: 10, child: Container(width: 2, height: 18, color: p.fg.withValues(alpha: .6))),
          Positioned(left: (w * pos(fat) - 7).clamp(0, w - 14), top: 0, child: Icon(Icons.arrow_drop_down_rounded, size: 22, color: p.fg)),
          Positioned(
            top: 28,
            left: 0,
            right: 0,
            child: Row(children: [
              for (var i = 0; i < 5; i++) Expanded(flex: ((cuts[i + 1] - cuts[i]) * 10).round(), child: Text(t(labels[i]), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(fontSize: 9.5, color: p.muted))),
            ]),
          ),
        ]),
      );
    });
  }
}
