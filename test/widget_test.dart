import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awrad_almuslim/main.dart';
import 'package:awrad_almuslim/services/store.dart';
void main(){
  testWidgets('Arabic shell navigates to original morning content',
  (tester)async{
    SharedPreferences.setMockInitialValues({
      'awrad_flutter':'{"splash":false}'
    });
    final store=Store();
    await store.load();
    await tester.binding.setSurfaceSize(const Size(390,
    844));
    addTearDown(()=>tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(AwradApp(store:store));
    await tester.pump();
    expect(find.text('أوراد المسلم'),
    findsWidgets);
    expect(Directionality.of(tester.element(find.byType(NavigationBar))),
    TextDirection.rtl);
    await tester.tap(find.byIcon(Icons.auto_awesome_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('أذكار الصباح'),
    findsOneWidget);
    expect(find.text('أذكار المساء'),
    findsOneWidget);
    expect(tester.takeException(),
    isNull);
  });
}
