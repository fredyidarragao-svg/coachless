import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'i18n.dart';

class Exercise {
  final String id, lib, eq, part, es, en, img, flag;
  final int level;
  const Exercise({required this.id, required this.lib, required this.eq, required this.part, required this.es, required this.en, required this.img, required this.level, required this.flag});
  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
      id: j['id'], lib: j['lib'], eq: j['eq'], part: j['part'], es: j['es'], en: j['en'],
      img: j['img'] ?? '', level: j['level'] ?? 1, flag: j['flag'] ?? '');
  String get name => I18n.lang == 'es' ? es : en;
  bool get hasImage => img.isNotEmpty;
  String frame(int i) => 'assets/exercises/${img}_$i.jpg';
}

class Food {
  final String id, slot, emoji, es, en, tags;
  final int kcal, protein, carbs, fat, costCop, minutes;
  final List<String> ingredients, steps;
  const Food({required this.id, required this.slot, required this.emoji, required this.es, required this.en, required this.kcal, required this.protein, required this.carbs, required this.fat, required this.costCop, required this.tags, required this.minutes, required this.ingredients, required this.steps});
  factory Food.fromJson(Map<String, dynamic> j) => Food(
      id: j['id'], slot: j['slot'], emoji: j['emoji'], es: j['es'], en: j['en'], kcal: j['kcal'], protein: j['protein'],
      carbs: j['carbs'], fat: j['fat'], costCop: j['costCop'], tags: j['tags'], minutes: j['minutes'],
      ingredients: List<String>.from(j['ingredients']), steps: List<String>.from(j['steps']));
  String get name => I18n.lang == 'es' ? es : en;
  bool has(String tag) => tags.contains(tag);
}

class WatchBrand {
  final String brand, app;
  final Color color;
  final List<String> routes, models;
  const WatchBrand(this.brand, this.color, this.app, this.routes, this.models);
}

class Store {
  final String name;
  final double priceFactor, km;
  final Color color;
  const Store(this.name, this.priceFactor, this.km, this.color);
}

class Place {
  final String key, city, country, currency;
  final double rate, lat, lng;
  final List<Store> stores;
  const Place(this.key, this.city, this.country, this.currency, this.rate, this.lat, this.lng, this.stores);
  Store get cheapest => (List<Store>.from(stores)..sort((a, b) => a.priceFactor.compareTo(b.priceFactor))).first;
  List<Store> get byDistance => List<Store>.from(stores)..sort((a, b) => a.km.compareTo(b.km));
}

Color hex(String h) => Color(int.parse('FF${h.replaceAll('#', '')}', radix: 16));

/// Catálogos estáticos de la app (ejercicios, recetas, relojes y ciudades).
/// En la versión con servidor se reemplazan por datos descargados.
class Catalog {
  static late List<Exercise> exercises;
  static late Map<String, Exercise> exById;
  static late List<Food> foods;
  static late Map<String, Food> foodById;
  static late List<WatchBrand> watches;
  static late Map<String, Place> places;

  static Future<void> load() async {
    final ex = json.decode(await rootBundle.loadString('assets/data/exercises.json')) as List;
    exercises = ex.map((e) => Exercise.fromJson(e)).toList();
    exById = {for (final e in exercises) e.id: e};
    final fd = json.decode(await rootBundle.loadString('assets/data/foods.json')) as List;
    foods = fd.map((e) => Food.fromJson(e)).toList();
    foodById = {for (final f in foods) f.id: f};
    final cat = json.decode(await rootBundle.loadString('assets/data/catalogs.json')) as Map<String, dynamic>;
    watches = (cat['watches'] as List)
        .map((w) => WatchBrand(w['brand'], hex(w['color']), w['app'], List<String>.from(w['routes']), List<String>.from(w['models'])))
        .toList();
    places = (cat['locations'] as Map<String, dynamic>).map((k, v) => MapEntry(
        k,
        Place(k, v['city'], v['country'], v['currency'], (v['rate'] as num).toDouble(), (v['lat'] as num).toDouble(), (v['lng'] as num).toDouble(),
            (v['stores'] as List).map((s) => Store(s[0], (s[1] as num).toDouble(), (s[2] as num).toDouble(), hex(s[3]))).toList())));
  }

  static WatchBrand? brand(String? b) => watches.where((w) => w.brand == b).firstOrNull;
}

/// Catálogos de opciones (la clave interna es el texto en español).
const equipment = {
  'mancuernas': 'Mancuernas', 'barra': 'Barra y discos', 'banco': 'Banco', 'rueda': 'Rueda abdominal', 'barrafija': 'Barra de dominadas',
  'bici': 'Bicicleta estática', 'eliptica': 'Elíptica', 'caminadora': 'Caminadora', 'remo': 'Máquina de remo', 'cuerda': 'Cuerda para saltar',
  'kettlebell': 'Kettlebell', 'bandas': 'Bandas elásticas', 'fitball': 'Fitball', 'balon': 'Balón medicinal', 'step': 'Step',
  'trx': 'TRX / suspensión', 'paralelas': 'Paralelas', 'gym': 'Gimnasio (poleas y máquinas)', 'ninguno': 'Sin equipo',
};
const bodyParts = ['Pecho', 'Espalda', 'Hombros', 'Brazos', 'Abdomen', 'Piernas', 'Glúteos', 'Pantorrillas'];
const goals = {'no': 'No', 'masa': 'Ganar masa', 'tonificar': 'Tonificar', 'disminuir': 'Disminuir'};
const kidGoals = {'no': 'No', 'masa': 'Fuerza', 'tonificar': 'Agilidad', 'disminuir': 'Resistencia'};
const dietGoals = {'perder': 'Bajar de peso', 'mantener': 'Mantener peso', 'ganar': 'Subir de peso', 'masa': 'Ganar masa muscular'};
const sports = ['Fútbol', 'Patinaje', 'Natación', 'Ciclismo', 'Running', 'Baloncesto', 'Tenis', 'Voleibol', 'Baile', 'Yoga', 'Artes marciales', 'Caminata', 'Gimnasio', 'Otro'];
const habits = ['Trabajo sentado', 'Trabajo de pie o activo', 'Desayuno todos los días', 'Como fuera de casa seguido', 'Tomo bebidas azucaradas', 'Consumo alcohol los fines de semana', 'Fumo', 'Me acuesto tarde', 'Estrés alto', 'Picoteo entre comidas'];
const libraries = {'mancuernas': 'Mancuernas', 'barra': 'Barra', 'abd': 'Abdominales', 'cardio': 'Calentamiento y quema', 'corporal': 'Sin equipo', 'maquinas': 'Máquinas y otros', 'comidas': 'Comida sana'};
const levels = ['', 'Principiante', 'Intermedio', 'Avanzado'];
const slotNames = {'desayuno': 'Desayuno', 'media': 'Media mañana', 'almuerzo': 'Almuerzo', 'onces': 'Merienda', 'cena': 'Cena'};
const slotType = {'desayuno': 'desayuno', 'media': 'snack', 'almuerzo': 'almuerzo', 'onces': 'snack', 'cena': 'cena'};
const routeNames = {'hc': 'Health Connect (Android)', 'hk': 'Apple Salud (iPhone)', 'api': 'Cuenta del fabricante'};
const intensities = ['Baja', 'Media', 'Alta'];
const skipReasons = ['Sin tiempo', 'Cansancio', 'Dolor o molestia', 'Enfermedad', 'Viaje', 'Otro motivo'];
const partColors = {
  'Pecho': Color(0xFFE24A55), 'Espalda': Color(0xFF3B7BEA), 'Hombros': Color(0xFF8E5BE8), 'Bíceps': Color(0xFFE57A2B), 'Tríceps': Color(0xFFD9A21B),
  'Antebrazos': Color(0xFFA07A40), 'Piernas': Color(0xFF21A56B), 'Glúteos': Color(0xFFDB4B91), 'Pantorrillas': Color(0xFF1EA8B8), 'Abdomen': Color(0xFFEE6A2E),
  'Cuerpo completo': Color(0xFF5563E0), 'Cardio': Color(0xFFE5443F), 'Estiramiento': Color(0xFF36A89F),
};
const tips = {
  'mancuernas': 'Controla la bajada en 2–3 segundos. Elige un peso con el que las dos últimas repeticiones cuesten, sin perder la técnica.',
  'barra': 'Calienta con la barra sola antes de cargar discos. Espalda neutra y abdomen firme; en press usa topes de seguridad o un compañero.',
  'abd': 'Exhala al contraer. Mantén la zona lumbar pegada al suelo cuando el ejercicio lo permita y no jales el cuello.',
  'cardio': 'Zona 2: puedes hablar en frases cortas. Intervalos: esfuerzo alto pero sostenible; recupera antes de repetir.',
  'corporal': 'Usa el rango completo de movimiento. Cuando hagas más de 20 repeticiones con facilidad, pasa a la variante más difícil.',
  'maquinas': 'Ajusta asiento y apoyos antes de empezar para que la articulación quede alineada con el eje de la máquina o el anclaje.',
  'stretch': 'Mantén la posición sin rebotes y respira lento. Debe sentirse tensión, nunca dolor.',
};
