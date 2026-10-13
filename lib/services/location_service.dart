import 'package:geolocator/geolocator.dart';

import '../core/catalog.dart';

class GeoResult {
  final String place;
  final double lat, lng;
  GeoResult(this.place, this.lat, this.lng);
}

/// Ubica al usuario: devuelve sus coordenadas y la ciudad del catálogo más cercana
/// (para moneda y precios de referencia). Los supermercados reales se buscan con StoresService.
class LocationService {
  static Future<GeoResult?> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));
      String best = 'mzl';
      var bestD = double.infinity;
      Catalog.places.forEach((k, pl) {
        final d = Geolocator.distanceBetween(pos.latitude, pos.longitude, pl.lat, pl.lng);
        if (d < bestD) {
          bestD = d;
          best = k;
        }
      });
      return GeoResult(best, pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }
}
