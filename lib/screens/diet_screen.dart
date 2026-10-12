import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/catalog.dart';
import '../core/engine.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import 'sheets.dart';
import 'train_screen.dart';

class DietScreen extends StatelessWidget {
  const DietScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final pr = st.profile!;
    final p = Palette.of(context);
    final m = dayMenu(pr, st.selected, st.log(st.selected).meals);
    final over = m.costCop > pr.budgetCop;
    final pl = placeOf(pr);
    final cheapest = pl.cheapest.name;
    final base = m.costCop / m.mult;
    final maxKm = pl.stores.map((s) => s.km).reduce((a, b) => a > b ? a : b);

    final w = <Widget>[
      const WeekStrip(),
      HeroBox(children: [
        Eyebrow(pr.isKid ? t('Alimentación para crecer') : '${t('Plan')}: ${t(dietGoals[pr.dietGoal] ?? '')}', color: Colors.white),
        Row(children: [
          _MacroDonut(m),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('Meta diaria'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text('${I18n.fmt(m.targets.kcal)} KCAL', style: display(context, 28, color: Colors.white)),
              const SizedBox(height: 6),
              _legend(context, p.acc, '${t('Proteína')} ${m.protein} g'),
              _legend(context, p.acc2, '${t('Carbohidratos')} ${m.carbs} g'),
              _legend(context, p.ok, '${t('Grasa')} ${m.fat} g'),
              const SizedBox(height: 6),
              Pill('${money(m.costCop, pr)} · ${over ? t('sobre el presupuesto') : t('dentro del presupuesto')}', color: over ? p.bad : p.ok),
            ]),
          ),
        ]),
        Text(t('Porciones ajustadas ×{f} para llegar a tu meta. Proteína objetivo: {g} g.', {'f': m.factor.toStringAsFixed(2), 'g': m.targets.protein}), style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
      if (pr.isKid) Box(color: p.acc2.withValues(alpha: .12), child: Text(t('En menores de 15 años la app no aplica dietas para bajar de peso: arma un plan balanceado para crecer y rendir en el deporte. Recomendamos validarlo con el pediatra.'))),
      Box(child: vgap([
        Row(children: [
          Icon(Icons.place_rounded, color: p.acc2),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Supermercados cerca de ti'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text('${pl.city}, ${t(pl.country)} · ${pr.located ? t('ubicación activa') : t('ubicación manual')}', style: TextStyle(color: p.muted, fontSize: 12)),
          ])),
          Btn(t('Cambiar'), kind: BtnKind.ghost, onTap: () => showSheet(context, (_) => const LocationSheet())),
        ]),
        SizedBox(
          height: 86,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final s in pl.byDistance)
              GestureDetector(
                onTap: () => st.update(() => pr.store = s.name),
                child: Container(
                  width: 210,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: s.name == m.store.name ? p.acc.withValues(alpha: .14) : p.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: s.name == m.store.name ? p.acc : p.line)),
                  child: Row(children: [
                    Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(10)), child: Text(s.name.substring(0, 2).toUpperCase(), style: display(context, 14, color: Colors.white))),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Row(children: [Flexible(child: Text(s.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))), if (s.name == cheapest) ...[const SizedBox(width: 4), Pill(t('Más barato'), color: p.ok)]]),
                      Text('${I18n.fmt(s.km)} km · ${t('día')} ${money(base * s.priceFactor, pr)}', style: TextStyle(color: p.muted, fontSize: 11.5)),
                      const SizedBox(height: 4),
                      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: 1 - s.km / maxKm * .8, minHeight: 4, color: p.acc2, backgroundColor: p.line)),
                    ])),
                  ]),
                ),
              ),
          ]),
        ),
        TextFormField(
          key: ValueKey('budget-${pr.place}'),
          initialValue: (pr.budgetCop * pl.rate).round().toString(),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: '${t('Presupuesto diario')} (${pl.currency})'),
          onFieldSubmitted: (v) {
            final n = double.tryParse(v);
            if (n != null && n > 0) st.update(() => pr.budgetCop = n / pl.rate);
          },
        ),
      ], 10)),
    ];

    for (final it in m.items) {
      final f = it.food;
      w.add(Box(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Plate(f.emoji),
          const SizedBox(width: 14),
          Expanded(
            child: vgap([
              Row(children: [Expanded(child: Eyebrow(t(slotNames[it.slot]!))), Text('${f.minutes} min', style: TextStyle(color: p.muted, fontSize: 12))]),
              GestureDetector(onTap: () => showSheet(context, (_) => FoodSheet(f)), child: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              MacroBar(f.protein, f.carbs, f.fat),
              Wrap(spacing: 6, runSpacing: 6, children: [
                Pill('${(f.kcal * m.factor).round()} kcal'),
                Pill('${(f.protein * m.factor).round()} g ${t('prot')}'),
                Pill(money(f.costCop * m.mult * m.factor, pr), color: p.acc2),
                if (f.has('v')) Pill(t('Vegetariano'), color: p.ok),
              ]),
              Row(children: [
                Btn(t('Receta'), onTap: () => showSheet(context, (_) => FoodSheet(f))),
                const SizedBox(width: 8),
                Expanded(child: Btn(t('Cambiar plato'), kind: BtnKind.primary, onTap: () => showSheet(context, (_) => SwapSheet(it.slot)))),
              ]),
            ], 7),
          ),
        ]),
      ));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 110), children: [for (var i = 0; i < w.length; i++) ...[if (i > 0) const SizedBox(height: 16), w[i]]]);
  }

  Widget _legend(BuildContext c, Color col, String s) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: col, shape: BoxShape.circle)), const SizedBox(width: 6), Text(s, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))]),
      );
}

class _MacroDonut extends StatelessWidget {
  final DayMenu m;
  const _MacroDonut(this.m);
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      width: 124,
      height: 124,
      child: CustomPaint(
        painter: _DonutPainter([m.protein * 4.0, m.carbs * 4.0, m.fat * 9.0], [p.acc, p.acc2, p.ok]),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(I18n.fmt(m.kcal), style: display(context, 26, color: Colors.white)),
            const Text('kcal', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> v;
  final List<Color> c;
  _DonutPainter(this.v, this.c);
  @override
  void paint(Canvas canvas, Size s) {
    final r = Rect.fromLTWH(7, 7, s.width - 14, s.height - 14);
    final bg = Paint()..style = PaintingStyle.stroke..strokeWidth = 14..color = Colors.white12;
    canvas.drawArc(r, 0, 6.2832, false, bg);
    final tot = v.fold<double>(0, (a, b) => a + b);
    if (tot <= 0) return;
    var start = -1.5708;
    for (var i = 0; i < v.length; i++) {
      final sweep = 6.2832 * v[i] / tot;
      canvas.drawArc(r, start, sweep - .05, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 14..color = c[i]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter o) => true;
}
