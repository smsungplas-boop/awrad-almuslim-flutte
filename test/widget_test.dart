import 'dart:convert';
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
    await pumpUntilState(
      tester,
      () => find.byType(WirdReader).evaluate().length == 1 &&
          find.text(firstDhikr).evaluate().length == 1 &&
          ModalRoute.of(tester.element(find.byType(WirdReader)))?.animation?.status ==
              AnimationStatus.completed,
      'morning route finishes opening and renders the original first dhikr',
    );
    expect(find.byType(WirdReader), findsOneWidget);
    expect(tester.widget<WirdReader>(find.byType(WirdReader)).wird.id, 'a3');
    expect(find.widgetWithText(AppBar, 'أذكار الصباح'), findsOneWidget);
    // Check the complete original text, not merely the screen's title.
    expect(find.text(firstDhikr), findsOneWidget);
    expect(find.text('تعذر تحميل الآيات. النصوص العادية متاحة دون اتصال.'), findsNothing);

    // Exercise the real counter and its stored progress as part of navigation.
    // Offscreen Semantics nodes may be clipped even when their widgets are
    // built. Find the exact first counter by identity and scroll the reader's
    // vertical list until it is visible; do not search by a repeated count.
    final readerList = find.byKey(const ValueKey('wird-list-a3'));
    final readerScrollable = find.descendant(
      of: readerList,
      matching: find.byType(Scrollable),
    );
    expect(readerScrollable, findsOneWidget);
    final counter = find.byKey(const ValueKey('dhikr-counter-a3-0'));
    await tester.scrollUntilVisible(
      counter,
      240,
      scrollable: readerScrollable,
      maxScrolls: 50,
    );
    await pumpUntilState(
      tester,
      () => counter.hitTestable().evaluate().length == 1,
      'first morning counter is visible after scrolling',
    );
    expect(counter.hitTestable(), findsOneWidget);
    expect(
      tester.widget<Semantics>(counter).properties.label,
      'المتبقي ${morning.items.first.repeat}',
    );
    await tester.tap(counter);
    await pumpUntilState(tester, () {
      if (counter.evaluate().length != 1) return false;
      final saved = jsonDecode(store.prefs.getString('awrad_flutter') ?? '{}') as Map;
      return tester.widget<Semantics>(counter).properties.label ==
              'المتبقي ${morning.items.first.repeat - 1}' &&
          (saved['progress_a3'] as List?)?.first == morning.items.first.repeat - 1 &&
          saved['total'] == 1;
    }, 'counter UI and persisted morning progress update after tap');
    // AnimatedOpacity has a finite 200 ms transition; do not wait for unrelated
    // loading indicators elsewhere in the lazily built list to stop ticking.
    await tester.pump(const Duration(milliseconds: 250));
    expect((store.data['progress_a3'] as List).first, morning.items.first.repeat - 1);
    expect(store.get<int>('total', 0), 1);
    // The UI must also reflect the updated counter, not only the store.
    expect(
      tester.widget<Semantics>(counter).properties.label,
      'المتبقي ${morning.items.first.repeat - 1}',
    );
    expect(
      find.descendant(of: counter, matching: find.text('✓')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await pumpUntilState(
      tester,
      () => find.byType(WirdReader).evaluate().isEmpty &&
          find.widgetWithText(ListTile, 'أذكار الصباح').evaluate().length == 1,
      'back navigation returns to the original adhkar list',
    );
    expect(find.byType(WirdReader), findsNothing);
    expect(find.widgetWithText(ListTile, 'أذكار الصباح'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Dispose audio, streams and wakelock before the platform mocks are removed.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });
}

/// Wait for a concrete outcome, not global frame inactivity. Loading spinners
/// in neighbouring lazy list items can legitimately keep scheduling frames.
Future<void> pumpUntilState(
  WidgetTester tester,
  bool Function() ready,
  String description,
) async {
  for (var frame = 0; frame < 40; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
    // Let real asset/platform I/O complete outside FakeAsync as well.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    if (ready()) return;
  }
  final scrolls = tester.widgetList<Scrollable>(find.byType(Scrollable)).map((w) {
    final controller = w.controller;
    return controller != null && controller.hasClients
        ? '${w.axisDirection}: ${controller.position.pixels}/${controller.position.maxScrollExtent}'
        : '${w.axisDirection}: no attached controller';
  }).join(', ');
  debugPrint('WAIT FAILED: $description; '
      'scheduledFrame=${tester.binding.hasScheduledFrame}; '
      'transientCallbacks=${tester.binding.transientCallbackCount}; '
      'circularIndicators=${find.byType(CircularProgressIndicator).evaluate().length}; '
      'scrolls=[$scrolls]');
  debugDumpApp();
  throw TestFailure('State not reached within 40 pumps (2 seconds): $description');
}
