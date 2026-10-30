import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mock only native device boundaries; keep the real widgets, store, assets,
/// navigation and Quran text resolver in the test.
void mockNativeChannels() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final methods = <String>{};
  final binaryChannels = <String>{};

  void method(String name, Future<Object?> Function(MethodCall) handler) {
    methods.add(name);
    messenger.setMockMethodCallHandler(MethodChannel(name), handler);
  }

  method('flutter_timezone', (_) async => 'UTC');
  method('dexterous.com/flutter/local_notifications', (_) async => true);
  method('xyz.luan/audioplayers.global', (_) async => null);
  method('xyz.luan/audioplayers.global/events', (_) async => null);
  method('xyz.luan/audioplayers', (call) async {
    if (call.method == 'create') {
      final id = (call.arguments as Map)['playerId'] as String;
      method('xyz.luan/audioplayers/events/$id', (_) async => null);
    }
    if (call.method == 'getDuration' || call.method == 'getCurrentPosition') {
      return 0;
    }
    return null;
  });

  // Wakelock's Pigeon namespace changed between compatible plugin releases.
  // Reply without decoding its generated request type; void replies use [null].
  for (final prefix in [
    'dev.flutter.pigeon.WakelockPlusApi',
    'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi',
  ]) {
    final name = '$prefix.toggle';
    binaryChannels.add(name);
    messenger.setMockMessageHandler(name, (_) async {
      return const StandardMessageCodec().encodeMessage(<Object?>[null]);
    });
  }

  addTearDown(() {
    for (final name in methods) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
    for (final name in binaryChannels) {
      messenger.setMockMessageHandler(name, null);
    }
  });
}
