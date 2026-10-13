import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../core/models.dart';

/// Busca supermercados reales cerca del usuario usando OpenStreetMap (servicio Overpass, gratuito).
/// Para cada uno guarda su página web cuando existe, para consultar ahí los precios reales.
class StoresService {
  /// Cadenas conocidas: dominio de su tienda en línea y factor de precio relativo (estimado).
  static const known = <String, (String, double)>{
    'd1': ('domicilios.tiendasd1.com', .82), 'ara': ('aratiendas.com', .86), 'exito': ('exito.com', 1), 'carulla': ('carulla.com', 1.12),
    'jumbo': ('tiendasjumbo.co', 1.03), 'olimpica': ('olimpica.com', .95), 'euro': ('eurosupermercados.com.co', 1.08), 'makro': ('makro.com.co', .9),
    'pricesmart': ('pricesmart.com', .95), 'colsubsidio': ('colsubsidio.com', .97), 'surtimax': ('surtimax.com.co', .9), 'isimo': ('isimo.com.co', .92),
    'mercadona': ('tienda.mercadona.es', .92), 'lidl': ('lidl.es', .85), 'dia': ('dia.es', .88), 'alcampo': ('alcampo.es', .95), 'eroski': ('supermercado.eroski.es', .98),
    'el corte ingles': ('elcorteingles.es', 1.25), 'walmart': ('walmart.com', .88), 'aldi': ('aldi.us', .8), 'target': ('target.com', .97), 'publix': ('publix.com', 1.05),
    'whole foods': ('wholefoodsmarket.com', 1.3), 'kroger': ('kroger.com', .95), 'soriana': ('soriana.com', .95), 'chedraui': ('chedraui.com.mx', .93),
    'bodega aurrera': ('despensa.bodegaaurrera.com.mx', .85), 'la comer': ('lacomer.com.mx', 1.1), 'heb': ('heb.com.mx', .97), 'carrefour': ('carrefour.com', 1),
    'pao de acucar': ('paodeacucar.com', 1.15), 'atacadao': ('atacadao.com.br', .82), 'assai': ('assai.com.br', .85), 'tottus': ('tottus.com.pe', .92),
    'plaza vea': ('plazavea.com.pe', .95), 'wong': ('wong.pe', 1.1), 'lider': ('lider.cl', .92), 'jumbo cl': ('jumbo.cl', 1.03), 'coto': ('cotodigital3.com.ar', .95),
  };

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áàä]'), 'a')
      .replaceAll(RegExp('[éèë]'), 'e')
      .replaceAll(RegExp('[íìï]'), 'i')
      .replaceAll(RegExp('[óòö]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll('ã', 'a')
      .replaceAll('ç', 'c');

  static (String, double)? _match(String name) {
    final n = _norm(name);
    for (final e in known.entries) {
      if (RegExp('(^|[^a-z0-9])${RegExp.escape(e.key)}([^a-z0-9]|\$)').hasMatch(n)) return e.value;
    }
    return null;
  }

  /// Supermercados en un radio de 5 km, ordenados por distancia (máximo 12, uno por cadena).
  static Future<List<NearbyStore>> nearby(double lat, double lng, {int radius = 5000}) async {
    final q = '[out:json][timeout:25];(node["shop"="supermarket"](around:$radius,$lat,$lng);way["shop"="supermarket"](around:$radius,$lat,$lng););out center tags 80;';
    final res = await http.post(Uri.parse('https://overpass-api.de/api/interpreter'), body: {'data': q}).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw Exception('Overpass ${res.statusCode}');
    final els = (json.decode(utf8.decode(res.bodyBytes))['elements'] as List?) ?? [];
    final out = <NearbyStore>[];
    final seen = <String>{};
    final rows = <(double, Map)>[];
    for (final e in els) {
      final tags = (e['tags'] ?? {}) as Map;
      final la = (e['lat'] ?? e['center']?['lat']) as num?;
      final lo = (e['lon'] ?? e['center']?['lon']) as num?;
      if (la == null || lo == null || (tags['name'] == null && tags['brand'] == null)) continue;
      rows.add((Geolocator.distanceBetween(lat, lng, la.toDouble(), lo.toDouble()) / 1000, tags));
    }
    rows.sort((a, b) => a.$1.compareTo(b.$1));
    for (final r in rows) {
      final tags = r.$2;
      final name = (tags['brand'] ?? tags['name']).toString();
      final key = _norm(name);
      if (seen.contains(key)) continue;
      seen.add(key);
      final m = _match(name);
      var web = (tags['website'] ?? tags['contact:website'] ?? tags['brand:website'] ?? '').toString();
      if (web.isEmpty && m != null) web = m.$1;
      web = web.replaceFirst(RegExp(r'^https?://'), '').replaceFirst(RegExp(r'^www\.'), '').split('/').first;
      out.add(NearbyStore(name: name, km: double.parse(r.$1.toStringAsFixed(1)), website: web, priceFactor: m?.$2 ?? 1));
      if (out.length >= 12) break;
    }
    return out;
  }

  /// Enlace para ver el precio real de un ingrediente en la web del supermercado.
  static Uri priceSearch(String ingredient, NearbyStore s) {
    final clean = ingredient.replaceAll(RegExp(r'^[\d½⅓¼¾.,/]+\s*(g|kg|ml|l|cda|cdas|cdta|taza|tazas|lata|unidad(es)?)?\s*(de\s+)?', caseSensitive: false), '').replaceAll(RegExp(r'\(.*?\)'), '').trim();
    final q = s.website.isNotEmpty ? '$clean precio site:${s.website}' : '$clean precio ${s.name}';
    return Uri.parse('https://www.google.com/search?q=${Uri.encodeComponent(q)}');
  }
}
