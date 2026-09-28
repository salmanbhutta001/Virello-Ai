import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/ads_models.dart';
import '../../services/api_client.dart';
import '../../main.dart';
import '../communities/communities_screen.dart';

/// AI Ad Builder (Phase 1): paste post/link → AI analysis + proposals →
/// edit → submit for approval → status view. Board-styled (2026-09-26):
/// post-summary card, 2×2 objective radio cards, AI-recommended target
/// audience, duration pills, daily-budget slider, gradient primary action.
///
/// Nothing launches without the advertiser's explicit approval:
/// draft → pending approval → approved. Estimates are always labeled
/// "estimate — not a guarantee".
class CampaignBuilderScreen extends StatefulWidget {
  /// When set, opens the status/detail view for an existing campaign.
  final String? campaignId;

  /// Optional pre-filled content (e.g. a caption from an uploaded file).
  final String? initialContent;

  /// Optional local media path carried from Upload Studio (kept optional —
  /// shown as an attached-media note, never sent anywhere silently).
  final String? initialMediaPath;
  const CampaignBuilderScreen(
      {super.key, this.campaignId, this.initialContent, this.initialMediaPath});

  @override
  State<CampaignBuilderScreen> createState() => _CampaignBuilderScreenState();
}

class _CampaignBuilderScreenState extends State<CampaignBuilderScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  final _inputCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();

  bool _busy = false;
  String? _error;
  AdBuildResult? _result; // fresh build
  AdCampaign? _campaign; // loaded or submitted campaign
  AdDeliveryStats? _delivery; // phase 2: spend / impressions / pacing
  AdDashboard? _dashboard; // phase 4: ONE advertiser dashboard payload
  AdInsights? _insights; // phase 3: per-segment/variant/placement performance
  AdOptimizationHistory? _history; // phase 3: run history + decision feed
  bool _optimizing = false;
  List<SegmentMatch> _matches = [];
  String _objective = 'views';
  Set<String> _pickedSegments = {};
  String _langMode = 'single';
  Set<String> _targetLangs = {};
  Map<String, String> _langNames = {}; // code -> "English · native"
  String _geoMode = 'ai_recommended';
  Set<String> _geoCountries = {};
  Map<String, dynamic>? _geoData; // {countries: [{code,name_en}], region_presets: {...}}
  /// Campaign plan picked for a NEW campaign: 'free' (Free Grow —
  /// worldwide, $0) or 'paid' (Paid Boost — package + country targeting).
  /// Immutable once the campaign exists (backend enforces it too).
  String _plan = 'paid';
  bool get _isFree => (_campaign?.isFree ?? _plan == 'free');

  /// Paid Boost package picked for a NEW campaign (packages only — no
  /// manual budgeting). Defaults to the popular package.
  String _packageId = 'growth';
  List<AdPackage> _packages = const [];
  Map<String, dynamic> _freeLimits = const {};
  List<GrowthAgent> _agents = const [];
  bool _plansLoading = false;

  /// Where-to-share: AI-suggested communities for the current post.
  List<dynamic> _suggestedCommunities = [];
  bool _suggestLoading = false;

  /// Connected social accounts gate.
  List<String> _connectedPlatforms = [];
  bool _accountsLoading = false;

  /// Board objective cards → the exact API objective values.
  static const _objectiveValues = ['sales', 'leads', 'engagement', 'followers'];
  static const _durationValues = [1, 3, 7, 14];

  @override
  void initState() {
    super.initState();
    if (widget.initialContent != null && widget.initialContent!.isNotEmpty) {
      _inputCtrl.text = widget.initialContent!;
    } else {
      // Auto-paste link from clipboard if available
      _autoPasteFromClipboard();
    }
    if (widget.campaignId != null) {
      _loadCampaign();
    } else {
      _loadPlans();
    }
    _loadConnectedAccounts();
  }

  /// Load which social platforms the user has connected (account gate).
  Future<void> _loadConnectedAccounts() async {
    setState(() => _accountsLoading = true);
    try {
      final d = await apiClient.getConnectedAccounts();
      if (!mounted) return;
      setState(() {
        _connectedPlatforms =
            ((d['connected'] ?? []) as List).map((e) => e.toString()).toList();
        _accountsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _accountsLoading = false);
    }
  }

  /// AI-suggest communities matching the current post input.
  Future<void> _suggestWhereToShare() async {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) return;
    setState(() => _suggestLoading = true);
    try {
      final suggestions = await apiClient.suggestCommunities(content: input);
      if (!mounted) return;
      setState(() {
        _suggestedCommunities = suggestions;
        _suggestLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _suggestLoading = false);
    }
  }

  /// Auto-fill the input from clipboard if it contains a URL.
  Future<void> _autoPasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) return;
      // Only auto-paste if it looks like a URL
      if ((text.startsWith('http://') || text.startsWith('https://')) &&
          _inputCtrl.text.isEmpty &&
          mounted) {
        setState(() => _inputCtrl.text = text);
      }
    } catch (_) {
      // Clipboard unavailable — user can paste manually
    }
  }

  /// Manual paste button handler.
  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isNotEmpty && mounted) {
        setState(() => _inputCtrl.text = text);
      }
    } catch (_) {}
  }

  Future<void> _loadPlans() async {
    if (_plansLoading) return;
    setState(() => _plansLoading = true);
    try {
      final pkgs = await apiClient.getAdPackages();
      final limits = await apiClient.getAdFreeLimits();
      final agents = await apiClient.getGrowthAgents();
      if (!mounted) return;
      setState(() {
        _packages = pkgs;
        _freeLimits = limits;
        _agents = agents;
        if (pkgs.any((p) => p.id == _packageId) == false && pkgs.isNotEmpty) {
          _packageId = pkgs.firstWhere((p) => p.popular,
              orElse: () => pkgs.first).id;
        }
        _plansLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _plansLoading = false);
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCampaign() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final detail = await apiClient.getAdCampaignDetail(widget.campaignId!);
      final c = detail.campaign;
      if (!mounted) return;
      setState(() {
        _campaign = c;
        _matches = detail.matches;
        _objective = c.objective;
        _pickedSegments = c.segmentIds.toSet();
        _plan = c.plan;
        if (c.packageId != null && c.packageId!.isNotEmpty) {
          _packageId = c.packageId!;
        }
        _langMode = c.languageTargetingMode;
        _targetLangs = c.targetLanguages.toSet();
        _geoMode = c.geoMode;
        _geoCountries = c.geoCountries.toSet();
        _durationCtrl.text = c.durationDays.toString();
        _busy = false;
      });
      _loadLangNames();
      _loadGeoData();
      _loadPlans();
      _refreshDelivery();
      _refreshDashboard();
      _refreshOptimization();
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = s.adBuildFailed;
      });
    }
  }

  Future<void> _build() async {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _campaign = null;
    });
    try {
      final isUrl = input.startsWith('http://') || input.startsWith('https://');
      final r = await apiClient.buildAdCampaign(
        url: isUrl ? input : null,
        content: isUrl ? null : input,
        // Free Grow: no budget, no package. Paid Boost: package only —
        // no manual budgeting in the UI.
        packageId: _plan == 'free' ? null : _packageId,
        plan: _plan,
      );
      if (!mounted) return;
      setState(() {
        _result = r;
        _campaign = r.campaign;
        _matches = r.matches;
        _objective = r.proposal.objective;
        _pickedSegments = r.proposal.segmentIds.toSet();
        _plan = r.campaign.plan;
        _langMode = r.campaign.languageTargetingMode;
        _targetLangs = r.campaign.targetLanguages.toSet();
        _geoMode = r.campaign.geoMode;
        _geoCountries = r.campaign.geoCountries.toSet();
        _durationCtrl.text = r.proposal.durationDays.toString();
        _busy = false;
      });
      _loadLangNames();
      _loadGeoData();
      _suggestWhereToShare(); // Auto-suggest communities for this post.
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = s.adBuildFailed;
      });
    }
  }

  Future<void> _applyEdits(Map<String, dynamic> patch, String okMsg) async {
    final c = _campaign;
    if (c == null) return;
    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{
        'objective': _objective,
        'duration_days': int.tryParse(_durationCtrl.text.trim()) ?? 7,
        'segment_ids': _pickedSegments.toList(),
        ...patch,
      };
      if (c.isPaid) {
        // Paid Boost: package only — no manual budgeting. Switching the
        // package resets budget AND duration to the package's fixed values.
        body['package_id'] = _packageId;
      }
      // Free Grow: never send budget or package — backend rejects both.
      final updated = await apiClient.patchAdCampaign(c.id, body);
      if (!mounted) return;
      setState(() {
        _campaign = updated;
        _busy = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(okMsg)));
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.adBuildFailed)));
    }
  }

  /// One-tap flow: build → submit → approve → launch.
  /// For users who want to go live immediately from this screen.
  /// Requires at least one connected social account (account gate).
  Future<void> _buildAndLaunch() async {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste a link or text first')),
      );
      return;
    }
    // Account gate: must connect at least one social account first.
    if (_connectedPlatforms.isEmpty && !_accountsLoading) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Connect social account'),
          content: const Text(
            'Connect at least one social media account before launching '
            'a campaign, so Virello can attribute and distribute your post.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Connect now'),
            ),
          ],
        ),
      );
      if (go == true && mounted) {
        // Navigate to social connections (profile → connect accounts).
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Connect accounts from Profile → Settings')),
        );
      }
      return;
    }
    setState(() => _busy = true);
    try {
      // Step 1: Build
      await _build();
      final c = _campaign;
      if (c == null || !mounted) {
        setState(() => _busy = false);
        return;
      }
      // Step 2: Submit for approval (draft -> pending_approval)
      if (c.isDraft) {
        final submitted = await apiClient.patchAdCampaign(
            c.id, {'status': 'pending_approval'});
        if (!mounted) return;
        setState(() => _campaign = submitted);
      }
      // Step 3: Approve
      final approved = await apiClient.approveAdCampaign(_campaign!.id);
      if (!mounted) return;
      setState(() => _campaign = approved);
      // Step 4: Launch
      final launched = await apiClient.launchAdCampaign(_campaign!.id);
      if (!mounted) return;
      setState(() {
        _campaign = launched;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Campaign is now Live!')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Launch failed. Try step by step.')),
      );
    }
  }

  Future<void> _approve() async {
    final c = _campaign;
    if (c == null) return;
    setState(() => _busy = true);
    try {
      final updated = await apiClient.approveAdCampaign(c.id);
      if (!mounted) return;
      setState(() {
        _campaign = updated;
        _busy = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.adApprovedToast)));
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.adBuildFailed)));
    }
  }

  Future<void> _reject() async {
    final c = _campaign;
    if (c == null) return;
    setState(() => _busy = true);
    try {
      final updated = await apiClient.rejectAdCampaign(c.id);
      if (!mounted) return;
      setState(() {
        _campaign = updated;
        _busy = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.adRejectedToast)));
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  String _statusLabel(String status) => switch (status) {
        'draft' => s.adStatusDraft,
        'pending_approval' => s.adStatusPending,
        'approved' => s.adStatusApproved,
        'rejected' => s.adStatusRejected,
        'active' => s.adStatusActive,
        'paused' => s.adStatusPaused,
        'completed' => s.adStatusCompleted,
        _ => status,
      };

  Color _statusColor(String status) => switch (status) {
        'approved' => Colors.green,
        'active' => Colors.green,
        'pending_approval' => Colors.orange,
        'paused' => Colors.orange,
        'rejected' => Colors.red,
        _ => Colors.blueGrey,
      };

  /// Phase 2: refresh delivery stats for delivering campaigns.
  Future<void> _refreshDelivery() async {
    final c = _campaign;
    if (c == null || !(c.isActive || c.isPaused || c.isCompleted)) {
      if (mounted) setState(() => _delivery = null);
      return;
    }
    try {
      final d = await apiClient.getAdDelivery(c.id);
      if (!mounted) return;
      setState(() => _delivery = d);
    } catch (_) {
      // Delivery stats are informational — never block the screen.
    }
  }

  /// Phase 4: refresh the ONE advertiser dashboard payload.
  Future<void> _refreshDashboard() async {
    final c = _campaign;
    if (c == null || !(c.isActive || c.isPaused || c.isCompleted)) {
      if (mounted) setState(() => _dashboard = null);
      return;
    }
    try {
      final d = await apiClient.getAdDashboard(c.id);
      if (!mounted) return;
      setState(() => _dashboard = d);
    } catch (_) {
      // Dashboard data is informational — never block the screen.
    }
  }

  /// Phase 3: refresh insights + optimization history.
  Future<void> _refreshOptimization() async {
    final c = _campaign;
    if (c == null || !(c.isActive || c.isPaused || c.isCompleted)) {
      if (mounted) {
        setState(() {
          _insights = null;
          _history = null;
        });
      }
      return;
    }
    try {
      final ins = await apiClient.getAdInsights(c.id);
      final hist = await apiClient.getAdOptimizations(c.id);
      if (!mounted) return;
      setState(() {
        _insights = ins;
        _history = hist;
      });
    } catch (_) {
      // Optimization data is informational — never block the screen.
    }
  }

  /// Phase 3: run the AI Optimization Agent right now.
  Future<void> _optimizeNow() async {
    final c = _campaign;
    if (c == null || _optimizing) return;
    setState(() {
      _optimizing = true;
      _error = null;
    });
    try {
      await apiClient.optimizeAdCampaign(c.id);
      if (!mounted) return;
      await _refreshOptimization();
      await _refreshDashboard();
      if (!mounted) return;
      setState(() => _optimizing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.adOptimizedToast)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _optimizing = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.adOptimizeFailed)));
    }
  }

  Future<void> _launch() => _lifecycle(
      () => apiClient.launchAdCampaign(_campaign!.id), s.adLaunchedToast);

  Future<void> _pause() => _lifecycle(
      () => apiClient.pauseAdCampaign(_campaign!.id), s.adPausedToast);

  Future<void> _resume() => _lifecycle(
      () => apiClient.resumeAdCampaign(_campaign!.id), s.adResumedToast);

  Future<void> _lifecycle(
      Future<AdCampaign> Function() call, String okMsg) async {
    final c = _campaign;
    if (c == null) return;
    setState(() => _busy = true);
    try {
      final updated = await call();
      if (!mounted) return;
      setState(() {
        _campaign = updated;
        _busy = false;
      });
      await _refreshDelivery();
      await _refreshDashboard();
      await _refreshOptimization();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(okMsg)));
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.adBuildFailed)));
    }
  }

  // ---------------- board label/icon maps (display only) ----------------

  String _objectiveLabel(String v) => switch (v) {
        'sales' => s.salesObj,
        'leads' => s.leadsObj,
        'engagement' => s.engagementObj,
        'followers' => s.followersObj,
        _ => v,
      };

  String _objectiveDesc(String v) => switch (v) {
        'sales' => s.salesObjDesc,
        'leads' => s.leadsObjDesc,
        'engagement' => s.engagementObjDesc,
        'followers' => s.followersObjDesc,
        _ => '',
      };

  IconData _objectiveIcon(String v) => switch (v) {
        'sales' => Icons.shopping_cart_outlined,
        'leads' => Icons.person_add_alt_outlined,
        'engagement' => Icons.favorite_border,
        'followers' => Icons.group_outlined,
        _ => Icons.flag_outlined,
      };

  String _durationLabel(int days) {
    final i = _durationValues.indexOf(days);
    if (i < 0) return '$days';
    return [s.day1, s.day3, s.day7, s.day14][i];
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.adBuilder)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.campaignId == null && _campaign == null) ...[
            Text(s.adBuilderTagline,
                style: const TextStyle(
                    fontSize: 13, color: VirelloColors.mutedDark)),
            const SizedBox(height: 12),
            _inputCard(),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!,
                  style: const TextStyle(color: VirelloColors.danger)),
            ),
          if (_busy && _campaign == null && _result == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(children: [
                const CircularProgressIndicator(color: VirelloColors.violet),
                const SizedBox(height: 12),
                Text(s.adBuilding,
                    style: const TextStyle(color: VirelloColors.muted)),
              ]),
            ),
          if (_campaign != null) ..._campaignBody(),
        ],
      ),
    );
  }

  Widget _inputCard() => VCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.adPasteLabel,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            TextField(
              controller: _inputCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: s.adPasteHint,
                hintStyle: const TextStyle(color: VirelloColors.muted),
                filled: true,
                fillColor: VirelloColors.chipBg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste_outlined),
                  tooltip: 'Paste from clipboard',
                  onPressed: _pasteFromClipboard,
                ),
              ),
            ),
            // Media carried over from Upload Studio (optional; shown only).
            if (widget.initialMediaPath != null &&
                widget.initialMediaPath!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.attach_file_outlined, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${s.attachedMedia}: ${widget.initialMediaPath!.split('/').last}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: VirelloColors.muted),
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 12),
            _planPicker(),
            const SizedBox(height: 12),
            // Analyze button moved up — visible without scrolling through plan details.
            VGradientButton(
              label: s.adAnalyzeBuild,
              icon: Icons.auto_awesome_outlined,
              onPressed: _busy ? null : _build,
            ),
            const SizedBox(height: 8),
            // Quick launch: build + approve + launch in one tap.
            VGradientButton(
              label: 'Build & Launch Now',
              icon: Icons.rocket_launch_outlined,
              onPressed: _busy ? null : _buildAndLaunch,
            ),
            const SizedBox(height: 12),
            _whereToShareCard(),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            // Two fully separate modules: switching plans swaps everything
            // below — Free Grow has no packages; Paid Boost is package-driven.
            if (_plan == 'free') _freeModule() else _paidModule(),
          ],
        ),
      );

  /// Free Grow vs Paid Boost — two clearly separate cards, immutable after
  /// the campaign is created.

  /// Where-to-share: AI-suggested communities for this post.
  /// Users share manually — Virello never auto-posts.
  Widget _whereToShareCard() {
    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_outlined,
                  color: VirelloColors.primary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Where to Share',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              TextButton.icon(
                onPressed: _suggestLoading ? null : _suggestWhereToShare,
                icon: _suggestLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome_outlined, size: 16),
                label: const Text('Suggest'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'AI finds public communities where your audience hangs out. '
            'You share manually — Virello never auto-posts.',
            style: TextStyle(fontSize: 12, color: VirelloColors.muted),
          ),
          if (_suggestedCommunities.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final c in _suggestedCommunities.take(5))
              _suggestedCommunityRow(c),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CommunitiesScreen()),
              );
            },
            icon: const Icon(Icons.explore_outlined, size: 18),
            label: const Text('Browse all communities'),
          ),
        ],
      ),
    );
  }

  Widget _suggestedCommunityRow(dynamic c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.forum_outlined,
              size: 18, color: VirelloColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c['name'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                if ((c['match_reason'] ?? '').toString().isNotEmpty)
                  Text(c['match_reason'],
                      style: const TextStyle(
                          fontSize: 11, color: VirelloColors.muted)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _shareToCommunity(c),
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  /// One-tap share sheet — user reviews and posts manually.
  Future<void> _shareToCommunity(dynamic c) async {
    final name = c['name'] ?? 'community';
    final url = c['url'] ?? '';
    final input = _inputCtrl.text.trim();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Share to $name',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Open $name and share your post there manually. '
                'Always follow the community rules — no spam.',
                style: const TextStyle(
                    fontSize: 13, color: VirelloColors.muted),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.tryParse(url);
                  if (uri != null) {
                    // ignore: avoid_print
                    debugPrint('Opening community: $url');
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Open $name in your browser and paste:\n$input')),
                    );
                  }
                },
                icon: const Icon(Icons.open_in_new_outlined),
                label: const Text('Open community'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _planPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.choosePlan,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _planOption(
          plan: 'free',
          icon: Icons.public_outlined,
          title: s.freeGrow,
          tag: s.freeGrowTag,
          selected: _plan == 'free',
        ),
        const SizedBox(height: 8),
        _planOption(
          plan: 'paid',
          icon: Icons.rocket_launch_outlined,
          title: s.paidBoost,
          tag: s.paidBoostTag,
          selected: _plan == 'paid',
        ),
      ],
    );
  }

  Widget _planOption(
      {required String plan,
      required IconData icon,
      required String title,
      required String tag,
      required bool selected}) {
    return GestureDetector(
      onTap: () => setState(() => _plan = plan),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? VirelloColors.violet : VirelloColors.chipBg,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? VirelloColors.violet.withValues(alpha: 0.08)
              : VirelloColors.chipBg,
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected
                  ? VirelloColors.violet
                  : VirelloColors.muted.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                color: Colors.white,
                size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(tag,
                      style: const TextStyle(
                          fontSize: 12, color: VirelloColors.muted)),
                ]),
          ),
          if (selected)
            const Icon(Icons.check_circle,
                color: VirelloColors.violet, size: 24),
        ]),
      ),
    );
  }

  /// FREE GROW MODULE — description + its own limits. No packages here.
  Widget _freeModule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _moduleHeader(
          icon: Icons.public_outlined,
          color: Colors.teal,
          title: s.freeGrow,
          badge: s.freeModuleBadge,
        ),
        const SizedBox(height: 8),
        VCard(
          child: Row(children: [
            const Icon(Icons.eco_outlined, color: Colors.teal, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text(s.freeGrowDesc,
                    style: const TextStyle(fontSize: 13, height: 1.4))),
          ]),
        ),
        const SizedBox(height: 8),
        _freeLimitsCard(),
      ],
    );
  }

  /// PAID BOOST MODULE — description + package picker (the package IS the
  /// budget) + its own limits. No manual budget inputs anywhere.
  Widget _paidModule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _moduleHeader(
          icon: Icons.rocket_launch_outlined,
          color: VirelloColors.violet,
          title: s.paidBoost,
          badge: s.paidModuleBadge,
        ),
        const SizedBox(height: 8),
        VCard(
          child: Row(children: [
            const Icon(Icons.rocket_launch_outlined,
                color: VirelloColors.violet, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text(s.paidBoostDesc,
                    style: const TextStyle(fontSize: 13, height: 1.4))),
          ]),
        ),
        const SizedBox(height: 12),
        _packagePicker(),
        const SizedBox(height: 8),
        _paidLimitsCard(),
      ],
    );
  }

  /// Distinct tinted header per module so free vs paid is unmistakable.
  Widget _moduleHeader(
      {required IconData icon,
      required Color color,
      required String title,
      required String badge}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
          child: Text(badge,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  /// Free Grow limits card — visible proof of what "limited" means.
  Widget _freeLimitsCard() {
    final rawCampaigns = _freeLimits['max_active_campaigns'];
    final rawImpressions = _freeLimits['max_impressions_per_campaign'];
    final maxCampaigns =
        rawCampaigns is int ? rawCampaigns : int.tryParse('$rawCampaigns') ?? 3;
    final maxImpressions = rawImpressions is int
        ? rawImpressions
        : int.tryParse('$rawImpressions') ?? 1000;
    final impressionsFmt = maxImpressions.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.info_outline, color: Colors.teal, size: 18),
          const SizedBox(width: 8),
          Text(s.freeGrowLimits,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        _limitRow(Icons.campaign_outlined,
            s.freeLimitCampaignsN(maxCampaigns)),
        _limitRow(Icons.visibility_outlined,
            s.freeLimitImpressionsN(impressionsFmt)),
        _limitRow(Icons.trending_down_outlined, s.freeWindDown),
        _limitRow(Icons.public_outlined, s.freeWorldwideOnly),
        _limitRow(Icons.money_off_outlined, s.freeNoBudget),
      ]),
    );
  }

  /// Paid Boost limits card — separate from Free Grow's limits.
  Widget _paidLimitsCard() {
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.info_outline,
              color: VirelloColors.violet, size: 18),
          const SizedBox(width: 8),
          Text(s.paidLimitsTitle,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        _limitRow(Icons.lock_outlined, s.paidLimitSpend),
        _limitRow(Icons.schedule_outlined, s.paidLimitDuration),
        _limitRow(Icons.public_outlined, s.paidLimitCountries),
        _limitRow(Icons.block_outlined, s.planLockedNote),
      ]),
    );
  }

  Widget _limitRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 16, color: VirelloColors.muted),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 12.5, color: VirelloColors.muted))),
        ]),
      );

  /// Paid Boost package picker — fixed packages, no manual budgeting.
  Widget _packagePicker() {
    if (_plansLoading) {
      return const VCard(
          child: Center(
              child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(color: VirelloColors.violet),
      )));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(s.choosePackage,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.account_balance_wallet_outlined,
              size: 14, color: VirelloColors.violet),
          const SizedBox(width: 6),
          Expanded(
            child: Text(s.packageIsBudget,
                style: const TextStyle(
                    fontSize: 12,
                    color: VirelloColors.violet,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 8),
        ..._packages.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _packageOption(p),
            )),
      ],
    );
  }

  Widget _packageOption(AdPackage p) {
    final selected = _packageId == p.id;
    return GestureDetector(
      onTap: () => setState(() => _packageId = p.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? VirelloColors.violet : VirelloColors.chipBg,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? VirelloColors.violet.withValues(alpha: 0.08)
              : VirelloColors.chipBg,
        ),
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(p.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    if (p.popular) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: VirelloColors.violet,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(s.packagePopular,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(s.packageDays(p.durationDays),
                      style: const TextStyle(
                          fontSize: 12, color: VirelloColors.muted)),
                ]),
          ),
          Text('\$${p.priceUsd.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: VirelloColors.violetDeep)),
          const SizedBox(width: 8),
          if (selected)
            const Icon(Icons.check_circle,
                color: VirelloColors.violet, size: 24),
        ]),
      ),
    );
  }

  /// Board order: post summary → AI analysis → objective → target audience
  /// → duration → budget → primary action → (informational sections).
  List<Widget> _campaignBody() {
    final free = _isFree;
    final sections = <Widget>[
      _postSummaryCard(),
      _planAgentBanner(),
      if (_result != null) _analysisCard(),
      _objectiveCard(),
      _matchesCard(),
      if (!free) _geographyCard(),
      if (free) _durationCard(),
      if (!free) _packageCard() else const SizedBox.shrink(),
      _actionsCard(),
      _languageTargetingCard(),
      _estimateCard(),
      _deliveryCard(),
      _dashboardCard(),
      _optimizationCard(),
    ];
    return sections.expand((w) => [w, const SizedBox(height: 12)]).toList();
  }

  /// Plan is immutable after creation: which plan this campaign runs on,
  /// and which AI agent manages it.
  Widget _planAgentBanner() {
    final c = _campaign!;
    final free = c.isFree;
    final agent = _agents.firstWhere((a) => a.id == c.growthAgent,
        orElse: () => GrowthAgent(
            id: c.growthAgent,
            name: free ? 'Free Grow AI' : 'Paid Boost AI',
            tagline: free ? s.freeGrowAiDesc : s.paidBoostAiDesc,
            manages: c.plan));
    return VCard(
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: free ? Colors.teal : VirelloColors.violet,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(free ? Icons.public_outlined : Icons.rocket_launch_outlined,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(free ? s.freeGrow : s.paidBoost,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(free ? s.managedByFreeAi : s.managedByPaidAi,
                    style: const TextStyle(
                        fontSize: 12, color: VirelloColors.muted)),
                const SizedBox(height: 2),
                Text(agent.tagline,
                    style: const TextStyle(
                        fontSize: 11.5, color: VirelloColors.muted)),
                const SizedBox(height: 4),
                Text(s.planLockedNote,
                    style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: VirelloColors.muted)),
              ]),
        ),
      ]),
    );
  }

  /// Paid Boost package card on an existing campaign: package name, price,
  /// duration; editable while the campaign is a draft (switching resets
  /// budget + duration to the package's fixed values).
  Widget _packageCard() {
    final c = _campaign!;
    final editable = c.isDraft;
    final current =
        _packages.firstWhere((p) => p.id == (c.packageId ?? _packageId),
            orElse: () => _packages.isNotEmpty
                ? _packages.first
                : const AdPackage(
                    id: '', name: '', priceUsd: 0, durationDays: 7));
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(s.choosePackage,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800))),
          if (current.name.isNotEmpty)
            Text('\$${current.priceUsd.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: VirelloColors.violetDeep)),
        ]),
        const SizedBox(height: 4),
        if (current.name.isNotEmpty)
          Text('${current.name} · ${s.packageDays(current.durationDays)}',
              style:
                  const TextStyle(fontSize: 13, color: VirelloColors.muted)),
        if (editable && _packages.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._packages.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _packageOption(p),
              )),
        ],
        const SizedBox(height: 4),
        Text(s.budgetNeverExceeded,
            style: const TextStyle(fontSize: 12, color: VirelloColors.muted)),
      ]),
    );
  }

  /// Board post-summary card: title + platform/language/status chips.
  /// Built only from real campaign + analysis-signal data.
  Widget _postSummaryCard() {
    final c = _campaign!;
    final sig = _result?.signals ?? const <String, dynamic>{};
    final titleRaw = sig['title'];
    final title = (titleRaw is String && titleRaw.trim().isNotEmpty)
        ? titleRaw.trim()
        : c.contentRef;
    final languageRaw = sig['language'];
    final language = (languageRaw is String && languageRaw.isNotEmpty)
        ? languageRaw
        : (c.languages.isNotEmpty ? c.languages.first : '');
    final platformRaw = sig['platform'];
    final platform =
        platformRaw is String && platformRaw.isNotEmpty ? platformRaw : '';
    final scoreRaw = sig['analysis_score'];
    final score = scoreRaw is num ? scoreRaw.toInt() : null;
    return VCard(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: VirelloColors.violet.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.link, color: VirelloColors.violet, size: 30),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              title.isEmpty ? c.contentRef : title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (platform.isNotEmpty) _miniChip(platform, tinted: true),
              if (language.isNotEmpty && language != 'unknown')
                _miniChip(language.toUpperCase(), tinted: true),
              _statusChip(c.status),
              if (score != null) _miniChip('$score/100'),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _miniChip(String label, {bool tinted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tinted
            ? VirelloColors.violet.withValues(alpha: 0.1)
            : VirelloColors.chipBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color:
                  tinted ? VirelloColors.violetDeep : VirelloColors.mutedDark)),
    );
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(_statusLabel(status),
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: color)),
    );
  }

  Widget _analysisCard() {
    final sig = _result!.signals;
    final topics = ((sig['topics'] as List?) ?? []).join(', ');
    final tags = ((sig['hashtags'] as List?) ?? []).take(8).join('  ');
    final score = (sig['analysis_score'] as num? ?? 0).toInt();
    return VCard(
      child: Row(children: [
        VScoreRing(score: score.toDouble(), size: 84),
        const SizedBox(width: 16),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.adAnalysis,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${s.contentScore}: $score/100',
                style: const TextStyle(
                    fontSize: 12, color: VirelloColors.mutedDark)),
            if (topics.isNotEmpty)
              Text(topics,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: VirelloColors.muted)),
            Text('${sig['language'] ?? 'unknown'}',
                style:
                    const TextStyle(fontSize: 12, color: VirelloColors.muted)),
            if (tags.isNotEmpty)
              Text(tags,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: VirelloColors.violetDeep)),
          ]),
        ),
      ]),
    );
  }

  /// Board Objective: 2×2 radio cards. Only the labels change — the API
  /// values sent on save are exactly the ones the backend accepts.
  Widget _objectiveCard() {
    final c = _campaign!;
    final editable = c.isDraft;
    final knownSelection = _objectiveValues.contains(_objective);
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        VSectionHeader(title: s.objective),
        if (_result != null && _result!.proposal.rationale.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_result!.proposal.rationale,
              style: const TextStyle(
                  fontSize: 13, color: VirelloColors.mutedDark)),
        ],
        if (_result != null) ...[
          const SizedBox(height: 6),
          Text(_result!.usedAi ? s.adAiNote : s.adHeuristicNote,
              style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: VirelloColors.muted)),
        ],
        const SizedBox(height: 12),
        if (editable) ...[
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.9,
            children: _objectiveValues.map((v) {
              final on = v == _objective;
              return GestureDetector(
                onTap: () => setState(() => _objective = v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: on ? const Color(0xFFF7F4FF) : Colors.white,
                    border: Border.all(
                        color:
                            on ? VirelloColors.violet : VirelloColors.divider,
                        width: on ? 2 : 1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(children: [
                        Icon(_objectiveIcon(v),
                            size: 18,
                            color: on
                                ? VirelloColors.violet
                                : VirelloColors.muted),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(_objectiveLabel(v),
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: on
                                      ? VirelloColors.violetDeep
                                      : VirelloColors.ink)),
                        ),
                      ]),
                      const SizedBox(height: 3),
                      Text(_objectiveDesc(v),
                          style: const TextStyle(
                              fontSize: 11.5, color: VirelloColors.muted)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (!knownSelection) ...[
            const SizedBox(height: 8),
            Text('${s.adObjective}: $_objective',
                style:
                    const TextStyle(fontSize: 12, color: VirelloColors.muted)),
          ],
        ] else
          _miniChip(
              '${_objectiveLabel(_objective)}${_objectiveDesc(_objective).isNotEmpty ? ' · ${_objectiveDesc(_objective)}' : ''}',
              tinted: true),
      ]),
    );
  }

  /// Board Target Audience: section header with the AI Recommended pill,
  /// then the same editable checkboxes / read-only expansion rows.
  Widget _matchesCard() {
    final editable = _campaign?.isDraft ?? false;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      VSectionHeader(title: s.targetAudience, actionLabel: s.aiRecommended),
      const SizedBox(height: 10),
      VCard(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Column(children: [
          for (final m in _matches.take(5))
            editable ? _matchCheckRow(m) : _matchExpansion(m),
          if (_matches.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(s.nothingHere,
                  style: const TextStyle(color: VirelloColors.muted)),
            ),
        ]),
      ),
    ]);
  }

  Widget _matchCheckRow(SegmentMatch m) {
    final picked = _pickedSegments.contains(m.segmentId);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() {
        if (picked) {
          _pickedSegments.remove(m.segmentId);
        } else {
          _pickedSegments.add(m.segmentId);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: picked
                  ? VirelloColors.success.withValues(alpha: 0.15)
                  : VirelloColors.chipBg,
            ),
            child: Icon(picked ? Icons.check : Icons.add,
                size: 16,
                color: picked ? const Color(0xFF159A5E) : VirelloColors.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.name,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              if (m.reasons.isNotEmpty)
                Text(m.reasons.first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: VirelloColors.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          _scorePill(m.score),
        ]),
      ),
    );
  }

  Widget _scorePill(double score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: VirelloColors.violet.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(score.toStringAsFixed(2),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: VirelloColors.violetDeep)),
    );
  }

  Widget _matchExpansion(SegmentMatch m) {
    return ExpansionTile(
      shape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Row(children: [
        Expanded(
          child: Text(m.name,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        _scorePill(m.score),
      ]),
      subtitle: m.reasons.isNotEmpty
          ? Text(m.reasons.first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: VirelloColors.muted))
          : null,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.adWhyThisSegment,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              for (final r in m.reasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('• $r',
                      style: const TextStyle(
                          fontSize: 12, color: VirelloColors.mutedDark)),
                ),
              const SizedBox(height: 4),
              for (final c in m.contributions)
                Text(
                    '• ${c.factor}: ${(c.contribution * 100).toStringAsFixed(1)}% — ${c.reason}',
                    style: const TextStyle(
                        fontSize: 11.5, color: VirelloColors.muted)),
            ],
          ),
        ),
      ],
    );
  }

  /// Board Duration: pill tabs mapping to the same duration values.
  Widget _durationCard() {
    final c = _campaign!;
    final editable = c.isDraft;
    final current = int.tryParse(_durationCtrl.text.trim()) ?? 7;
    var selected = _durationValues.indexOf(current);
    if (selected < 0) selected = _durationValues.indexOf(7);
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        VSectionHeader(title: s.duration),
        const SizedBox(height: 10),
        if (editable)
          VPillTabs(
            tabs: [s.day1, s.day3, s.day7, s.day14],
            selected: selected,
            onTap: (i) => setState(
                () => _durationCtrl.text = _durationValues[i].toString()),
          )
        else
          Text(_durationLabel(current),
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ]),
    );
  }


  Future<void> _loadLangNames() async {
    if (_langNames.isNotEmpty) return;
    try {
      final langs = await apiClient.listLanguages();
      final map = <String, String>{};
      for (final e in (langs['languages'] as List)) {
        final m = Map<String, dynamic>.from(e as Map);
        map[m['code'] as String] =
            '${m['name_en']} · ${m['name_native'] ?? ''}';
      }
      if (mounted) setState(() => _langNames = map);
    } catch (_) {}
  }

  String _langLabel(String code) => _langNames[code] ?? code;

  Future<void> _saveLanguageTargeting() {
    return _applyEdits({
      'language_targeting_mode': _langMode,
      'target_languages': _targetLangs.toList(),
    }, s.savedDone);
  }

  Widget _languageTargetingCard() {
    final c = _campaign;
    if (c == null) return const SizedBox.shrink();
    final editable = c.isDraft;
    final modes = ['single', 'multiple', 'all_relevant'];
    final modeLabel = {
      'single': s.langModeSingle,
      'multiple': s.langModeMultiple,
      'all_relevant': s.langModeAllRelevant,
    };
    // Candidate languages: detected + currently targeted + AI-suggested.
    final candidates = <String>{
      ...c.languages,
      ..._targetLangs,
      for (final sg in c.suggestedLanguages) '${sg['code']}',
    };
    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VSectionHeader(title: s.langTargetingMode),
          const SizedBox(height: 8),
          if (editable)
            DropdownButton<String>(
              value: modes.contains(_langMode) ? _langMode : 'single',
              items: modes
                  .map((m) => DropdownMenuItem(
                      value: m, child: Text(modeLabel[m] ?? m)))
                  .toList(),
              onChanged: (v) => setState(() => _langMode = v ?? 'single'),
            )
          else
            Text(modeLabel[_langMode] ?? _langMode,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_langMode != 'all_relevant') ...[
            Text(s.langSelectLanguages,
                style:
                    const TextStyle(fontSize: 12, color: VirelloColors.muted)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: candidates.map((code) {
                final selected = _targetLangs.contains(code);
                return FilterChip(
                  label: Text(_langLabel(code)),
                  selected: selected,
                  selectedColor: VirelloColors.violet.withValues(alpha: 0.15),
                  checkmarkColor: VirelloColors.violet,
                  onSelected: editable
                      ? (v) => setState(() {
                            if (v) {
                              _targetLangs.add(code);
                            } else {
                              _targetLangs.remove(code);
                            }
                          })
                      : null,
                );
              }).toList(),
            ),
          ] else
            Text(s.langAllRelevantDesc,
                style:
                    const TextStyle(fontSize: 12, color: VirelloColors.muted)),
          if (c.suggestedLanguages.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(s.langSuggested,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            Text(s.langSuggestedDesc,
                style:
                    const TextStyle(fontSize: 12, color: VirelloColors.muted)),
            ...c.suggestedLanguages.map((sg) => ExpansionTile(
                  shape: const Border(),
                  title: Text(_langLabel('${sg['code']}'),
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text(s.langWhySuggested,
                      style: const TextStyle(fontSize: 11)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text('${sg['reason'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 12, color: VirelloColors.mutedDark)),
                    ),
                  ],
                )),
          ],
          if (editable) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : _saveLanguageTargeting,
                child: Text(s.saveChanges,
                    style: const TextStyle(color: VirelloColors.violet)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Audience geography: AI Recommended (default) / Worldwide / custom
  /// countries, with quick region presets and a searchable country picker.
  /// AI suggests, the advertiser approves — the approval gate stays intact.
  Future<void> _loadGeoData() async {
    if (_geoData != null) return;
    try {
      final j = await apiClient.getGeoCountries();
      if (!mounted) return;
      setState(() => _geoData = j);
    } catch (_) {}
  }

  String _countryName(String code) {
    final list = (_geoData?['countries'] as List?) ?? const [];
    for (final e in list) {
      final m = Map<String, dynamic>.from(e as Map);
      if ('${m['code']}' == code) return '${m['name_en']}';
    }
    return code;
  }

  Future<void> _saveGeography() {
    if (_geoMode == 'custom' && _geoCountries.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.geoNeedCountry)));
      return Future.value();
    }
    return _applyEdits({
      'geo_mode': _geoMode,
      'geo_countries': _geoCountries.toList(),
    }, s.savedDone);
  }

  Widget _geographyCard() {
    final c = _campaign;
    if (c == null) return const SizedBox.shrink();
    final editable = c.isDraft;
    final suggestion = c.suggestedGeography;
    final suggested = ((suggestion['countries'] as List?) ?? [])
        .map((e) => '$e')
        .toList();
    final reasons =
        ((suggestion['reasons'] as List?) ?? []).map((e) => '$e').toList();
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        VSectionHeader(title: s.geoTitle),
        const SizedBox(height: 10),
        _geoOption(
          value: 'ai_recommended',
          icon: Icons.auto_awesome_outlined,
          title: s.geoAiRecommended,
          desc: s.geoAiRecommendedDesc,
          editable: editable,
        ),
        const SizedBox(height: 8),
        _geoOption(
          value: 'worldwide',
          icon: Icons.public_outlined,
          title: s.geoWorldwide,
          desc: s.geoWorldwideDesc,
          editable: editable,
        ),
        const SizedBox(height: 8),
        _geoOption(
          value: 'custom',
          icon: Icons.flag_outlined,
          title: s.geoCustom,
          desc: s.geoCustomDesc,
          editable: editable,
        ),
        if (_geoMode == 'ai_recommended' && suggested.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: suggested
                .map((code) =>
                    _miniChip('${_countryName(code)} ($code)', tinted: true))
                .toList(),
          ),
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 4),
            ExpansionTile(
              shape: const Border(),
              tilePadding: EdgeInsets.zero,
              title: Text(s.geoWhyThese,
                  style: const TextStyle(fontSize: 13)),
              children: [
                for (final r in reasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $r',
                        style: const TextStyle(
                            fontSize: 12, color: VirelloColors.mutedDark)),
                  ),
              ],
            ),
          ],
          Text(s.geoAiNote,
              style: const TextStyle(fontSize: 12, color: VirelloColors.muted)),
        ],
        if (_geoMode == 'custom') ...[
          const SizedBox(height: 10),
          if (_geoData != null) ...[
            Text(s.geoQuickRegions,
                style:
                    const TextStyle(fontSize: 12, color: VirelloColors.muted)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  ((_geoData!['region_presets'] as Map?) ?? {}).entries.map((e) {
                final p = Map<String, dynamic>.from(e.value as Map);
                final codes =
                    ((p['countries'] as List?) ?? []).map((x) => '$x').toSet();
                final active = _geoCountries.length == codes.length &&
                    _geoCountries.containsAll(codes);
                return FilterChip(
                  label: Text('${p['name_en']}'),
                  selected: active,
                  selectedColor: VirelloColors.violet.withValues(alpha: 0.15),
                  checkmarkColor: VirelloColors.violet,
                  onSelected: editable
                      ? (_) => setState(() => _geoCountries = codes)
                      : null,
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final code in _geoCountries)
                Chip(
                  label: Text('${_countryName(code)} ($code)',
                      style: const TextStyle(fontSize: 12)),
                  deleteIcon:
                      editable ? const Icon(Icons.close, size: 16) : null,
                  onDeleted: editable
                      ? () => setState(() => _geoCountries.remove(code))
                      : null,
                ),
              if (editable)
                ActionChip(
                  avatar: const Icon(Icons.add,
                      size: 16, color: VirelloColors.violet),
                  label: Text(s.geoCustom),
                  onPressed: _openCountryPicker,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(s.geoCountriesSelected(_geoCountries.length),
              style: const TextStyle(fontSize: 12, color: VirelloColors.muted)),
          // "Your markets" brief — the concept for what a selected country
          // means: flag, regions, AI-suggested vs own pick, and the honest
          // note that AI matches content language + audience to these
          // markets. This feeds plan/package choice and the final campaign.
          if (_geoCountries.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    VirelloColors.violet.withValues(alpha: 0.08),
                    VirelloColors.violet.withValues(alpha: 0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                    color:
                        VirelloColors.violet.withValues(alpha: 0.25)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.public,
                          size: 18, color: VirelloColors.violet),
                      const SizedBox(width: 8),
                      Text(
                        '${s.geoYourMarkets} (${_geoCountries.length})',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: VirelloColors.violetDeep),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final code in _geoCountries) _marketRow(code),
                  const SizedBox(height: 2),
                  Text(
                    s.geoMarketBriefNote,
                    style: const TextStyle(
                        fontSize: 12,
                        color: VirelloColors.muted,
                        height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ],
        if (editable) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : _saveGeography,
              child: Text(s.saveChanges,
                  style: const TextStyle(color: VirelloColors.violet)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _geoOption({
    required String value,
    required IconData icon,
    required String title,
    required String desc,
    required bool editable,
  }) {
    final on = _geoMode == value;
    return GestureDetector(
      onTap: !editable
          ? null
          : () {
              setState(() {
                _geoMode = value;
                if (value == 'custom' && _geoCountries.isEmpty) {
                  // Start from the AI suggestion — the advertiser refines it.
                  final sg = _suggestedSet();
                  if (sg.isNotEmpty) _geoCountries = sg;
                }
              });
              // "Choose countries" opens the full modern country list directly.
              if (value == 'custom') _openCountryPicker();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: on ? const Color(0xFFF7F4FF) : Colors.white,
          border: Border.all(
              color: on ? VirelloColors.violet : VirelloColors.divider,
              width: on ? 2 : 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Icon(icon,
              size: 20, color: on ? VirelloColors.violet : VirelloColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: on ? VirelloColors.violetDeep : VirelloColors.ink)),
              Text(desc,
                  style:
                      const TextStyle(fontSize: 12, color: VirelloColors.muted)),
            ]),
          ),
          if (on)
            const Icon(Icons.check_circle,
                size: 20, color: VirelloColors.violet),
        ]),
      ),
    );
  }

  /// Country flag emoji from an ISO alpha-2 code.
  String _flag(String code) {
    final up = code.toUpperCase();
    if (up.length != 2 || !RegExp(r'^[A-Z]{2}$').hasMatch(up)) return '🏳️';
    return String.fromCharCodes(
        up.codeUnits.map((c) => 0x1F1E6 + c - 0x41));
  }

  /// Region preset display names that contain [code].
  List<String> _regionsOf(String code) {
    final presets = ((_geoData?['region_presets'] as Map?) ?? {});
    final out = <String>[];
    for (final e in presets.entries) {
      final p = Map<String, dynamic>.from(e.value as Map);
      final codes = ((p['countries'] as List?) ?? []).map((x) => '$x');
      if (codes.contains(code)) out.add('${p['name_en']}');
    }
    return out;
  }

  /// AI-suggested country codes for this campaign (may be empty).
  Set<String> _suggestedSet() {
    final sgRaw = _campaign?.suggestedGeography;
    return (((sgRaw?['countries'] as List?) ?? []).map((e) => '$e')).toSet();
  }

  /// One row of the "Your markets" brief: flag, name, regions, and why
  /// this country is in the list (AI reason vs the advertiser's own pick).
  Widget _marketRow(String code) {
    final suggested = _suggestedSet().contains(code);
    final regions = _regionsOf(code);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_flag(code), style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_countryName(code)} ($code)',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                if (regions.isNotEmpty)
                  Text(
                    regions.join(' • '),
                    style: const TextStyle(
                        fontSize: 12, color: VirelloColors.muted),
                  ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (suggested
                      ? VirelloColors.violet
                      : const Color(0xFF22B8CF))
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              suggested ? s.geoAiSuggestedBadge : s.geoYourPickBadge,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: suggested
                    ? VirelloColors.violet
                    : const Color(0xFF0E7490),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCountryPicker() async {
    final data = _geoData;
    if (data == null) return;
    final all = ((data['countries'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final presets = ((data['region_presets'] as Map?) ?? {}).entries
        .map((e) =>
            MapEntry('$e.key', Map<String, dynamic>.from(e.value as Map)))
        .toList();
    final aiSuggested = _suggestedSet();
    var query = '';
    var regionFilter = '';
    final temp = Set<String>.from(_geoCountries);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final q = query.trim().toLowerCase();
          final filtered = all.where((m) {
            if (q.isNotEmpty &&
                !'${m['name_en']}'.toLowerCase().contains(q) &&
                !'${m['code']}'.toLowerCase().contains(q)) {
              return false;
            }
            if (regionFilter.isNotEmpty) {
              final preset =
                  presets.firstWhere((p) => p.key == regionFilter);
              final codes = ((preset.value['countries'] as List?) ?? [])
                  .map((x) => '$x');
              if (!codes.contains('${m['code']}')) return false;
            }
            return true;
          }).toList();
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.88,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Column(children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: VirelloColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.geoCustom,
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800)),
                          Text(
                              '${filtered.length} • ${s.geoCountriesSelected(temp.length)}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: VirelloColors.muted)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _geoCountries = temp);
                        Navigator.pop(ctx);
                      },
                      child: Text(s.done,
                          style: const TextStyle(
                              color: VirelloColors.violet,
                              fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: s.geoSearchCountries,
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: VirelloColors.chipBg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                    ),
                    onChanged: (v) => setS(() => query = v),
                  ),
                ),
                // Region filter chips.
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(s.geoAllRegions),
                          selected: regionFilter.isEmpty,
                          selectedColor: VirelloColors.violet
                              .withValues(alpha: 0.15),
                          checkmarkColor: VirelloColors.violet,
                          onSelected: (_) =>
                              setS(() => regionFilter = ''),
                        ),
                      ),
                      for (final p in presets)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label:
                                Text('${p.value['name_en']}'),
                            selected: regionFilter == p.key,
                            selectedColor: VirelloColors.violet
                                .withValues(alpha: 0.15),
                            checkmarkColor: VirelloColors.violet,
                            onSelected: (_) => setS(() =>
                                regionFilter = p.key),
                          ),
                        ),
                    ],
                  ),
                ),
                // Selected tray.
                if (temp.isNotEmpty)
                  Container(
                    height: 52,
                    margin: const EdgeInsets.only(top: 4),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20),
                      children: [
                        for (final code in temp)
                          Padding(
                            padding:
                                const EdgeInsets.only(right: 8),
                            child: Chip(
                              avatar: Text(_flag(code),
                                  style: const TextStyle(
                                      fontSize: 16)),
                              label: Text(code,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                              deleteIcon: const Icon(Icons.close,
                                  size: 14),
                              onDeleted: () =>
                                  setS(() => temp.remove(code)),
                              backgroundColor: VirelloColors.violet
                                  .withValues(alpha: 0.1),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (aiSuggested.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        20, 8, 20, 0),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(
                            Icons.auto_awesome_outlined,
                            size: 18),
                        label: Text(s.geoUseAiSuggestion),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              VirelloColors.violet,
                          side: const BorderSide(
                              color: VirelloColors.violet),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14)),
                        ),
                        onPressed: () => setS(() {
                          temp
                            ..clear()
                            ..addAll(aiSuggested);
                        }),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          12, 4, 12, 16),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final m = filtered[i];
                        final code = '${m['code']}';
                        final name = '${m['name_en']}';
                        final picked = temp.contains(code);
                        final regions = _regionsOf(code);
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(16),
                            onTap: () => setS(() {
                              if (picked) {
                                temp.remove(code);
                              } else {
                                temp.add(code);
                              }
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(
                                  milliseconds: 180),
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12),
                              decoration: BoxDecoration(
                                color: picked
                                    ? VirelloColors.violet
                                        .withValues(alpha: 0.08)
                                    : VirelloColors.chipBg,
                                border: Border.all(
                                  color: picked
                                      ? VirelloColors.violet
                                      : Colors.transparent,
                                  width: picked ? 1.5 : 1,
                                ),
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                              child: Row(children: [
                                Text(_flag(code),
                                    style: const TextStyle(
                                        fontSize: 28)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Text(name,
                                          style:
                                              const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight:
                                                      FontWeight
                                                          .w700)),
                                      Text(
                                        regions.isEmpty
                                            ? code
                                            : '$code • ${regions.join(' • ')}',
                                        style:
                                            const TextStyle(
                                                fontSize: 12,
                                                color: VirelloColors
                                                    .muted),
                                      ),
                                    ],
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(
                                      milliseconds: 180),
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: picked
                                        ? VirelloColors.violet
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: picked
                                          ? VirelloColors
                                              .violet
                                          : VirelloColors
                                              .divider,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: picked
                                      ? const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Colors.white)
                                      : null,
                                ),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ]),
              ),
            );
        },
      ),
    );
  }

  Widget _estimateCard() {
    final est = _campaign!.estimate;
    if (est == null) return const SizedBox.shrink();
    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VSectionHeader(title: s.adReachEstimate),
          const SizedBox(height: 4),
          Text('${est.low} – ${est.high}',
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(s.adEstimateNote,
              style: const TextStyle(fontSize: 12, color: VirelloColors.muted)),
        ],
      ),
    );
  }

  /// Board primary action: gradient Review & Launch (draft) / Approve /
  /// Launch / Resume, with the same approval-gate logic as before.
  Widget _actionsCard() {
    final c = _campaign!;
    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (c.isDraft)
            VGradientButton(
              label: s.reviewAndLaunch,
              icon: Icons.rocket_launch_outlined,
              onPressed: _busy
                  ? null
                  : () => _applyEdits(
                      {'status': 'pending_approval'}, s.adSubmittedToast),
            ),
          if (c.isPendingApproval) ...[
            VGradientButton(
              label: s.adApprove,
              icon: Icons.check_circle_outline,
              onPressed: _busy ? null : _approve,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : _reject,
              child: Text(s.adReject),
            ),
          ],
          // Phase 2 lifecycle: approved -> launch -> active <-> paused.
          if (c.isApproved)
            VGradientButton(
              label: s.adLaunch,
              icon: Icons.rocket_launch_outlined,
              onPressed: _busy ? null : _launch,
            ),
          if (c.isActive)
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _pause,
              icon: const Icon(Icons.pause_outlined),
              label: Text(s.adPause),
            ),
          if (c.isPaused)
            VGradientButton(
              label: s.adResume,
              icon: Icons.play_arrow_outlined,
              onPressed: _busy ? null : _resume,
            ),
          if (!c.isDraft &&
              !c.isPendingApproval &&
              !c.isApproved &&
              !c.isActive &&
              !c.isPaused)
            Text(_statusLabel(c.status),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _statusColor(c.status),
                    fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  /// Phase 3: AI Optimization section — latest run, per-segment bars,
  /// decision feed (explainable), and the manual "Optimize now" button.
  Widget _optimizationCard() {
    final c = _campaign;
    if (c == null || !(c.isActive || c.isPaused || c.isCompleted)) {
      return const SizedBox.shrink();
    }
    final ins = _insights;
    final hist = _history;
    final canOptimize = c.isActive || c.isPaused;
    final latest =
        (hist != null && hist.runs.isNotEmpty) ? hist.runs.first : null;

    Widget bar(String name, double frac, String meta) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                    child: Text(name, style: const TextStyle(fontSize: 13))),
                Text(meta,
                    style: const TextStyle(
                        fontSize: 12, color: VirelloColors.muted)),
              ]),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: frac.clamp(0.0, 1.0),
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                color: VirelloColors.violet,
                backgroundColor: VirelloColors.chipBg,
              ),
            ],
          ),
        );

    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(s.adOptimization,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            if (canOptimize)
              _optimizing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: VirelloColors.violet))
                  : FilledButton.tonalIcon(
                      onPressed: _optimizeNow,
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: Text(s.adOptimizeNow),
                    ),
          ]),
          const SizedBox(height: 8),
          if (latest == null)
            Text(s.adNoRunsYet,
                style:
                    const TextStyle(fontSize: 12, color: VirelloColors.muted))
          else ...[
            Text('${s.adLatestRun}: ${latest.summaryLine()}',
                style: const TextStyle(
                    fontSize: 12, color: VirelloColors.mutedDark)),
            if (latest.wasSafetyPaused) ...[
              const SizedBox(height: 4),
              Text(s.adSafetyPausedNote,
                  style: const TextStyle(fontSize: 12, color: Colors.orange)),
            ],
          ],
          if (ins != null && ins.segments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(s.adSegmentPerformance,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final sg in ins.segments)
              if (sg.impressions >= ins.minSampleGuard)
                bar(
                    sg.segmentName,
                    sg.engagementRate,
                    '${(sg.engagementRate * 100).toStringAsFixed(1)}% · '
                    '${s.adWeight} ${sg.weight.toStringAsFixed(2)}')
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                      '${sg.segmentName}: ${s.adInsufficientData} '
                      '(${sg.impressions}/${ins.minSampleGuard})',
                      style: const TextStyle(
                          fontSize: 12, color: VirelloColors.muted)),
                ),
          ],
          if (ins != null && ins.variants.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(s.adVariantPerformance,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final v in ins.variants)
              bar('${v.isOriginal ? '★ ' : ''}${v.label}', v.weight / 2.0,
                  '${s.adWeight} ${v.weight.toStringAsFixed(2)}'),
          ],
          if (ins != null && ins.placements.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(s.adPlacementPerformance,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final p in ins.placements)
              bar(p.placementType, p.weight / 2.0,
                  '${s.adWeight} ${p.weight.toStringAsFixed(2)}'),
          ],
          if (hist != null && hist.decisions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(s.adDecisionFeed,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (final d in hist.decisions.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                    '• ${d.action}: ${d.reasons.isNotEmpty ? d.reasons.first : ''}',
                    style: const TextStyle(
                        fontSize: 12, color: VirelloColors.mutedDark)),
              ),
          ],
          const SizedBox(height: 8),
          Text(s.adOptimizeNote,
              style: const TextStyle(fontSize: 12, color: VirelloColors.muted)),
        ],
      ),
    );
  }

  /// Phase 2: delivery stats — genuine measured events, spend, pacing.
  Widget _deliveryCard() {
    final d = _delivery;
    if (d == null) return const SizedBox.shrink();
    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VSectionHeader(title: s.adDelivery),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Text(
                  '${s.adSpend}: \$${d.spentUsd.toStringAsFixed(2)}'
                  ' / \$${d.budgetUsd.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 13)),
            ),
            Text('${(d.spendPct * 100).toStringAsFixed(0)}%',
                style:
                    const TextStyle(fontSize: 12, color: VirelloColors.muted)),
          ]),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: d.spendPct,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            color: VirelloColors.violet,
            backgroundColor: VirelloColors.chipBg,
          ),
          const SizedBox(height: 8),
          Text('${s.adImpressions}: ${d.impressions}',
              style: const TextStyle(fontSize: 13)),
          Text(
              '${s.adPacing}: \$${d.spentTodayUsd.toStringAsFixed(2)}'
              ' / \$${d.dailyCapUsd.toStringAsFixed(2)}'
              ' — ${d.onPace ? s.adOnPace : s.adOverPace}',
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          Text(s.adSimulatedNote,
              style: const TextStyle(fontSize: 12, color: VirelloColors.muted)),
        ],
      ),
    );
  }

  /// Phase 4: the ONE advertiser dashboard — every figure labeled measured
  /// vs estimate; revenue is advertiser-reported/measured, never verified.
  Widget _dashboardCard() {
    final d = _dashboard;
    if (d == null) return const SizedBox.shrink();
    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VSectionHeader(title: s.adDashboard),
          const SizedBox(height: 4),
          Text(s.adLastClick,
              style: const TextStyle(fontSize: 12, color: VirelloColors.muted)),
          const SizedBox(height: 8),
          _metricRow(s.adSpend, d.metric('spend_usd'), isMoney: true),
          _metricRow(s.adImpressions, d.metric('impressions')),
          _metricRow(s.adReach, d.metric('reach')),
          _metricRow(s.adViews, d.metric('views')),
          _metricRow(s.adEngagement, d.metric('engagement')),
          _metricRow(s.adFollowersGained, d.metric('followers_gained')),
          _metricRow(s.adClicks, d.metric('clicks')),
          _metricRow(s.adLeads, d.metric('leads')),
          _metricRow(s.adConversions, d.metric('conversions')),
          _metricRow(s.adCostPerResult, d.metric('cost_per_result_usd'),
              isMoney: true),
          _metricRow(s.adAttrRevenue, d.metric('attributable_revenue_usd'),
              isMoney: true),
          if (d.bySegment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(s.adSegmentPerformance,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            for (final sl in d.bySegment)
              Text(
                  '${sl.name}: ${sl.conversions} '
                  '${s.adConversions.toLowerCase()}'
                  ' · \$${sl.revenueUsd.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 12, color: VirelloColors.mutedDark)),
          ],
          if (d.byVariant.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(s.adVariantPerformance,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            for (final sl in d.byVariant)
              Text(
                  '${sl.name}: ${sl.conversions} '
                  '${s.adConversions.toLowerCase()}'
                  ' · \$${sl.revenueUsd.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 12, color: VirelloColors.mutedDark)),
          ],
          const SizedBox(height: 8),
          Text(s.adRevenueNote,
              style: const TextStyle(fontSize: 12, color: VirelloColors.muted)),
        ],
      ),
    );
  }

  /// One dashboard figure with its measured/estimate badge.
  Widget _metricRow(String label, AdMetric m, {bool isMoney = false}) {
    final v = m.value;
    final text = v == null
        ? '—'
        : isMoney
            ? '\$${(v as num).toDouble().toStringAsFixed(2)}'
            : '${(v as num).toInt()}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: m.isEstimate
                  ? Colors.orange.withValues(alpha: 0.15)
                  : Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              m.isEstimate ? s.adEstimate : s.adMeasured,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
