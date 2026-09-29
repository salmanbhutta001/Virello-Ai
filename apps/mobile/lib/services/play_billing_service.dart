import 'package:in_app_purchase/in_app_purchase.dart';

/// Google Play Billing for Virello.
///
/// Product IDs — these exact IDs must exist in Play Console
/// (Monetize > Products), otherwise queries return empty:
///   Consumables (one-time credit packs):
///     virello_credits_1000 / virello_credits_5000 / virello_credits_20000
///   Subscriptions:
///     virello_pro_monthly / virello_scale_monthly
///
/// Money rule: the app NEVER treats a purchase as successful on its own.
/// Every purchased/restored item goes to the backend
/// (POST /api/v1/billing/play/verify) and is only completed locally after
/// the server confirms it.
class PlayBillingService {
  PlayBillingService._();
  static final PlayBillingService instance = PlayBillingService._();

  static const Set<String> productIds = {
    'virello_credits_1000',
    'virello_credits_5000',
    'virello_credits_20000',
    'virello_pro_monthly',
    'virello_scale_monthly',
  };

  /// Map a Play product ID to the backend purchase kind.
  /// creditPack uses the backend CREDIT_PACKS keys (starter/growth/scale).
  static Map<String, String>? backendKindFor(String productId) {
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

  /// Map a billing-screen item (kind + plan/pack) to its Play product ID.
  /// Returns null when the item has no Play counterpart (e.g. the Free plan).
  static String? productIdForPurchase({
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

  static bool isCreditsProduct(String productId) =>
      productId.startsWith('virello_credits_');

  /// False on sideloaded installs / devices without Play services.
  Future<bool> isAvailable() => InAppPurchase.instance.isAvailable();

  /// Query Play Console for our 5 products. Returns only what Play knows.
  Future<List<ProductDetails>> queryProducts() async {
    final resp = await InAppPurchase.instance.queryProductDetails(productIds);
    return resp.productDetails;
  }

  /// One-time credit pack. Result arrives on [purchaseStream].
  Future<bool> buyCredits(ProductDetails product) =>
      InAppPurchase.instance.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );

  /// Recurring subscription. Result arrives on [purchaseStream].
  Future<bool> buySubscription(ProductDetails product) =>
      InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );

  /// Listen in the billing screen; verify server-side before completing.
  Stream<List<PurchaseDetails>> get purchaseStream =>
      InAppPurchase.instance.purchaseStream;

  /// Acknowledge/consume with Play. Call ONLY after server verification.
  Future<void> completePurchase(PurchaseDetails p) =>
      InAppPurchase.instance.completePurchase(p);
}
