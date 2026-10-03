import 'dart:async';

import 'package:flutter/services.dart';

import 'billing_provider.dart';

/// Amazon Appstore IAP implementation of [BillingProvider].
///
/// Talks to the native Amazon Appstore SDK (IAP v2) through
/// MethodChannel "virello/billing_amazon" + EventChannel
/// "virello/billing_amazon/events". The native bridge
/// (AmazonBillingBridge.kt) exists ONLY in the `amazon` Gradle flavor.
///
/// Amazon IAP concepts mapped to Virello:
///   - Credit packs  -> CONSUMABLE SKUs
///   - Subscriptions -> SUBSCRIPTION SKUs (Amazon supports these natively)
/// Server verification uses Amazon's Receipt Verification Service (RVS)
/// via POST /api/v1/billing/amazon/verify on our backend — the billing
/// screen enforces verify-before-fulfill ordering.
///
/// SKU IDs — these exact SKUs must exist in the Amazon Developer Console
/// (In-App Items tab) BEFORE the app is submitted:
///   Consumables: virello_credits_1000 / virello_credits_5000 / virello_credits_20000
///   Subscriptions: virello_pro_monthly / virello_scale_monthly
///   Consumables (AI Ad Builder ad packages — NOT credit packs):
///     virello_ad_starter / virello_ad_growth / virello_ad_pro / virello_ad_scale
///
/// Testing: use the Amazon App Tester app (sandbox mode) — no real charges.
class AmazonBilling implements BillingProvider {
  AmazonBilling._();
  static final AmazonBilling instance = AmazonBilling._();

  static const Set<String> skuIds = {
    'virello_credits_1000',
    'virello_credits_5000',
    'virello_credits_20000',
    'virello_pro_monthly',
    'virello_scale_monthly',
    'virello_ad_starter',
    'virello_ad_growth',
    'virello_ad_pro',
    'virello_ad_scale',
  };

  /// One-time (consumable-style) SKUs: credit packs AND ad packages.
  static bool isOneTimeProduct(String sku) =>
      sku.startsWith('virello_credits_') || sku.startsWith('virello_ad_');

  /// Ad package id (starter|growth|pro|scale) -> its store SKU.
  static String? adPackageSku(String adPackage) {
    switch (adPackage) {
      case 'starter':
        return 'virello_ad_starter';
      case 'growth':
        return 'virello_ad_growth';
      case 'pro':
        return 'virello_ad_pro';
      case 'scale':
        return 'virello_ad_scale';
    }
    return null;
  }

  static const _method = MethodChannel('virello/billing_amazon');
  static const _events = EventChannel('virello/billing_amazon/events');

  StreamController<List<BillingPurchase>>? _controller;
  StreamSubscription? _eventSub;

  @override
  String get storeName => 'Amazon Appstore';

  @override
  Map<String, String>? backendKindFor(String productId) {
    switch (productId) {
      case 'virello_credits_1000':
        return {'kind': 'credits', 'creditPack': 'starter'};
      case 'virello_credits_5000':
        return {'kind': 'credits', 'creditPack': 'growth'};
      case 'virello_credits_20000':
        return {'kind': 'credits', 'creditPack': 'scale'};
      case 'virello_pro_monthly':
        return {'kind': 'subscription', 'planSlug': 'pro'};
      case 'virello_scale_monthly':
        return {'kind': 'subscription', 'planSlug': 'scale'};
      case 'virello_ad_starter':
        return {'kind': 'ad_package', 'adPackage': 'starter'};
      case 'virello_ad_growth':
        return {'kind': 'ad_package', 'adPackage': 'growth'};
      case 'virello_ad_pro':
        return {'kind': 'ad_package', 'adPackage': 'pro'};
      case 'virello_ad_scale':
        return {'kind': 'ad_package', 'adPackage': 'scale'};
      default:
        return null;
    }
  }

  @override
  String? productIdForPurchase({
    required String kind,
    String? planSlug,
    String? creditPack,
    String? adPackage,
  }) {
    if (kind == 'credits') {
      switch (creditPack) {
        case 'starter':
          return 'virello_credits_1000';
        case 'growth':
          return 'virello_credits_5000';
        case 'scale':
          return 'virello_credits_20000';
      }
    } else if (kind == 'subscription') {
      switch (planSlug) {
        case 'pro':
          return 'virello_pro_monthly';
        case 'scale':
          return 'virello_scale_monthly';
      }
    } else if (kind == 'ad_package') {
      return adPackage == null ? null : adPackageSku(adPackage);
    }
    return null;
  }

  @override
  bool isCreditsProduct(String productId) =>
      productId.startsWith('virello_credits_');

  @override
  Future<bool> isAvailable() async {
    try {
      return await _method.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false; // play flavor / no native bridge
    } on PlatformException {
      return false; // native bridge error -> treat as unavailable
    }
  }

  @override
  Future<List<BillingProduct>> queryProducts() async {
    try {
      final res = await _method.invokeMapMethod<String, dynamic>(
          'getProducts', {'skus': skuIds.toList()});
      if (res == null) return const [];
      final products = (res['products'] as List?) ?? const [];
      return products.whereType<Map>().map((p) {
        final sku = p['sku'] as String? ?? '';
        final itemType = p['itemType'] as String? ?? '';
        return BillingProduct(
          productId: sku,
          title: p['title'] as String? ?? sku,
          description: p['description'] as String? ?? '',
          price: p['price'] as String? ?? '',
          isSubscription:
              itemType.toUpperCase().contains('SUBSCRIPTION') &&
              !isOneTimeProduct(sku),
        );
      }).toList();
    } on MissingPluginException {
      return const []; // play flavor / no native bridge
    } on PlatformException {
      return const []; // native bridge error -> no products
    }
  }

  @override
  Future<bool> buyCredits(BillingProduct product) =>
      _purchase(product.productId);

  @override
  Future<bool> buySubscription(BillingProduct product) =>
      _purchase(product.productId);

  @override
  Future<bool> buyOneTime(BillingProduct product) =>
      _purchase(product.productId);

  Future<bool> _purchase(String sku) async {
    try {
      return await _method.invokeMethod<bool>('purchase', {'sku': sku}) ?? false;
    } on MissingPluginException {
      return false; // play flavor / no native bridge
    } on PlatformException {
      return false; // native bridge error
    }
  }

  /// Restore / pick up purchases completed while away.
  Future<void> refreshPurchases() async {
    try {
      await _method.invokeMethod<bool>('getPurchaseUpdates', {'reset': false});
    } on MissingPluginException {
      // play flavor / no native bridge — nothing to refresh
    } on PlatformException {
      // native bridge error — safe to ignore, next listen retries
    }
  }

  @override
  Stream<List<BillingPurchase>> get purchaseStream {
    _controller ??= StreamController<List<BillingPurchase>>.broadcast(
      onListen: () {
        _eventSub = _events.receiveBroadcastStream().listen(_onNativeEvent);
        // Drain anything completed while we were away.
        refreshPurchases();
      },
      onCancel: () {
        _eventSub?.cancel();
        _eventSub = null;
      },
    );
    return _controller!.stream;
  }

  void _onNativeEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['type'] as String?;
    if (type == 'purchase') {
      final purchase = _purchaseFromMap(event);
      if (purchase != null) _controller?.add([purchase]);
    } else if (type == 'purchaseUpdates') {
      final receipts = (event['receipts'] as List?) ?? const [];
      final purchases = receipts
          .whereType<Map>()
          .map(_purchaseFromMap)
          .whereType<BillingPurchase>()
          // Skip already-canceled receipts; they carry no grant.
          .where((p) => event['status'] != 'FAILED')
          .toList();
      if (purchases.isNotEmpty) _controller?.add(purchases);
    }
    // 'userData' events are informational; userId rides on purchase events.
  }

  BillingPurchase? _purchaseFromMap(Map event) {
    final sku = event['sku'] as String?;
    final receiptId = event['receiptId'] as String?;
    if (sku == null || sku.isEmpty || receiptId == null || receiptId.isEmpty) {
      return null;
    }
    final status = (event['status'] as String? ?? '').toUpperCase();
    if (status == 'FAILED' || status == 'INVALID_SKU') {
      return BillingPurchase(
        productId: sku,
        receipt: receiptId,
        isSubscription: !isCreditsProduct(sku),
        status: BillingPurchaseStatus.error,
        errorCode: status.toLowerCase(),
      );
    }
    if (status == 'ALREADY_PURCHASED') {
      return BillingPurchase(
        productId: sku,
        receipt: receiptId,
        isSubscription: !isCreditsProduct(sku),
        status: BillingPurchaseStatus.restored,
        storeUserId: event['userId'] as String?,
      );
    }
    // Canceled receipts must never grant.
    if (event['isCanceled'] == true || event['cancelDate'] != 0) {
      return BillingPurchase(
        productId: sku,
        receipt: receiptId,
        isSubscription: !isCreditsProduct(sku),
        status: BillingPurchaseStatus.canceled,
        storeUserId: event['userId'] as String?,
      );
    }
    return BillingPurchase(
      productId: sku,
      receipt: receiptId,
      isSubscription: !isCreditsProduct(sku),
      status: BillingPurchaseStatus.purchased,
      storeUserId: event['userId'] as String?,
    );
  }

  @override
  Future<void> completePurchase(BillingPurchase purchase) async {
    // Call ONLY after POST /api/v1/billing/amazon/verify succeeds.
    try {
      await _method.invokeMethod<bool>(
        'completePurchase',
        {'receiptId': purchase.receipt},
      );
    } on MissingPluginException {
      // play flavor / no native bridge — nothing to fulfill
    } on PlatformException {
      // native bridge error — server already granted; safe to skip
    }
  }
}
