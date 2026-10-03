/// Store-agnostic billing abstraction for Virello.
///
/// Two implementations:
///   - [GooglePlayBilling] — Google Play Billing (Play Store flavor)
///   - [AmazonBilling]      — Amazon Appstore IAP (Amazon flavor)
///
/// The active implementation is chosen at compile time:
///   flutter build apk --dart-define=VIRELLO_STORE=amazon
/// (default: play). This keeps Play Billing code out of the Amazon build
/// and vice versa — each store only sees its own compliant billing path.
///
/// Money rule (both stores): the app NEVER treats a purchase as successful
/// on its own. Every purchase goes to the backend for server-side
/// verification and is only completed after the server confirms it.
library;

/// A purchasable item, in store-agnostic terms.
class BillingProduct {
  const BillingProduct({
    required this.productId,
    required this.title,
    required this.description,
    required this.price,
    required this.isSubscription,
  });

  final String productId;
  final String title;
  final String description;
  final String price;
  final bool isSubscription;
}

/// A completed purchase awaiting server verification.
class BillingPurchase {
  const BillingPurchase({
    required this.productId,
    required this.receipt,
    required this.isSubscription,
    this.status = BillingPurchaseStatus.purchased,
    this.errorCode,
    this.storeUserId,
  });

  final String productId;

  /// Store receipt: Play purchase token, or Amazon receipt ID + user ID.
  final String receipt;
  final bool isSubscription;
  final BillingPurchaseStatus status;

  /// Machine-readable error (e.g. 'userCancelled'), if status is error.
  final String? errorCode;

  /// Store account ID (Amazon user ID for RVS verification; null for Play).
  final String? storeUserId;
}

/// Store-agnostic purchase states.
enum BillingPurchaseStatus {
  pending,
  purchased,
  restored,
  error,
  canceled,
}

/// Store-agnostic billing interface.
abstract class BillingProvider {
  /// Human-readable store name for UI ("Google Play" / "Amazon Appstore").
  String get storeName;

  /// False when the store's billing service is unreachable
  /// (e.g. sideloaded APK, no Play Services on Fire device).
  Future<bool> isAvailable();

  /// Query the store for our products. Returns only what the store knows.
  Future<List<BillingProduct>> queryProducts();

  /// Start a one-time credit-pack purchase. Result arrives on [purchaseStream].
  Future<bool> buyCredits(BillingProduct product);

  /// Start a recurring subscription purchase. Result arrives on [purchaseStream].
  Future<bool> buySubscription(BillingProduct product);

  /// Start a one-time (consumable, non-subscription) purchase that is NOT
  /// a credit pack — e.g. an AI Ad Builder ad package. Result arrives on
  /// [purchaseStream]; verify server-side before completing, like the rest.
  Future<bool> buyOneTime(BillingProduct product);

  /// Purchase updates; verify server-side before completing.
  Stream<List<BillingPurchase>> get purchaseStream;

  /// Acknowledge/consume with the store. Call ONLY after server verification.
  Future<void> completePurchase(BillingPurchase purchase);

  /// Map a store product ID to the backend purchase kind.
  /// Returns {'kind': 'credits', 'creditPack': ...},
  /// {'kind': 'subscription', 'planSlug': ...}, or
  /// {'kind': 'ad_package', 'adPackage': ...}, or null.
  Map<String, String>? backendKindFor(String productId);

  /// Map a billing-screen item to its store product ID, or null.
  /// [kind]: 'credits' | 'subscription' | 'ad_package'.
  /// 'ad_package' uses [adPackage] (starter|growth|pro|scale) and maps to
  /// the one-time store product for that Paid Boost package.
  String? productIdForPurchase({
    required String kind,
    String? planSlug,
    String? creditPack,
    String? adPackage,
  });

  bool isCreditsProduct(String productId);
}
