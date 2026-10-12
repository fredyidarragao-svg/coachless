import 'package:geolocator/geolocator.dart';

import '../core/catalog.dart';

/// Ubica al usuario y elige la ciudad del catálogo más cercana (con sus supermercados y moneda).
/// En la fase con servidor, los supermercados vendrán de un servicio de mapas según las coordenadas exactas.
class LocationService {
  static Future<String?> nearestPlace() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));
      String? best;
      var bestD = double.infinity;
      Catalog.places.forEach((k, pl) {
        final d = Geolocator.distanceBetween(pos.latitude, pos.longitude, pl.lat, pl.lng);
        if (d < bestD) {
          bestD = d;
          best = k;
        }
      });
      return best;
    } catch (_) {
      return null;
    }
  }
}
