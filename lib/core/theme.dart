import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta por perfil: hombre (azul cobalto profundo), mujer (frambuesa profunda), niños (claro y lúdico).
class Palette extends ThemeExtension<Palette> {
  final Color bg, bg2, surface, raised, line, fg, muted, acc, acc2, deep, ok, bad;
  final bool kid;
  const Palette({required this.bg, required this.bg2, required this.surface, required this.raised, required this.line, required this.fg, required this.muted, required this.acc, required this.acc2, required this.deep, required this.ok, required this.bad, required this.kid});

  static const male = Palette(bg: Color(0xFF080D19), bg2: Color(0xFF0D1426), surface: Color(0xFF121A30), raised: Color(0xFF19233F), line: Color(0xFF24304F), fg: Color(0xFFEEF2FB), muted: Color(0xFF8C98B6), acc: Color(0xFF3D6BFF), acc2: Color(0xFFFFB547), deep: Color(0xFF152C8C), ok: Color(0xFF2FD08A), bad: Color(0xFFFF6B6B), kid: false);
  static const female = Palette(bg: Color(0xFF12080F), bg2: Color(0xFF190B15), surface: Color(0xFF22111D), raised: Color(0xFF2D1827), line: Color(0xFF42243A), fg: Color(0xFFF9EEF4), muted: Color(0xFFBE97AE), acc: Color(0xFFE2427B), acc2: Color(0xFFF3B79E), deep: Color(0xFF7A1840), ok: Color(0xFF2FD08A), bad: Color(0xFFFF6B6B), kid: false);
  static const child = Palette(bg: Color(0xFFFFF6E5), bg2: Color(0xFFFFEBC7), surface: Color(0xFFFFFFFF), raised: Color(0xFFFFF4DE), line: Color(0xFFF0DAB0), fg: Color(0xFF2B1C0C), muted: Color(0xFF7A6247), acc: Color(0xFFFF6B00), acc2: Color(0xFF169FE0), deep: Color(0xFFD25400), ok: Color(0xFF1E9E57), bad: Color(0xFFD63C3C), kid: true);

  static Palette of(BuildContext c) => Theme.of(c).extension<Palette>()!;
  static Palette forTheme(String t) => t == 'k' ? child : t == 'f' ? female : male;

  @override
  Palette copyWith() => this;
  @override
  Palette lerp(ThemeExtension<Palette>? other, double tt) => (tt < .5 || other is! Palette) ? this : other;
}

ThemeData buildTheme(String themeKey) {
  final p = Palette.forTheme(themeKey);
  final base = p.kid ? ThemeData.light(useMaterial3: true) : ThemeData.dark(useMaterial3: true);
  final body = p.kid ? GoogleFonts.baloo2TextTheme(base.textTheme) : GoogleFonts.figtreeTextTheme(base.textTheme);
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    colorScheme: (p.kid ? const ColorScheme.light() : const ColorScheme.dark()).copyWith(primary: p.acc, secondary: p.acc2, surface: p.surface, onSurface: p.fg, error: p.bad),
    textTheme: body.apply(bodyColor: p.fg, displayColor: p.fg),
    extensions: [p],
    dividerColor: p.line,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.bg2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.acc, width: 2)),
      labelStyle: TextStyle(color: p.muted),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.bg2, showDragHandle: true, dragHandleColor: p.line),
  );
}

/// Títulos grandes estilo deportivo (en modo niños, redondeados).
TextStyle display(BuildContext c, double size, {Color? color}) {
  final p = Palette.of(c);
  return p.kid
      ? GoogleFonts.baloo2(fontSize: size, fontWeight: FontWeight.w800, color: color ?? p.fg, height: 1.05)
      : GoogleFonts.barlowCondensed(fontSize: size, fontWeight: FontWeight.w800, color: color ?? p.fg, height: 1.0, letterSpacing: .2);
}

String up(BuildContext c, String s) => Palette.of(c).kid ? s : s.toUpperCase();
