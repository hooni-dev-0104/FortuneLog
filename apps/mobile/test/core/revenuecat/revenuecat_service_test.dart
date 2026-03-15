import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fortune_log_mobile/core/revenuecat/revenuecat_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('purchases_flutter');
  final log = <MethodCall>[];
  var isConfigured = false;

  Map<String, dynamic> mockCustomerInfo() => {
        'originalAppUserId': 'user-1',
        'entitlements': {
          'all': {},
          'active': {},
          'verification': 'NOT_REQUESTED',
        },
        'activeSubscriptions': [],
        'latestExpirationDate': null,
        'allExpirationDates': {},
        'allPurchasedProductIdentifiers': [],
        'firstSeen': '2021-01-09T14:48:00.000Z',
        'requestDate': '2021-04-09T14:48:00.000Z',
        'allPurchaseDates': {},
        'originalApplicationVersion': '1.2.3',
        'nonSubscriptionTransactions': [],
      };

  setUp(() {
    RevenueCatService.debugReset();
    log.clear();
    isConfigured = false;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      log.add(call);
      switch (call.method) {
        case 'setLogLevel':
          return null;
        case 'isConfigured':
          return isConfigured;
        case 'setupPurchases':
          isConfigured = true;
          return null;
        case 'logIn':
          return {
            'customerInfo': mockCustomerInfo(),
            'created': false,
          };
        case 'logOut':
          return mockCustomerInfo();
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    RevenueCatService.debugReset();
  });

  test('returns early when RevenueCat is disabled', () async {
    await RevenueCatService.syncWithUserId('user-1');

    expect(log, isEmpty);
  });

  test('bootstraps purchases once for the first signed-in user', () async {
    RevenueCatService.debugApiKeyOverride = 'rc_test_key';

    await RevenueCatService.syncWithUserId('  user-1  ');
    await RevenueCatService.syncWithUserId('user-1');

    expect(log.map((call) => call.method), [
      'setLogLevel',
      'isConfigured',
      'setupPurchases',
      'isConfigured',
    ]);

    final setupCall = log[2];
    expect(setupCall.arguments, isA<Map>());
    expect((setupCall.arguments as Map)['apiKey'], 'rc_test_key');
    expect((setupCall.arguments as Map)['appUserId'], 'user-1');
  });

  test('logs out on sign-out and logs in when a different user appears',
      () async {
    RevenueCatService.debugApiKeyOverride = 'rc_test_key';

    await RevenueCatService.syncWithUserId('user-1');
    await RevenueCatService.syncWithUserId(null);
    await RevenueCatService.syncWithUserId('user-2');

    expect(log.map((call) => call.method), [
      'setLogLevel',
      'isConfigured',
      'setupPurchases',
      'isConfigured',
      'logOut',
      'isConfigured',
      'logIn',
    ]);
    expect((log.last.arguments as Map)['appUserID'], 'user-2');
  });
}
