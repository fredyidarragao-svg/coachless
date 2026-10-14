/// Qué métricas llegaron en la última lectura del reloj (para explicar al usuario qué falta).
class HealthReport {
  final bool steps, heart, calories, sleep, permissions;
  const HealthReport({this.steps = false, this.heart = false, this.calories = false, this.sleep = false, this.permissions = true});
  bool get complete => steps && heart && calories && sleep;
  List<String> get missing => [
        if (!heart) 'pulso',
        if (!calories) 'calorías',
        if (!sleep) 'sueño',
        if (!steps) 'pasos',
      ];
}
