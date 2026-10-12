import 'dart:math';

import 'package:flutter/material.dart';

import '../core/catalog.dart';
import '../core/theme.dart';

class Box extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? border, color;
  const Box({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.border, this.color});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: color ?? p.surface, borderRadius: BorderRadius.circular(p.kid ? 22 : 18), border: Border.all(color: border ?? p.line)),
      child: child,
    );
  }
}

/// Tarjeta principal con degradado del color de la marca.
class HeroBox extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment align;
  const HeroBox({super.key, required this.children, this.align = CrossAxisAlignment.start});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: p.kid
            ? const LinearGradient(colors: [Color(0xFFFF6B00), Color(0xFFFF9A3D)], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : LinearGradient(colors: [Color.lerp(p.acc, p.deep, .25)!, p.deep, Color.lerp(p.deep, p.bg, .6)!], begin: Alignment.topRight, end: Alignment.bottomLeft),
      ),
      child: Stack(children: [
        Positioned(right: -50, bottom: -70, child: IgnorePointer(child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .07), width: 28))))),
        Padding(
          padding: const EdgeInsets.all(20),
          child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: Column(crossAxisAlignment: align, children: _gap(children, 14))),
        ),
      ]),
    );
  }
}

List<Widget> _gap(List<Widget> c, double g) => [for (var i = 0; i < c.length; i++) ...[if (i > 0) SizedBox(height: g), c[i]]];
Widget vgap(List<Widget> c, [double g = 12]) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _gap(c, g));

class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  const Eyebrow(this.text, {super.key, this.color});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Text(text.toUpperCase(), style: TextStyle(fontSize: 11.5, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: color ?? (p.kid ? p.deep : p.acc2)));
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color? color;
  const Pill(this.text, {super.key, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? Palette.of(context).acc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: c.withValues(alpha: .18), borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color.lerp(c, Palette.of(context).fg, .35))),
    );
  }
}

enum BtnKind { primary, normal, ok, ghost }

class Btn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final BtnKind kind;
  final IconData? icon;
  final bool expand;
  const Btn(this.label, {super.key, this.onTap, this.kind = BtnKind.normal, this.icon, this.expand = false});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final bg = switch (kind) { BtnKind.primary => p.acc, BtnKind.ok => p.ok, BtnKind.ghost => Colors.transparent, _ => p.raised };
    final fg = switch (kind) { BtnKind.primary => Colors.white, BtnKind.ok => p.kid ? Colors.white : const Color(0xFF06150E), BtnKind.ghost => p.kid ? p.deep : p.acc2, _ => p.fg };
    final shadow = p.kid && kind != BtnKind.ghost ? [BoxShadow(color: kind == BtnKind.primary ? p.deep : kind == BtnKind.ok ? const Color(0xFF146B3B) : p.line, offset: const Offset(0, 4))] : null;
    final child = Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
      Flexible(child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: p.kid ? 16 : 14.5))),
    ]);
    return Opacity(
      opacity: onTap == null ? .45 : 1,
      child: Container(
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(p.kid ? 16 : 14), border: kind == BtnKind.normal ? Border.all(color: p.line) : null, boxShadow: shadow),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13), child: child)),
        ),
      ),
    );
  }
}

class ChoiceChipX extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const ChoiceChipX(this.label, this.on, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(color: on ? p.acc : p.surface, borderRadius: BorderRadius.circular(99), border: Border.all(color: on ? p.acc : p.line)),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: on ? Colors.white : p.fg)),
      ),
    );
  }
}

class Segmented<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  const Segmented({super.key, required this.options, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: p.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.line)),
      child: Row(children: [
        for (final o in options)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(o.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(color: o.$1 == value ? p.acc : Colors.transparent, borderRadius: BorderRadius.circular(11)),
                child: Text(o.$2, textAlign: TextAlign.center, maxLines: 2, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: o.$1 == value ? Colors.white : p.muted)),
              ),
            ),
          ),
      ]),
    );
  }
}

class StatTile extends StatelessWidget {
  final String value, label;
  final IconData? icon;
  final Color? iconColor;
  final bool onHero;
  const StatTile(this.value, this.label, {super.key, this.icon, this.iconColor, this.onHero = false});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: onHero ? Colors.white.withValues(alpha: .1) : p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: onHero ? Colors.white.withValues(alpha: .12) : p.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (icon != null) Icon(icon, size: 18, color: iconColor ?? p.acc),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: display(context, 22, color: onHero ? Colors.white : p.fg))),
        Text(label, maxLines: 2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: onHero ? Colors.white70 : p.muted)),
      ]),
    );
  }
}

Widget statRow(List<Widget> tiles) => Row(children: [for (var i = 0; i < tiles.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: tiles[i])]]);

class ProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final String label;
  const ProgressRing(this.value, {super.key, this.size = 86, required this.label});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox.expand(child: CircularProgressIndicator(value: value.clamp(0, 1), strokeWidth: 9, color: Colors.white, backgroundColor: Colors.white24, strokeCap: StrokeCap.round)),
          Text(label, style: display(context, size * .26, color: Colors.white)),
        ]),
      );
}

/// Foto del ejercicio o, si no hay foto, una ilustración con el músculo resaltado.
class ExerciseImage extends StatelessWidget {
  final Exercise ex;
  final double? width, height;
  final double radius;
  final int frame;
  const ExerciseImage(this.ex, {super.key, this.width, this.height, this.radius = 13, this.frame = 0});
  @override
  Widget build(BuildContext context) {
    final c = partColors[ex.part] ?? const Color(0xFF5563E0);
    final img = ex.hasImage
        ? Image.asset(ex.frame(frame), width: width, height: height, fit: BoxFit.cover, gaplessPlayback: true)
        : Container(
            width: width,
            height: height,
            decoration: BoxDecoration(gradient: LinearGradient(colors: [c, const Color(0xFF0B1120)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: CustomPaint(painter: _BodyPainter(ex.part, c)),
          );
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: img);
  }
}

class _BodyPainter extends CustomPainter {
  final String part;
  final Color color;
  _BodyPainter(this.part, this.color);
  static const _reg = {
    'Hombros': ['sl', 'sr'], 'Pecho': ['ch'], 'Espalda': ['ch', 'ab'], 'Abdomen': ['ab'], 'Bíceps': ['ual', 'uar'], 'Tríceps': ['ual', 'uar'],
    'Antebrazos': ['fal', 'far'], 'Glúteos': ['hp'], 'Piernas': ['thl', 'thr'], 'Pantorrillas': ['cal', 'car'],
  };
  @override
  void paint(Canvas canvas, Size s) {
    final sc = min(s.width / 96, s.height / 66);
    canvas.translate((s.width - 96 * sc) / 2 + 26 * sc, (s.height - 66 * sc) / 2 + sc);
    canvas.scale(sc);
    final all = part == 'Cuerpo completo' || part == 'Cardio';
    final hi = all ? null : _reg[part] ?? const [];
    Paint pnt(String k) => Paint()..color = (all || hi!.contains(k)) ? Colors.white.withValues(alpha: .95) : Colors.white.withValues(alpha: part == 'Estiramiento' ? .5 : .18);
    void rr(String k, double x, double y, double w, double h, double r) => canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)), pnt(k));
    canvas.drawCircle(const Offset(34, 9), 4.6, Paint()..color = Colors.white30);
    canvas.drawCircle(const Offset(25, 17), 3.4, pnt('sl'));
    canvas.drawCircle(const Offset(43, 17), 3.4, pnt('sr'));
    rr('ch', 27.5, 14.5, 13, 8, 3);
    rr('ab', 28.5, 23.5, 11, 9.5, 2.5);
    rr('ual', 20.5, 18, 4.4, 10, 2.2);
    rr('uar', 43.1, 18, 4.4, 10, 2.2);
    rr('fal', 19, 28.6, 3.8, 9.5, 1.9);
    rr('far', 45.2, 28.6, 3.8, 9.5, 1.9);
    rr('hp', 27.5, 33.6, 13, 5.4, 2.5);
    rr('thl', 27.6, 39.6, 6, 12, 2.8);
    rr('thr', 34.4, 39.6, 6, 12, 2.8);
    rr('cal', 28.2, 52.4, 5, 10, 2.4);
    rr('car', 34.8, 52.4, 5, 10, 2.4);
  }

  @override
  bool shouldRepaint(covariant _BodyPainter old) => old.part != part;
}

class Plate extends StatelessWidget {
  final String emoji;
  final double size;
  const Plate(this.emoji, {super.key, this.size = 78});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(center: const Alignment(-.3, -.4), colors: [Color.lerp(p.acc2, p.raised, .6)!, p.raised], stops: const [0, .7]),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 8))],
        border: Border.all(color: Colors.white.withValues(alpha: .06), width: 5),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * .42)),
    );
  }
}

class MacroBar extends StatelessWidget {
  final int p, c, f;
  const MacroBar(this.p, this.c, this.f, {super.key});
  @override
  Widget build(BuildContext context) {
    final pal = Palette.of(context);
    final tot = max(1, p * 4 + c * 4 + f * 9);
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        height: 6,
        child: Row(children: [
          Expanded(flex: (p * 400 / tot).round().clamp(1, 100), child: Container(color: pal.acc)),
          Expanded(flex: (c * 400 / tot).round().clamp(1, 100), child: Container(color: pal.acc2)),
          Expanded(flex: (f * 900 / tot).round().clamp(1, 100), child: Container(color: pal.ok)),
        ]),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: Text(up(context, title), style: display(context, 24))),
        if (trailing != null) trailing!,
      ]);
}

Future<T?> showSheet<T>(BuildContext context, Widget Function(BuildContext) builder) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .85,
        maxChildSize: .95,
        builder: (c, sc) => SingleChildScrollView(controller: sc, padding: const EdgeInsets.fromLTRB(16, 0, 16, 28), child: builder(c)),
      ),
    );
