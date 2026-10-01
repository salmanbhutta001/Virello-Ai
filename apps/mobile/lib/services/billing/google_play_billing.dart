import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'billing_provider.dart';

/// Google Play Billing implementation of [BillingProvider].
///
/// Product IDs — these exact IDs must exist in Play Console
/// (Monetize > Products), otherwise queries return empty:
///   Consumables (one-time credit packs):
///     virello_credits_1000 / virello_credits_5000 / virello_credits_20000
///   Subscriptions:
///     virello_pro_monthly / virello_scale_monthly
class GooglePlayBilling implements BillingProvider {
  GooglePlayBilling._();
  static final GooglePlayBilling instance = GooglePlayBilling._();

  static const Set<String> productIds = {
    'virello_credits_1000',
    'virello_credits_5000',
    'virello_credits_20000',
    'virello_pro_monthly',
    'virello_scale_monthly',
  };

  @override
  String get storeName => 'Google Play';

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
      default:
        return null;
    }
  }

  @override
  String? productIdForPurchase({
    required String kind,
    String? planSlug,
    String? creditPack,
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
    }
    return null;
  }

  @override
  bool isCreditsProduct(String productId) =>
      productId.startsWith('virello_credits_');

  @override
  Future<bool> isAvailable() => InAppPurchase.instance.isAvailable();

  @override
  Future<List<BillingProduct>> queryProducts() async {
    final resp = await InAppPurchase.instance.queryProductDetails(productIds);
    return resp.productDetails
        .map(
          (p) => BillingProduct(
            productId: p.id,
            title: p.title,
            description: p.description,
            price: p.price,
            isSubscription: !isCreditsProduct(p.id),
          ),
        )
        .toList();
  }

  @override
  Future<bool> buyCredits(BillingProduct product) async {
    final details = await _detailsFor(product.productId);
    if (details == null) return false;
    return InAppPurchase.instance.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
  }

  @override
  Future<bool> buySubscription(BillingProduct product) async {
    final details = await _detailsFor(product.productId);
    if (details == null) return false;
    return InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
  }

  Future<ProductDetails?> _detailsFor(String productId) async {
    final resp = await InAppPurchase.instance.queryProductDetails({productId});
    return resp.productDetails.isEmpty ? null : resp.productDetails.first;
  }

  @override
  Stream<List<BillingPurchase>> get purchaseStream =>
      InAppPurchase.instance.purchaseStream.map(
        (list) => list
            .map(
              (p) => BillingPurchase(
                productId: p.productID,
                receipt: p.verificationData.serverVerificationData,
                isSubscription: !isCreditsProduct(p.productID),
                status: _mapStatus(p.status),
                errorCode: p.error?.code,
              ),
            )
            .toList(),
      );

  BillingPurchaseStatus _mapStatus(PurchaseStatus s) {
    switch (s) {
      case PurchaseStatus.pending:
        return BillingPurchaseStatus.pending;
      case PurchaseStatus.purchased:
        return BillingPurchaseStatus.purchased;
      case PurchaseStatus.restored:
        return BillingPurchaseStatus.restored;
      case PurchaseStatus.error:
        return BillingPurchaseStatus.error;
      case PurchaseStatus.canceled:
        return BillingPurchaseStatus.canceled;
    }
  }

  @override
  Future<void> completePurchase(BillingPurchase purchase) async {
    // Re-resolve the underlying PurchaseDetails to complete it.
    // The billing screen keeps the raw stream items; this is a safety net.
    await for (final list in InAppPurchase.instance.purchaseStream) {
      final match = list.where((p) =>
          p.productID == purchase.productId &&
          p.verificationData.serverVerificationData == purchase.receipt);
      if (match.isNotEmpty) {
        await InAppPurchase.instance.completePurchase(match.first);
        return;
      }
      break;
    }
  }
}
