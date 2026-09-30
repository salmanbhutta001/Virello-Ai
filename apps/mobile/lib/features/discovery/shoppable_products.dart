import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../main.dart';
import '../wallet/share_earn.dart';

/// Shoppable post UI: creator-tagged Amazon products rendered below a post.
/// Every card carries the "Sponsored" disclosure label. Tapping a card
/// opens the tracked redirect GET /api/v1/shop/go/{asin}?post={placement_id}
/// in the external browser (never an in-app WebView) so clicks are counted
/// server-side. Nothing is fabricated — the widget renders nothing when
/// [tagged] is empty.
class ShoppableProducts extends StatelessWidget {
  final List<Map<String, dynamic>> tagged;
  final String placementId;
  final bool compact;

  const ShoppableProducts({
    super.key,
    required this.tagged,
    this.placementId = '',
    this.compact = false,
  });

  /// Real tagged products only — entries without an ASIN cannot be opened.
  List<Map<String, dynamic>> get _valid =>
      tagged.where((p) => '${p['asin'] ?? ''}'.isNotEmpty).toList();

  Future<void> _open(BuildContext context, Map<String, dynamic> p) async {
    final uri = Uri.tryParse(
      apiClient.shopGoUrl('${p['asin']}', placementId),
    );
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final items = _valid;
    if (items.isEmpty) return const SizedBox.shrink();
    return compact ? _compactCard(context, items) : _fullRail(context, items);
  }

  /// Feed card: single compact row (first product + "N more" count).
  Widget _compactCard(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) {
    final s = AppStrings(appState.localeCode);
    final p = items.first;
    final more = items.length - 1;
    return InkWell(
      onTap: () => _open(context, p),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: VTheme.chip(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VTheme.divider(context)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: '${p['image_url'] ?? ''}'.isNotEmpty
                  ? Image.network(
                      '${p['image_url']}',
                      width: 48,
                      height: 48,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _ph(context, 48, 48),
                    )
                  : _ph(context, 48, 48),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${p['title'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${p['price_display'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: VirelloColors.pink,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          s.sponsored,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8D6E00),
                          ),
                        ),
                      ),
                      if (more > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          '+$more',
                          style: const TextStyle(
                            fontSize: 11,
                            color: VirelloColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: VirelloColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  /// Post reader: horizontal rail of product cards.
  Widget _fullRail(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) {
    final s = AppStrings(appState.localeCode);
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final p = items[i];
          return GestureDetector(
            onTap: () => _open(ctx, p),
            child: Container(
              width: 150,
              decoration: BoxDecoration(
                color: VTheme.card(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: VTheme.divider(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: Stack(
                      children: [
                        '${p['image_url'] ?? ''}'.isNotEmpty
                            ? Image.network(
                                '${p['image_url']}',
                                height: 104,
                                width: 150,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => _ph(context, 150, 104),
                              )
                            : _ph(context, 150, 104),
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade700,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              s.sponsored,
                              style:  TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: VTheme.text(context),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p['title'] ?? ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${p['price_display'] ?? ''}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: VirelloColors.pink,
                                ),
                              ),
                            ),
                            // Share & earn $0.05 — tracked personal link.
                            Tooltip(
                              message: s.shareEarnHint,
                              child: InkWell(
                                onTap: () =>
                                    ShareEarn.shareProduct(ctx, product: p),
                                borderRadius: BorderRadius.circular(20),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.share_outlined,
                                    size: 16,
                                    color: VirelloColors.muted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _ph(BuildContext context, double w, double h) => Container(
        width: w,
        height: h,
        color: VTheme.chip(context),
        child: const Center(
          child: Icon(
            Icons.shopping_bag_outlined,
            color: VirelloColors.muted,
            size: 24,
          ),
        ),
      );
}
