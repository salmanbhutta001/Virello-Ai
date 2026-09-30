import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../main.dart';
import 'seller_dashboard_screen.dart';

/// Phase 4 — Creator product listing form.
///
/// POSTs to /api/v1/commerce/products. Price is entered in major currency
/// units and converted to cents client-side. Affiliate products require a
/// valid http(s) affiliate URL (validated again server-side); the
/// disclosure is rendered by the product detail screen.
class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _imagesCtrl = TextEditingController();
  final _affUrlCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '1');

  String _currency = 'USD';
  String _category = 'all';
  bool _isAffiliate = false;
  String _affiliateProvider = 'amazon';
  bool _submitting = false;
  String? _error;

  static const _currencies = ['USD', 'PKR', 'GBP', 'EUR', 'AED', 'INR'];
  static const _categories = ['all', 'men', 'women', 'sale'];
  static const _affProviders = ['amazon'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _imagesCtrl.dispose();
    _affUrlCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final priceText = _priceCtrl.text.trim().replaceAll(',', '');
    final price = double.tryParse(priceText);

    // Client-side validation mirrors the backend (which validates again).
    if (title.isEmpty || price == null || price <= 0) {
      setState(() => _error = s.sellNeedTitlePrice);
      return;
    }
    final affUrl = _affUrlCtrl.text.trim();
    if (_isAffiliate) {
      if (!(affUrl.startsWith('http://') || affUrl.startsWith('https://'))) {
        setState(() => _error = s.sellNeedAffiliateUrl);
        return;
      }
    }
    final imageUrls = _imagesCtrl.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(10)
        .toList();
    for (final u in imageUrls) {
      if (!(u.startsWith('http://') || u.startsWith('https://'))) {
        setState(() => _error = s.sellNeedAffiliateUrl);
        return;
      }
    }
    final stock = int.tryParse(_stockCtrl.text.trim()) ?? 0;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await apiClient.createProduct({
        'title': title,
        'description': _descCtrl.text.trim(),
        'price_cents': (price * 100).round(),
        'currency': _currency,
        'category': _category,
        'image_urls': imageUrls,
        'stock_qty': stock < 0 ? 0 : stock,
        'is_affiliate': _isAffiliate,
        'affiliate_url': _isAffiliate ? affUrl : '',
        'affiliate_provider': _isAffiliate ? _affiliateProvider : '',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.sellSuccess)));
      Navigator.of(context).pop(true);
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = s.sellFailed);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(s.sellTitle,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: s.p11SellerDashboard,
            icon: const Icon(Icons.dashboard_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SellerDashboardScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (_error != null) _errorCard(),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: s.sellTitleHint,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 4,
            minLines: 2,
            decoration: InputDecoration(
              labelText: s.sellDescHint,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: s.sellPriceHint,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: InputDecoration(
                    labelText: s.sellCurrency,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  items: _currencies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _currency = v ?? 'USD'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: InputDecoration(
                    labelText: s.sellCategory,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v ?? 'all'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _stockCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: s.sellStockHint,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _imagesCtrl,
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(
              labelText: s.sellImagesHint,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          // Affiliate section.
          SwitchListTile(
            value: _isAffiliate,
            onChanged: (v) => setState(() => _isAffiliate = v),
            title: Text(s.sellIsAffiliate,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            contentPadding: EdgeInsets.zero,
          ),
          if (_isAffiliate) ...[
            TextField(
              controller: _affUrlCtrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: s.sellAffiliateUrlHint,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _affiliateProvider,
              decoration: InputDecoration(
                labelText: s.sellAffiliateProvider,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: _affProviders
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _affiliateProvider = v ?? 'amazon'),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _submitting
                  ?  SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: VTheme.text(context)),
                    )
                  : Text(s.sellSubmit),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VirelloColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VirelloColors.danger.withValues(alpha: 0.3)),
      ),
      child: Text(_error!,
          style: const TextStyle(fontSize: 13, color: VirelloColors.danger)),
    );
  }
}
