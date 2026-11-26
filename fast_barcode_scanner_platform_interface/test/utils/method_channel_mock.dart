import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class MethodChannelMock {
  final Duration? delay;
  final MethodChannel channel;
  final Map<String, dynamic> methods;
  final log = <MethodCall>[];

  MethodChannelMock({
    required String channelName,
    this.delay,
    required this.methods,
  }) : channel = MethodChannel(channelName) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, _handler);
  }

  Future _handler(MethodCall methodCall) async {
    log.add(methodCall);

    if (!methods.containsKey(methodCall.method)) {
      throw MissingPluginException('No implementation found for method '
          '${methodCall.method} on channel ${channel.name}');
    }

    return Future.delayed(delay ?? Duration.zero, () {
      final result = methods[methodCall.method];
      if (result is Exception) {
        throw result;
      }

      return Future.value(result);
    });
  }
}
