import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
class QuranService {
  static Future<Map<String,
  dynamic>>? _bundled;
  static final Map<String,
  Future<Map<String,
  dynamic>>> _pending = {
  };
  Future<Map<String,
  dynamic>> get bundled => _bundled ??= rootBundle .loadString('assets/data/content.json') .then((s) => jsonDecode(s) as Map<String,
  dynamic>);
  Future<Directory> get directory async {
    final d = Directory('${(await getApplicationSupportDirectory()).path}/cache');
    await d.create(recursive: true);
    return d;
  } Future<Map<String,
  dynamic>> fetch(String path) async {
    if (_pending.containsKey(path)) {
      return _pending[path]!;
    } final task = _fetch(path);
    _pending[path] = task;
    try {
      return await task;
    } finally {
      _pending.remove(path);
    }
  } Future<Map<String,
  dynamic>> _fetch(String path) async {
    final file = File('${(await directory).path}/${path.replaceAll('/', '_')}.json');
    if (await file.exists()) {
      try {
        return jsonDecode(await file.readAsString()) as Map<String,
        dynamic>;
      } on FormatException {
        await file.delete();
      }
    } if (path.startsWith('surah/')) {
      final n = int.parse(path.split('/').last);
      final data = await bundled;
      final texts = (data['texts'] as Map)['$n'] as List?;
      if (texts != null) {
        const pages = {
          1: 1,
          103: 601,
          108: 602,
          112: 604,
          113: 604,
          114: 604
        };
        return {
          'number': n,
          'ayahs': List.generate(texts.length,
          (i) => {
            'text': texts[i],
            'numberInSurah': i + 1,
            'page': pages[n],
            'juz': n == 1 ? 1 : 30,
            'surah': {
              'number': n,
              'name': (data['names'] as List)[n - 1]
            },
          }),
        };
      }
    } final r = await http.get(Uri.https('api.alquran.cloud',
    '/v1/$path/quran-uthmani')) .timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) {
      throw Exception('تعذر تحميل القرآن (${r.statusCode})');
    } final j = jsonDecode(r.body) as Map<String,
    dynamic>;
    if (j['code'] != 200 || j['data'] is! Map) {
      throw const FormatException('استجابة غير صالحة');
    } final data = Map<String,
    dynamic>.from(j['data'] as Map);
    final ayahs = data['ayahs'];
    if (ayahs is! List || ayahs.isEmpty || ayahs.any((a) => a is! Map || a['text'] is! String || (a['text'] as String).trim().isEmpty)) {
      throw const FormatException('نص الآيات غير صالح');
    } if (path.startsWith('surah/')) {
      final n = int.parse(path.split('/').last);
      if (ayahs.length != ((await bundled)['counts'] as List)[n - 1]) {
        throw const FormatException('عدد آيات السورة غير مطابق');
      }
    } final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(data));
    await tmp.rename(file.path);
    return data;
  } Future<String> resolve(dynamic part) async {
    if (part is String) {
      return part;
    } if (part is List) {
      return (await Future.wait(part.map(resolve))).join('\n');
    } if (part is Map && part['q'] is List) {
      final q = part['q'] as List;
      final data = await bundled;
      final texts = (data['texts'] as Map)['${q[0]}'] as List?;
      final verses = (data['verses'] as Map)['${q[0]}'] as Map? ?? {
      };
      final local = <String>[];
      for (var i = q[1] as int; i <= (q[2] as int); i++) {
        final t = texts != null && i <= texts.length ? texts[i - 1] : verses['$i'];
        if (t is! String) {
          local.clear();
          break;
        } local.add(t);
      } if (local.isNotEmpty) {
        return local.join(' ');
      } final s = await fetch('surah/${q[0]}');
      return (s['ayahs'] as List).sublist((q[1] as int) - 1,
      q[2] as int) .map((e) => e['text']).join(' ');
    } return '';
  } Future<String> downloadAudio(String key,
  String url) async {
    if (!RegExp(r'^[A-Za-z0-9_\-]+$').hasMatch(key)) {
      throw const FormatException('اسم الملف غير صالح');
    } final f = File('${(await directory).path}/$key.mp3');
    if (!await f.exists()) {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(minutes: 3));
      final b = r.bodyBytes;
      final id3 = b.length > 3 && b[0] == 0x49 && b[1] == 0x44 && b[2] == 0x33;
      final mpeg = b.length > 2 && b[0] == 0xff && (b[1] & 0xe0) == 0xe0;
      if (r.statusCode != 200 || b.length < 128 || (!id3 && !mpeg)) {
        throw Exception('الرابط لم يُرجع ملف MP3 صالحاً');
      } final tmp = File('${f.path}.tmp');
      await tmp.writeAsBytes(b);
      await tmp.rename(f.path);
    } return f.path;
  }
}
