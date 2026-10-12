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
import 'onboarding.dart';
import 'sheets.dart';
import 'train_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void edit(BuildContext c, String step) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => OnboardingScreen(editStep: step)));

  Widget section(BuildContext c, String title, String step, Widget body) => Box(
        child: vgap([
          Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))), Btn(t('Editar'), kind: BtnKind.ghost, onTap: () => edit(c, step))]),
          body,
        ], 6),
      );

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final pr = st.profile!;
    final p = Palette.of(context);
    final kid = pr.isKid;
    final imc = pr.weight / ((pr.height / 100) * (pr.height / 100));
    final first = pr.weights.isNotEmpty ? pr.weights.first.kg : pr.weight;
    final diff = pr.weight - first;
    final g = kid ? kidGoals : goals;
    final w = pr.watch, wb = Catalog.brand(w.brand);

    final children = <Widget>[
      HeroBox(children: [
        Row(children: [
          CircleAvatar(radius: 28, backgroundColor: Colors.white24, child: Text(pr.initials, style: display(context, 22, color: Colors.white))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(up(context, '${pr.firstName} ${pr.lastName}'), style: display(context, 26, color: Colors.white)),
            Text(pr.email, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          ])),
        ]),
        statRow([
          StatTile('${pr.age}', t('años'), onHero: true),
          StatTile('${pr.weight}', 'kg', onHero: true),
          StatTile('${pr.height}', 'cm', onHero: true),
          StatTile(kid ? '—' : imc.toStringAsFixed(1), t('IMC'), onHero: true),
        ]),
        if (pr.weights.length > 1) SizedBox(height: 70, child: CustomPaint(size: Size.infinite, painter: _WeightPainter(pr.weights.map((e) => e.kg).toList(), p.acc2))),
        Row(children: [
          Expanded(child: Text(t('{d} kg desde el inicio', {'d': '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)}'}))),
          Btn(t('Actualizar peso'), onTap: () => showSheet(context, (_) => const MonthlySheet())),
        ]),
      ]),
      Box(child: vgap([
        Text(t('Idioma y ubicación'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        Row(children: [
          Expanded(child: Btn(I18n.langs[pr.lang]!.$1, icon: Icons.language_rounded, onTap: () => showSheet(context, (_) => LanguageSheet(onPick: st.setLang)))),
          const SizedBox(width: 10),
          Expanded(child: Btn(placeOf(pr).city, icon: Icons.place_rounded, onTap: () => showSheet(context, (_) => const LocationSheet()))),
        ]),
      ], 8)),
      section(context, t('Rutina'), 'rutina', Text('${pr.routineMinutes} min · ${pr.routineDays.map(I18n.dayName).join(', ')}')),
      section(context, t('Deportes'), 'deportes', pr.sports.isEmpty
          ? Text(t('Sin deportes registrados.'), style: TextStyle(color: p.muted))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: pr.sports.map((s) => Text('${t(s.name)} · ${s.days.map((d) => I18n.dayName(d, short: true)).join(' ')} · ${s.minutes} min · ${t(s.intensity)}')).toList())),
      section(context, t('Objetivos'), 'objetivos', vgap([
        Wrap(spacing: 6, runSpacing: 6, children: bodyParts.where((x) => (pr.parts[x] ?? 'no') != 'no').map((x) => Pill('${t(x)}: ${t(g[pr.parts[x]]!)}')).toList()),
        Text('${t('Dieta')}: ${kid ? t('Crecer sano') : t(dietGoals[pr.dietGoal] ?? '')}'),
      ], 8)),
      section(context, t('Mis equipos'), 'equipos', pr.equipment.isEmpty
          ? Text(t('Solo peso corporal'), style: TextStyle(color: p.muted))
          : Wrap(spacing: 6, runSpacing: 6, children: pr.equipment.map((e) => Pill(t(equipment[e]!), color: p.acc2)).toList())),
      section(context, t('Hábitos'), 'habitos', vgap([
        Text('${t('Sueño')} ${pr.sleep} h · ${pr.water} ${t('vasos de agua')} · ${pr.mealsPerDay} ${t('comidas al día')}'),
        Wrap(spacing: 6, runSpacing: 6, children: pr.habits.map((h) => Pill(t(h))).toList()),
      ], 8)),
      Box(child: vgap([
        Text(t('Reloj o banda'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        if (w.linked && wb != null)
          Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: wb.color, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.watch_rounded, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(w.model ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${wb.app.isEmpty ? t('App de tu reloj') : wb.app} · ${t(routeNames[w.route]!)}', style: TextStyle(color: p.muted, fontSize: 12)),
            ])),
            Pill(t('Conectado'), color: p.ok),
          ])
        else
          Text(t('Sin vincular'), style: TextStyle(color: p.muted)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Btn(w.linked ? t('Cambiar reloj') : t('Elegir mi reloj'), kind: BtnKind.primary, onTap: () => showSheet(context, (_) => const WatchSheet())),
          Btn(t('Ingresar a mano'), onTap: () => showSheet(context, (_) => const ManualDataSheet())),
          if (w.linked) Btn(t('Desvincular'), kind: BtnKind.ghost, onTap: () => st.update(() => pr.watch = WatchLink())),
        ]),
      ], 10)),
      if (kid) const MedalsView(),
      Btn(t('Cerrar sesión'), kind: BtnKind.ghost, onTap: () async {
        await AuthService.signOut();
        await st.signOut();
      }),
    ];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 110), children: [for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 14), children[i]]]);
  }
}

class _WeightPainter extends CustomPainter {
  final List<double> v;
  final Color dot;
  _WeightPainter(this.v, this.dot);
  @override
  void paint(Canvas canvas, Size s) {
    final mn = v.reduce((a, b) => a < b ? a : b) - .5, mx = v.reduce((a, b) => a > b ? a : b) + .5;
    Offset pt(int i) => Offset(8 + i * (s.width - 16) / (v.length - 1), 8 + (s.height - 20) * (1 - (v[i] - mn) / (mx - mn)));
    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < v.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    final fill = Path.from(path)..lineTo(pt(v.length - 1).dx, s.height)..lineTo(8, s.height)..close();
    canvas.drawPath(fill, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white30, Colors.transparent]).createShader(Offset.zero & s));
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = Colors.white..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(pt(v.length - 1), 5, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(covariant _WeightPainter o) => true;
}
