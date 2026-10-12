import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Idiomas soportados. La clave de cada texto es la frase en español;
/// los archivos assets/i18n/{en,pt,fr}.json traen la traducción.
class I18n {
  static const langs = {
    'es': ('Español', 'es_CO'),
    'en': ('English', 'en_US'),
    'pt': ('Português', 'pt_BR'),
    'fr': ('Français', 'fr_FR'),
  };

  static final Map<String, Map<String, String>> _dicts = {};
  static String lang = 'es';

  static Future<void> load() async {
    for (final l in ['en', 'pt', 'fr']) {
      final raw = await rootBundle.loadString('assets/i18n/$l.json');
      _dicts[l] = Map<String, String>.from(json.decode(raw) as Map);
    }
  }

  static String get locale => langs[lang]?.$2 ?? 'es_CO';

  /// Traduce una frase en español; `vars` reemplaza {nombre} dentro del texto.
  static String t(String es, [Map<String, Object?>? vars]) {
    var out = lang == 'es' ? es : (_dicts[lang]?[es] ?? es);
    vars?.forEach((k, v) => out = out.replaceAll('{$k}', '$v'));
    return out;
  }

  static String num(num n) => NumberFormat.decimalPattern(locale).format(n);

  /// Nombre del día: 0 = lunes … 6 = domingo.
  static String dayName(int i, {bool short = false}) {
    final d = DateTime(2024, 1, 1 + i); // 1 ene 2024 fue lunes
    final s = DateFormat(short ? 'EEE' : 'EEEE', locale).format(d);
    return s[0].toUpperCase() + s.substring(1);
  }

  static String dateLong(DateTime d) {
    final s = DateFormat('EEEE d MMM', locale).format(d);
    return s[0].toUpperCase() + s.substring(1);
  }
}

String t(String es, [Map<String, Object?>? vars]) => I18n.t(es, vars);
