import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:awrad_almuslim/models/content.dart';
import 'package:awrad_almuslim/services/store.dart';
import 'package:awrad_almuslim/services/quran.dart';
import 'package:shared_preferences/shared_preferences.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all original groups and Quran references survive extraction',
  ()async{
    final content=jsonDecode(await rootBundle.loadString('assets/data/content.json')) as Map;
    final groups=(content['groups'] as List).map((e)=>Wird.fromJson(List<dynamic>.from(e as List))).toList();
    expect(groups.length,
    150);
    expect(groups.fold<int>(0,
    (n,
    g)=>n+g.items.length),
    912);
    expect(groups.map((g)=>g.id).toSet().length,
    groups.length);
    expect(content['names'],
    hasLength(114));
    expect(content['counts'],
    hasLength(114));
    void validate(dynamic p){
      if(p is String){
        expect(p.trim(),
        isNotEmpty);
        return;
      } if(p is List){
        for(final e in p){
          validate(e);
        }return;
      } expect(p,
      isA<Map>());
      final q=(p as Map)['q'] as List;
      expect(q[0],
      inInclusiveRange(1,
      114));
      expect(q[1],
      inInclusiveRange(1,
      (content['counts'] as List)[(q[0] as int)-1] as int));
      expect(q[2],
      inInclusiveRange(q[1] as int,
      (content['counts'] as List)[(q[0] as int)-1] as int));
    } for(final g in groups){
      for(final d in g.items){
        expect(d.repeat,
        greaterThan(0));
        validate(d.parts);
      }
    } expect(groups.where((g)=>RegExp(r'^dl[1-7]$').hasMatch(g.id)),
    hasLength(7));
  });
  test('custom content favorites and counters persist through reload',
  ()async{
    SharedPreferences.setMockInitialValues({
    });
    final s=Store();
    await s.load();
    await s.addWird('وردي',
    'سبحان الله',
    33);
    final id=s.groups.last.id;
    s.toggle(id);
    await s.set('counter_test',
    17);
    final restored=Store();
    await restored.load();
    expect(restored.groups.last.title,
    'وردي');
    expect(restored.groups.last.items.single.repeat,
    33);
    expect(restored.favorite(id),
    isTrue);
    expect(restored.get<int>('counter_test',
    0),
    17);
  });
  test('bundled Quran references resolve without network or platform storage',()async{
    final q=QuranService();
    final text=await q.resolve({'q':[112,1,4]});
    expect(text,contains('أَحَد'));
    final verse=await q.resolve({'q':[2,255,255]});
    expect(verse,contains('الْحَيُّ'));
    expect(await q.resolve(['بسم الله',{'q':[103,1,3]}]),contains('بسم الله'));
  });
  test('Arabic search ignores vocalization and alef forms',
  (){
    expect(normalize('أَذْكَار الصَّبَاح'),
    normalize('اذكار الصباح'));
    expect(ar(604),
    '٦٠٤');
  });
  test('khatma distributes remaining pages without omitting final pages',
  (){
    expect(dailyPages(0,
    30),
    21);
    expect(dailyPages(600,
    2),
    2);
    expect(dailyPages(604,
    1),
    0);
  });
}
