import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../main.dart';

/// FTC + Amazon Associates disclosure. REQUIRED on every affiliate product
/// detail screen: "Affiliate link — we may earn a commission".
/// Phase 4 mobile: render this directly under the Buy button whenever
/// product['is_affiliate'] is true.
class AffiliateDisclosure extends StatelessWidget {
  const AffiliateDisclosure({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.affiliateDisclosure,
              style: TextStyle(
                fontSize: 12,
                color: Colors.amber.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
