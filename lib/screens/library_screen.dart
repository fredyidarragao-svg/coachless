import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/catalog.dart';
import '../core/engine.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import 'sheets.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String lib = 'mancuernas';
  String q = '';

  @override
  Widget build(BuildContext context) {
    final pr = context.watch<AppState>().profile!;
    final p = Palette.of(context);
    final query = q.trim().toLowerCase();
    final children = <Widget>[
      Eyebrow(t('Biblioteca')),
      Text(up(context, t('{a} ejercicios · {b} recetas', {'a': Catalog.exercises.length, 'b': Catalog.foods.length})), style: display(context, 32)),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.6,
        children: [
          for (final k in libraries.keys.where((k) => k != 'comidas')) _CategoryTile(k, on: lib == k, onTap: () => setState(() => lib = k)),
        ],
      ),
      GestureDetector(
        onTap: () => setState(() => lib = 'comidas'),
        child: Container(
          height: 92,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: lib == 'comidas' ? p.acc : p.line, width: 2),
            gradient: LinearGradient(colors: [p.surface, Color.lerp(p.acc2, p.raised, .65)!]),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(up(context, t('Comida sana')), style: display(context, 22)),
              Text('${Catalog.foods.length} ${t('recetas')}', style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w700)),
            ])),
            const Plate('🥗', size: 54), const SizedBox(width: 6), const Plate('🍗', size: 54), const SizedBox(width: 6), const Plate('🥑', size: 54),
          ]),
        ),
      ),
      TextField(decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: t('Buscar en {x}', {'x': t(libraries[lib]!).toLowerCase()})), onChanged: (v) => setState(() => q = v)),
    ];

    if (lib == 'comidas') {
      final sm = storeOf(pr).priceFactor;
      for (final s in ['desayuno', 'snack', 'almuerzo', 'cena']) {
        final fs = Catalog.foods.where((f) => f.slot == s && (query.isEmpty || f.name.toLowerCase().contains(query))).toList();
        if (fs.isEmpty) continue;
        children.add(SectionTitle(t({'desayuno': 'Desayunos', 'snack': 'Media mañana y meriendas', 'almuerzo': 'Almuerzos', 'cena': 'Cenas'}[s]!), trailing: Text('${fs.length}', style: TextStyle(color: p.muted))));
        children.add(SizedBox(
          height: 228,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: fs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final f = fs[i];
              return GestureDetector(
                onTap: () => showSheet(context, (_) => FoodSheet(f)),
                child: Container(
                  width: 170,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.line)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(height: 112, alignment: Alignment.center, color: Color.lerp(p.acc2, p.raised, .7), child: Plate(f.emoji)),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(f.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        const SizedBox(height: 4),
                        Text('${f.kcal} kcal · ${f.protein} g ${t('prot')}', style: TextStyle(color: p.muted, fontSize: 11.5)),
                        const SizedBox(height: 4),
                        Pill(money(f.costCop * sm, pr), color: p.acc2),
                      ]),
                    ),
                  ]),
                ),
              );
            },
          ),
        ));
      }
    } else {
      final byEq = const ['abd', 'cardio', 'maquinas'].contains(lib);
      final items = Catalog.exercises.where((e) => e.lib == lib && (query.isEmpty || e.name.toLowerCase().contains(query))).toList();
      if (items.isEmpty) {
        children.add(Box(child: Text(t('No hay ejercicios con ese nombre. Prueba otra palabra.'), style: TextStyle(color: p.muted))));
      } else if (query.isNotEmpty) {
        children.add(GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: .78,
          children: items.map((e) => _ExerciseTile(e, byEq: byEq)).toList(),
        ));
      } else {
        final groups = <String, List<Exercise>>{};
        for (final e in items) {
          groups.putIfAbsent(byEq ? equipment[e.eq]! : e.part, () => []).add(e);
        }
        groups.forEach((g, es) {
          children.add(SectionTitle(t(g), trailing: Text('${es.length}', style: TextStyle(color: p.muted))));
          children.add(SizedBox(
            height: 214,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: es.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => SizedBox(width: 156, child: _ExerciseTile(es[i], byEq: byEq)),
            ),
          ));
        });
      }
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 110), children: [for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 14), children[i]]]);
  }
}

class _CategoryTile extends StatelessWidget {
  final String k;
  final bool on;
  final VoidCallback onTap;
  const _CategoryTile(this.k, {required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final cover = Catalog.exercises.firstWhere((e) => e.lib == k && e.hasImage, orElse: () => Catalog.exercises.firstWhere((e) => e.lib == k));
    final n = Catalog.exercises.where((e) => e.lib == k).length;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: on ? p.acc : Colors.transparent, width: 2)),
        child: Stack(fit: StackFit.expand, children: [
          ExerciseImage(cover, radius: 0),
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xD0000000), Color(0x10000000)]))),
          Positioned(
            left: 12,
            right: 8,
            bottom: 10,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t(libraries[k]!).toUpperCase(), maxLines: 2, style: display(context, 18, color: Colors.white)),
              Text('$n ${t('ejercicios')}', style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final Exercise e;
  final bool byEq;
  const _ExerciseTile(this.e, {required this.byEq});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return GestureDetector(
      onTap: () => showSheet(context, (_) => ExerciseSheet(e)),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ExerciseImage(e, width: double.infinity, height: 112, radius: 0),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(height: 6),
              Row(children: [
                for (var i = 1; i <= 3; i++) Container(width: 14, height: 4, margin: const EdgeInsets.only(right: 3), decoration: BoxDecoration(color: i <= e.level ? p.acc2 : p.line, borderRadius: BorderRadius.circular(2))),
                const Spacer(),
                Flexible(child: Text(byEq ? t(e.part) : t(equipment[e.eq]!), overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 11))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
