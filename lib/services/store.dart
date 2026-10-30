import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/content.dart';
class Store extends ChangeNotifier {
  late SharedPreferences prefs;
  Map<String,
  dynamic> data = {
  };
  late Map<String,
  dynamic> content;
  late Map<String,
  dynamic> audio;
  List<Wird> groups = [];
  List<String> get names => List<String>.from(content['names'] as List);
  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    data = jsonDecode(prefs.getString('awrad_flutter') ?? '{}') as Map<String,
    dynamic>;
    content = jsonDecode(await rootBundle.loadString('assets/data/content.json')) as Map<String,
    dynamic>;
    audio = jsonDecode(await rootBundle.loadString('assets/data/audio.json')) as Map<String,
    dynamic>;
    rebuild();
  } void rebuild() {
    groups = [...(content['groups'] as List),
    ...(data['custom'] as List? ?? [])] .map((e) => Wird.fromJson(List<dynamic>.from(e as List))).toList();
    final extras = data['extras'] as Map? ?? {
    };
    for (final g in groups) {
      for (final e in extras[g.id] as List? ?? []) {
        g.items.add(Dhikr.fromJson(List<dynamic>.from(e as List)));
      }
    }
  } T get<T>(String key,
  T fallback) => data[key] is T ? data[key] as T : fallback;
  Future<void> set(String key,
  dynamic value) async {
    data[key] = value;
    await save();
  } Future<void> save() async {
    await prefs.setString('awrad_flutter',
    jsonEncode(data));
    notifyListeners();
  } bool favorite(String id) => (data['favorites'] as List? ?? []).contains(id);
  void toggle(String id) {
    final list=List<String>.from(data['favorites'] as List? ?? []);
    list.contains(id) ? list.remove(id) : list.add(id);
    set('favorites',
    list);
  } Future<void> addWird(String name,
  String text,
  int count) async {
    final list=List<dynamic>.from(data['custom'] as List? ?? []);
    list.add(Wird('custom${DateTime.now().millisecondsSinceEpoch}',
    name,
    'ورد خاص',
    [Dhikr(text,
    count,
    '')]).toJson());
    data['custom']=list;
    rebuild();
    await save();
  }
}
