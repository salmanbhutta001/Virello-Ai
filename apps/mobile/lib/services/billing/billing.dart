import 'amazon_billing.dart';
import 'billing_provider.dart';
import 'google_play_billing.dart';

/// Compile-time store selection.
///
///   Play Store:   flutter build appbundle (default)
///   Amazon:       flutter build apk --dart-define=VIRELLO_STORE=amazon
///
/// Each store build only links its own compliant billing path.
class Billing {
  Billing._();

  static const String store =
      String.fromEnvironment('VIRELLO_STORE', defaultValue: 'play');

  static bool get isAmazon => store == 'amazon';
  static bool get isPlay => !isAmazon;

  static BillingProvider get instance =>
      isAmazon ? AmazonBilling.instance : GooglePlayBilling.instance;
}
