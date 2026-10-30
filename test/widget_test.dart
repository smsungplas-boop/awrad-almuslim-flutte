import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awrad_almuslim/main.dart';
import 'package:awrad_almuslim/screens/wird_reader.dart';
import 'package:awrad_almuslim/services/quran.dart';
import 'package:awrad_almuslim/services/store.dart';
import 'support/native_channels.dart';

void main() {
  testWidgets('Arabic shell navigates to original morning content', (tester) async {
    mockNativeChannels();
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    SharedPreferences.setMockInitialValues({
      'awrad_flutter': '{"splash":false}',
    });
    final store = Store();
    // Asset loading involves real asynchronous file I/O. Do it outside the
    // widget test's fake clock, just as startup does before runApp in main().
    await tester.runAsync(() async {
      await store.load();
      // Warm the real bundled Quran data, without HTTP or replacement content.
      await QuranService().resolve({'q': [112, 1, 4]});
    });
    final morning = store.groups.firstWhere((g) => g.id == 'a3');
    final firstDhikr = morning.items.first.parts as String;
    expect(firstDhikr, startsWith('اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ'));

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(AwradApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('أوراد المسلم'), findsWidgets);
    expect(
      Directionality.of(tester.element(find.byType(NavigationBar))),
      TextDirection.rtl,
    );

    // Select the actual destination by label, not the last of several identical
    // decorative icons in home cards and navigation.
    final adhkarTab = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('أذكاري'),
    );
    await tester.tap(adhkarTab);
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 2);
    final morningTile = find.widgetWithText(ListTile, 'أذكار الصباح');
    expect(morningTile, findsOneWidget);
    expect(find.widgetWithText(ListTile, 'أذكار المساء'), findsOneWidget);

    await tester.ensureVisible(morningTile);
    await tester.tap(find.descendant(of: morningTile, matching: find.text('أذكار الصباح')));
    await tester.pumpAndSettle();
    expect(find.byType(WirdReader), findsOneWidget);
    expect(tester.widget<WirdReader>(find.byType(WirdReader)).wird.id, 'a3');
    expect(find.widgetWithText(AppBar, 'أذكار الصباح'), findsOneWidget);
    // Check the complete original text, not merely the screen's title.
    expect(find.text(firstDhikr), findsOneWidget);
    expect(find.text('تعذر تحميل الآيات. النصوص العادية متاحة دون اتصال.'), findsNothing);

    // Exercise the real counter and its stored progress as part of navigation.
    final counter = find.bySemanticsLabel(RegExp('^المتبقي ${morning.items.first.repeat}' r'(?:\s|$)')).first;
    await tester.ensureVisible(counter);
    await tester.tap(counter);
    await tester.pumpAndSettle();
    expect((store.data['progress_a3'] as List).first, morning.items.first.repeat - 1);
    expect(store.get<int>('total', 0), 1);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(WirdReader), findsNothing);
    expect(find.widgetWithText(ListTile, 'أذكار الصباح'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Dispose audio, streams and wakelock before the platform mocks are removed.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
