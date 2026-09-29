import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/ads_models.dart';
import '../../main.dart';
import 'review_campaign_screen.dart';

/// 68 · Campaign Setup — board-faithful wrapper over the REAL campaign
/// builder flow.
///
/// Product card (real image, name, price), setting rows (budget packages,
/// duration, audience), and a pink CTA that creates the campaign through
/// POST /api/v1/ads/campaigns and hands it to the approval-gated Review
/// Campaign screen. Paid boost keeps the verified-payment gate.
class CampaignSetupScreen extends StatefulWidget {
  /// Pre-selected product (from the Shop). Otherwise the user picks one.
  final Map<String, dynamic>? product;
  const CampaignSetupScreen({super.key, this.product});

  @override
  State<CampaignSetupScreen> createState() => _CampaignSetupScreenState();
}

class _CampaignSetupScreenState extends State<CampaignSetupScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  Map<String, dynamic>? _product;
  List<dynamic> _products = [];
  List<AdPackage> _packages = [];
  bool _loading = true;
  bool _creating = false;
  String? _error;

  String _plan = 'free'; // free | paid
  String? _packageId; // paid package id
  String _geoMode = 'ai_recommended'; // ai_recommended | worldwide

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        apiClient.myProducts(),
        apiClient.getAdPackages(),
      ]);
      if (!mounted) return;
      setState(() {
        _products = results[0];
        _packages = results[1] as List<AdPackage>;
        // Default to the popular package for paid.
        final popular = _packages.where((p) => p.popular);
        _packageId =
            (popular.isNotEmpty ? popular.first : _packages.firstOrNull)?.id;
      });
    } catch (_) {
      // honest empty states below
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  AdPackage? get _selectedPackage =>
      _packages.where((p) => p.id == _packageId).firstOrNull;

  String _priceLabel(Map<String, dynamic> p) {
    final display = '${p['price_display'] ?? ''}';
    if (display.isNotEmpty && display != 'null') return display;
    final cents = (p['price_cents'] as num?)?.toInt();
    if (cents != null && cents > 0) {
      return '\$${(cents / 100).toStringAsFixed(2)}';
    }
    return s.p10CheckPriceAmazon; // honest label, never invented
  }

  Future<void> _create() async {
    final product = _product;
    if (product == null || _creating) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final title = '${product['title'] ?? ''}';
      final url = '${product['affiliate_url'] ?? product['url'] ?? ''}';
      final content = url.isNotEmpty ? url : title;
      final pkg = _selectedPackage;
      final res = await apiClient.buildAdCampaign(
        url: url.isNotEmpty ? url : null,
        content: content.isEmpty ? null : content,
        budgetCap: _plan == 'paid' ? pkg?.priceUsd : 0,
        geoMode: _geoMode,
        plan: _plan,
        packageId: _plan == 'paid' ? _packageId : null,
      );
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.p10CampaignCreated)));
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReviewCampaignScreen(campaignId: res.campaign.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = s.growFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(s.p10CampaignSetup,
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: VirelloColors.pink))
          : _product == null
              ? _productPicker()
              : _setupForm(),
    );
  }

  // ---------------------------------------------------------- product picker
  Widget _productPicker() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(s.p10PickProduct,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        const SizedBox(height: 12),
        if (_products.isEmpty)
          VBoardCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: Column(
              children: [
                const Icon(Icons.shopping_bag_outlined,
                    size: 40, color: VirelloColors.boardTextSec),
                const SizedBox(height: 10),
                Text(s.p10NoProductsForCampaign,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13,
                        color: VirelloColors.boardTextSec,
                        height: 1.5)),
              ],
            ),
          )
        else
          for (final p in _products)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _productCard(Map<String, dynamic>.from(p),
                  onTap: () =>
                      setState(() => _product = Map<String, dynamic>.from(p))),
            ),
      ],
    );
  }

  // -------------------------------------------------------------- setup form
  Widget _setupForm() {
    final p = _product!;
    final pkg = _selectedPackage;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _productCard(p, onTap: () => setState(() => _product = null)),
        const SizedBox(height: 14),
        _settingRow(
          icon: Icons.account_balance_wallet_outlined,
          label: s.p10Budget,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _planChip('free', s.p10FreeGrowPlan),
                  const SizedBox(width: 8),
                  _planChip('paid', s.p10PaidBoostPlan),
                ],
              ),
              if (_plan == 'paid' && _packages.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _packages.map((pk) => _packageChip(pk)).toList(),
                ),
              ],
              if (_plan == 'free')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('\$0 · ${s.p10EstimateNote}',
                      style: const TextStyle(
                          fontSize: 11.5, color: VirelloColors.boardTextSec)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _settingRow(
          icon: Icons.schedule_outlined,
          label: s.p10Duration,
          child: Text(
            _plan == 'paid' && pkg != null
                ? '${pkg.durationDays} ${s.p10Days} · \$${pkg.priceUsd.toStringAsFixed(0)}'
                : '7 ${s.p10Days} · \$0',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
        const SizedBox(height: 10),
        _settingRow(
          icon: Icons.public_outlined,
          label: s.p10Audience,
          child: Row(
            children: [
              _geoChip('ai_recommended', 'AI'),
              const SizedBox(width: 8),
              _geoChip('worldwide', 'Worldwide'),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: VirelloColors.danger)),
        ],
        const SizedBox(height: 20),
        VPinkButton(
          label: s.p10CreateCampaign,
          onPressed: _create,
          loading: _creating,
        ),
        const SizedBox(height: 10),
        Text(s.p10ApprovalNote,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11, color: VirelloColors.boardTextSec)),
      ],
    );
  }

  Widget _productCard(Map<String, dynamic> p, {VoidCallback? onTap}) {
    final img = '${p['image_url'] ?? ''}';
    return VBoardCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: img.isNotEmpty
                ? Image.network(img,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imgPlaceholder())
                : _imgPlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p['title'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text(_priceLabel(p),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: VirelloColors.pink)),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right, color: VirelloColors.boardTextSec),
        ],
      ),
    );
  }

  Widget _imgPlaceholder() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: VirelloColors.boardField,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.shopping_bag_outlined,
          color: VirelloColors.boardTextSec),
    );
  }

  Widget _settingRow(
      {required IconData icon, required String label, required Widget child}) {
    return VBoardCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: VirelloColors.pink.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: VirelloColors.pink, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: VirelloColors.boardTextSec)),
                const SizedBox(height: 8),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _planChip(String value, String label) {
    final active = _plan == value;
    return GestureDetector(
      onTap: () => setState(() => _plan = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? VirelloColors.pink : VirelloColors.boardField,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: active ? VirelloColors.pink : VirelloColors.boardBorder),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.white : VirelloColors.boardTextSec,
                fontWeight: FontWeight.w700,
                fontSize: 12.5)),
      ),
    );
  }

  Widget _packageChip(AdPackage pk) {
    final active = _packageId == pk.id;
    return GestureDetector(
      onTap: () => setState(() => _packageId = pk.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? VirelloColors.pink.withValues(alpha: 0.16)
              : VirelloColors.boardField,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: active ? VirelloColors.pink : VirelloColors.boardBorder),
        ),
        child: Column(
          children: [
            Text(pk.name,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? VirelloColors.pink
                        : VirelloColors.boardTextSec)),
            const SizedBox(height: 2),
            Text('\$${pk.priceUsd.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            Text('${pk.durationDays}d',
                style: const TextStyle(
                    fontSize: 10, color: VirelloColors.boardTextSec)),
          ],
        ),
      ),
    );
  }

  Widget _geoChip(String value, String label) {
    final active = _geoMode == value;
    return GestureDetector(
      onTap: () => setState(() => _geoMode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? VirelloColors.pink : VirelloColors.boardField,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: active ? VirelloColors.pink : VirelloColors.boardBorder),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.white : VirelloColors.boardTextSec,
                fontWeight: FontWeight.w700,
                fontSize: 12.5)),
      ),
    );
  }
}
