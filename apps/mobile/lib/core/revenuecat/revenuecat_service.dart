import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class CreditPackOffering {
  const CreditPackOffering({
    required this.productId,
    required this.credits,
    required this.title,
    required this.fallbackPriceText,
    required this.canPurchase,
    this.storePriceText,
    this.badge,
  });

  final String productId;
  final int credits;
  final String title;
  final String fallbackPriceText;
  final String? storePriceText;
  final String? badge;
  final bool canPurchase;

  String get displayPriceText => storePriceText ?? fallbackPriceText;

  CreditPackOffering copyWith({
    String? storePriceText,
    bool? canPurchase,
  }) {
    return CreditPackOffering(
      productId: productId,
      credits: credits,
      title: title,
      fallbackPriceText: fallbackPriceText,
      storePriceText: storePriceText ?? this.storePriceText,
      badge: badge,
      canPurchase: canPurchase ?? this.canPurchase,
    );
  }
}

class RevenueCatService {
  static const aiCreditProductIds = <String>[
    'fortunelog_ai_credit_1',
    'fortunelog_ai_credit_5',
    'fortunelog_ai_credit_10',
  ];

  static const _fallbackCreditPacks = <CreditPackOffering>[
    CreditPackOffering(
      productId: 'fortunelog_ai_credit_1',
      credits: 1,
      title: 'AI 사주풀이 1회권',
      fallbackPriceText: '1,500원',
      canPurchase: false,
    ),
    CreditPackOffering(
      productId: 'fortunelog_ai_credit_5',
      credits: 5,
      title: 'AI 사주풀이 5회권',
      fallbackPriceText: '5,500원',
      badge: '추천',
      canPurchase: false,
    ),
    CreditPackOffering(
      productId: 'fortunelog_ai_credit_10',
      credits: 10,
      title: 'AI 사주풀이 10회권',
      fallbackPriceText: '10,000원',
      badge: '가장 합리적',
      canPurchase: false,
    ),
  ];

  static String? _lastSyncedUserId;
  static bool _logLevelConfigured = false;
  @visibleForTesting
  static String? debugApiKeyOverride;
  @visibleForTesting
  static String? debugEntitlementIdOverride;

  static String get _apiKey {
    final debugOverride = debugApiKeyOverride;
    if (debugOverride != null) return debugOverride;
    if (kIsWeb) return '';
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return const String.fromEnvironment('REVENUECAT_API_KEY_IOS');
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return const String.fromEnvironment('REVENUECAT_API_KEY_ANDROID');
    }
    return '';
  }

  static bool get isEnabled => _apiKey.trim().isNotEmpty;

  static String? get entitlementId {
    final debugOverride = debugEntitlementIdOverride;
    if (debugOverride != null) {
      final trimmed = debugOverride.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    final value = const String.fromEnvironment('REVENUECAT_ENTITLEMENT_ID');
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @visibleForTesting
  static void debugReset() {
    _lastSyncedUserId = null;
    _logLevelConfigured = false;
    debugApiKeyOverride = null;
    debugEntitlementIdOverride = null;
  }

  static Future<void> syncWithUserId(String? userId) async {
    final normalizedUserId = userId?.trim();
    if (!isEnabled) return;

    if (kDebugMode && !_logLevelConfigured) {
      await Purchases.setLogLevel(LogLevel.debug);
      _logLevelConfigured = true;
    }

    final configured = await Purchases.isConfigured;
    if (!configured) {
      if (normalizedUserId == null || normalizedUserId.isEmpty) {
        _lastSyncedUserId = null;
        return;
      }

      final configuration = PurchasesConfiguration(_apiKey)
        ..appUserID = normalizedUserId;
      await Purchases.configure(configuration);
      _lastSyncedUserId = normalizedUserId;
      return;
    }

    if (normalizedUserId == null || normalizedUserId.isEmpty) {
      if (_lastSyncedUserId == null) return;
      await Purchases.logOut();
      _lastSyncedUserId = null;
      return;
    }

    if (_lastSyncedUserId == normalizedUserId) return;
    await Purchases.logIn(normalizedUserId);
    _lastSyncedUserId = normalizedUserId;
  }

  static List<CreditPackOffering> fallbackCreditPacks(
      {bool canPurchase = false}) {
    return _fallbackCreditPacks
        .map((pack) => pack.copyWith(canPurchase: canPurchase && isEnabled))
        .toList();
  }

  static Future<List<CreditPackOffering>> loadCreditPacks() async {
    if (!isEnabled || kIsWeb || !await Purchases.isConfigured) {
      return fallbackCreditPacks();
    }

    final offerings = await Purchases.getOfferings();
    final current = offerings.current;
    if (current == null) {
      return fallbackCreditPacks(canPurchase: true);
    }

    return _fallbackCreditPacks.map((pack) {
      final match = current.availablePackages
          .where((package) => package.storeProduct.identifier == pack.productId)
          .toList();
      if (match.isEmpty) return pack.copyWith(canPurchase: true);
      return pack.copyWith(
        storePriceText: match.first.storeProduct.priceString,
        canPurchase: true,
      );
    }).toList();
  }

  static Future<void> purchaseCreditPack(String productId) async {
    if (!isEnabled || kIsWeb || !await Purchases.isConfigured) {
      throw StateError(
          'RevenueCat purchase is not available on this platform.');
    }

    final offerings = await Purchases.getOfferings();
    final current = offerings.current;
    if (current == null) {
      throw StateError('RevenueCat offering is not configured.');
    }

    final matches = current.availablePackages
        .where((package) => package.storeProduct.identifier == productId)
        .toList();
    if (matches.isEmpty) {
      throw StateError('RevenueCat product is not configured: $productId');
    }

    await Purchases.purchase(PurchaseParams.package(matches.first));
  }

  static Future<void> restorePurchases() async {
    if (!isEnabled || kIsWeb || !await Purchases.isConfigured) return;
    await Purchases.restorePurchases();
  }

  static Future<bool> hasActiveEntitlement() async {
    if (!isEnabled) return false;
    if (!await Purchases.isConfigured) return false;

    final customerInfo = await Purchases.getCustomerInfo();
    final configuredEntitlement = entitlementId;
    if (configuredEntitlement != null) {
      final entitlement = customerInfo.entitlements.all[configuredEntitlement];
      return entitlement?.isActive == true;
    }

    for (final entitlement in customerInfo.entitlements.active.values) {
      if (entitlement.isActive) {
        return true;
      }
    }
    return false;
  }
}
