// Lectura del reloj: en Android/iPhone usa Health Connect / Apple Salud;
// en la versión web no hay acceso a esos datos y se usa el ingreso manual.
export 'health_service_web.dart' if (dart.library.io) 'health_service_native.dart';
