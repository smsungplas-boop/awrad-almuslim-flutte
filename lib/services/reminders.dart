import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
class Reminders {
  final plugin=FlutterLocalNotificationsPlugin();
  Future<void> init() async {
    tzdata.initializeTimeZones();
    final zone=await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone));
    await plugin.initialize(const InitializationSettings(android:AndroidInitializationSettings('ic_stat_awrad')));
  } Future<void> schedule(int id,
  String title,
  int hour,
  int minute,
  bool enabled) async {
    await plugin.cancel(id);
    if(!enabled) {
      return;
    } final android=plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final allowed=await android?.requestNotificationsPermission();
    if(allowed==false) {
      throw Exception('يرجى السماح بالإشعارات من إعدادات الجهاز');
    } final now=tz.TZDateTime.now(tz.local);
    var at=tz.TZDateTime(tz.local,
    now.year,
    now.month,
    now.day,
    hour,
    minute);
    if(!at.isAfter(now)) {
      at=tz.TZDateTime(tz.local,
      now.year,
      now.month,
      now.day+1,
      hour,
      minute);
    } await plugin.zonedSchedule(id,
    title,
    'حان وقت وردك اليومي',
    at,
    const NotificationDetails(android:AndroidNotificationDetails('daily_adhkar',
    'تذكير الأذكار',
    channelDescription:'أذكار الصباح والمساء',
    importance:Importance.high,
    priority:Priority.high)),
    androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents:DateTimeComponents.time);
  }
}
