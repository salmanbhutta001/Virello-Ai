import 'package:flutter/services.dart';

/// Device/store capabilities, bridged from native MainActivity.
///
/// Used to degrade gracefully on Fire OS / de-Googled devices:
/// no Google Play Services -> hide Google Sign-In, use Amazon IAP.
class DeviceInfo {
  DeviceInfo._();
  static const _channel = MethodChannel('virello/device');

  static bool? _hasPlayServices;
  static String? _storeFlavor;

  /// True when Google Play Services are available and current.
  /// Cached after first check.
  static Future<bool> get hasPlayServices async {
    if (_hasPlayServices != null) return _hasPlayServices!;
    try {
      _hasPlayServices =
          await _channel.invokeMethod<bool>('hasPlayServices') ?? false;
    } on PlatformException {
      _hasPlayServices = false;
    }
    return _hasPlayServices!;
  }

  /// Which Gradle flavor built this app: "play", "amazon", or "unknown".
  static Future<String> get storeFlavor async {
    if (_storeFlavor != null) return _storeFlavor!;
    try {
      _storeFlavor =
          await _channel.invokeMethod<String>('storeFlavor') ?? 'unknown';
    } on PlatformException {
      _storeFlavor = 'unknown';
    }
    return _storeFlavor!;
  }

  /// True when this build targets the Amazon Appstore
  /// (compile-time dart-define OR amazon flavor).
  static Future<bool> get isAmazonBuild async {
    const defined =
        String.fromEnvironment('VIRELLO_STORE', defaultValue: 'play');
    if (defined == 'amazon') return true;
    return (await storeFlavor) == 'amazon';
  }
}
