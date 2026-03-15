import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
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
