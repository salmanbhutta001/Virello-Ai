import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/discovery_models.dart';
import '../../services/api_client.dart';
import '../../main.dart';
import '../admin/admin_pin_screen.dart';
import '../analytics/analytics_screen.dart';
import '../discovery/result_screen.dart';
import '../settings/settings_screen.dart';
import '../tour/app_tour.dart';
import '../shop/seller_dashboard_screen.dart';
import '../wallet/wallet_screen.dart';
import '../../services/rewards_api.dart';
import '../social/activity_screen.dart';
import '../social/creator_dashboard_screen.dart';
import '../social/following_screen.dart';
import '../social/messages_screen.dart';
import '../../core/config.dart';

/// Profile: board-styled cover, real stats (campaigns / credits / interests),
/// saved collections, and the full menu — settings, Trust Center, support.
/// Only real backend data is shown; nothing is faked.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _me;
  int? _campaignCount;
  Set<String> _interests = {};
  Map<String, String> _topicNames = {};
  // Cash balance for the wallet chip (hidden when the backend is silent).
  late final Future<Map<String, dynamic>> _cashFuture =
      RewardsApi(apiClient).walletBalance().catchError((_) =>
          <String, dynamic>{});
  // Hidden admin entry: 5 taps on the version footer within 3 seconds.
  int _verTaps = 0;
  DateTime? _firstVerTap;

  @override
  void initState() {
    super.initState();
    apiClient.me().then((m) {
      if (mounted) setState(() => _me = m);
    }).catchError((_) {});
    apiClient.listCampaigns().then((l) {
      if (mounted) setState(() => _campaignCount = l.length);
    }).catchError((_) {});
    Future.wait([apiClient.getTopics(), apiClient.getInterests()]).then((r) {
      if (!mounted) return;
      final topics = r[0] as List<Topic>;
      final interests = r[1] as Set<String>;
      setState(() {
        _topicNames = {
          for (final t in topics) t.slug: t.name(appState.localeCode),
        };
        _interests = interests;
      });
    }).catchError((_) {});
    savedStore.addListener(_onSavedChanged);
  }

  @override
  void dispose() {
    savedStore.removeListener(_onSavedChanged);
    super.dispose();
  }

  void _onSavedChanged() {
    if (mounted) setState(() {});
  }

  String get _name =>
      '${_me?['name'] ?? _me?['email'] ?? authStore.email ?? 'Virello'}';
  String get _email => '${_me?['email'] ?? authStore.email ?? ''}';
  String get _plan => '${_me?['plan'] ?? 'free'}';
  int get _credits => (_me?['credits'] as num? ?? 0).toInt();

  /// Rewards balance from /users/me (points_balance, points_level).
  /// Null when the backend does not send them — chip hides then.
  int? get _pointsBalance {
    final v = _me?['points_balance'];
    return v == null ? null : (v as num).toInt();
  }
  String get _pointsLevel => '${_me?['points_level'] ?? 'Sprout'}';

  /// True when the signed-in email is on the admin allowlist.
  /// (Must match backend VIRELLO_ADMIN_EMAILS.)
  bool get _isAdminEmail {
    final email = _email.trim().toLowerCase();
    return email == 'salman09bhutta@gmail.com' ||
        email == 'alif01fiverr@gmail.com';
  }

  /// Opens the Admin Panel via the self-contained admin entry flow
  /// (PIN -> unlock -> dashboard). The dashboard opens immediately on
  /// unlock; the profile refresh below is best-effort only.
  Future<void> _openAdminPanel() => openAdminPanel(
        context,
        onUnlocked: () {
          apiClient.me().then((m) {
            if (!mounted) return;
            setState(() => _me = m);
          }).catchError((_) {});
        },
      );

  /// Wallet chip: points balance + cash balance, opens WalletScreen on tap.
  /// Cash comes from GET /api/v1/wallet/balance (hidden when unavailable).
  Widget _pointsChip() {
    final s = AppStrings(appState.localeCode);
    return VCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const WalletScreen()),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: VirelloColors.brandGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child:  Icon(
                Icons.account_balance_wallet_rounded,
                color: VTheme.onBrand(context),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.stars_rounded,
                          size: 15, color: VirelloColors.pink),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${_pointsBalance ?? 0} ${s.virelloPoints}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.payments_outlined,
                          size: 15, color: Colors.green),
                      const SizedBox(width: 4),
                      FutureBuilder<Map<String, dynamic>>(
                        future: _cashFuture,
                        builder: (c, snap) {
                          final w = snap.data ?? {};
                          final cents =
                              (w['balance_cents'] as num? ?? 0).toInt();
                          final display =
                              '${w['balance_display'] ?? '\$${(cents / 100).toStringAsFixed(2)}'}';
                          return Text(
                            display,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.green,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  Text(
                    '${s.level}: $_pointsLevel',
                    style: const TextStyle(
                      fontSize: 12,
                      color: VirelloColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    final isAdmin = _me?['is_admin'] == true;
    final initial = _name.isNotEmpty ? _name[0].toUpperCase() : 'V';
    final handle = _email.contains('@') ? '@${_email.split('@').first}' : '';
    final planLabel =
        _plan.isEmpty ? '' : '${_plan[0].toUpperCase()}${_plan.substring(1)}';

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 150,
                decoration: const BoxDecoration(
                  gradient: VirelloColors.brandGradient,
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.profile,
                            style:  TextStyle(
                              color: VTheme.text(context),
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip:
                              AppStrings(appState.localeCode).settingsTitle,
                          icon:  Icon(
                            Icons.settings_outlined,
                            color: VTheme.text(context),
                          ),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                bottom: -34,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: VTheme.text(context),
                    border: Border.all(color: VTheme.text(context), width: 3),
                    boxShadow: VirelloColors.cardShadow,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: VirelloColors.pink,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 44),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (handle.isNotEmpty)
                  Text(
                    handle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: VirelloColors.muted,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  '$planLabel Plan',
                  style: const TextStyle(
                    fontSize: 13,
                    color: VirelloColors.pink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _showEditProfileSheet,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(s.editProfile),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    VStatTile(
                      label: s.campaigns,
                      value: '${_campaignCount ?? 0}',
                    ),
                    const SizedBox(width: 10),
                    VStatTile(label: s.creditsMonthly, value: '$_credits'),
                    const SizedBox(width: 10),
                    VStatTile(
                      label: s.myInterests,
                      value: '${_interests.length}',
                    ),
                  ],
                ),
                if (_pointsBalance != null) ...[
                  const SizedBox(height: 12),
                  _pointsChip(),
                ],
                const SizedBox(height: 20),
                VSectionHeader(title: s.myInterests),
                const SizedBox(height: 10),
                if (_interests.isEmpty)
                  Text(
                    s.nothingHere,
                    style: const TextStyle(
                      color: VirelloColors.muted,
                      fontSize: 13,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _interests
                        .map(
                          (slug) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: VTheme.chip(context),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              _topicNames[slug] ?? slug,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 20),
                VSectionHeader(
                  title: s.savedCollections,
                  actionLabel: s.seeAll,
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const _SavedAllScreen()),
                  ),
                ),
                const SizedBox(height: 10),
                if (savedStore.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      s.nothingHere,
                      style: const TextStyle(
                        color: VirelloColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 158,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: savedStore.items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => _savedCard(savedStore.items[i]),
                    ),
                  ),
                const SizedBox(height: 20),
                VCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _menuRow(
                        icon: Icons.query_stats_outlined,
                        iconColor: VirelloColors.pink,
                        title: s.analyticsMenu,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AnalyticsScreen(),
                          ),
                        ),
                      ),
                      _menuRow(
                        icon: Icons.people_outline,
                        iconColor: VirelloColors.pink,
                        title: s.boardFollowing,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const FollowingScreen(),
                          ),
                        ),
                      ),
                      _menuRow(
                        icon: Icons.timeline_outlined,
                        iconColor: VirelloColors.pink,
                        title: s.boardActivity,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ActivityScreen(),
                          ),
                        ),
                      ),
                      _menuRow(
                        icon: Icons.chat_bubble_outline,
                        iconColor: VirelloColors.pink,
                        title: s.p11Messages,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MessagesScreen(),
                          ),
                        ),
                      ),
                      _menuRow(
                        icon: Icons.dashboard_outlined,
                        iconColor: VirelloColors.pink,
                        title: s.boardCreatorDashboard,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CreatorDashboardScreen(),
                          ),
                        ),
                      ),
                      _menuRow(
                        icon: Icons.storefront_outlined,
                        iconColor: VirelloColors.pink,
                        title: s.p11SellerDashboard,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SellerDashboardScreen(),
                          ),
                        ),
                      ),
                      // Visible Admin Panel entry for allowlisted emails.
                      // (Hidden 5-tap on version footer still works as backup.)
                      if (_isAdminEmail)
                        _menuRow(
                          icon: Icons.admin_panel_settings_outlined,
                          iconColor: VirelloColors.pink,
                          title: s.adminPanel,
                          onTap: _openAdminPanel,
                        ),
                      _menuRow(
                        key: TourTargets.profileRewards,
                        icon: Icons.stars_outlined,
                        iconColor: VirelloColors.pink,
                        title: s.rewards,
                        subtitle: _pointsBalance != null
                            ? '$_pointsBalance ${s.virelloPoints}'
                            : null,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WalletScreen(),
                          ),
                        ),
                      ),
                      // "Take App Tour" — replay the professional app tour.
                      _menuRow(
                        icon: Icons.tour_outlined,
                        iconColor: VirelloColors.pink,
                        title: s.takeAppTour,
                        subtitle: s.takeAppTourSub,
                        onTap: () async {
                          await AppTourService.resetTour();
                          if (!context.mounted) return;
                          // Close profile and trigger tour on home shell.
                          Navigator.of(context).popUntil((r) => r.isFirst);
                          requestedTour.value = true;
                        },
                      ),
                      // "Invite Friends" — share the app.
                      _menuRow(
                        icon: Icons.person_add_alt_outlined,
                        title: s.inviteFriends,
                        subtitle: s.inviteFriendsSub,
                        onTap: () => SharePlus.instance.share(ShareParams(
                          text: s.inviteFriendsMessage,
                          subject: 'Virello',
                        )),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Trust, legal, support & app settings live in Settings
                // (gear icon) — single shortcut here, no duplicates.
                VCard(
                  padding: EdgeInsets.zero,
                  child: _menuRow(
                    icon: Icons.settings_outlined,
                    iconColor: VirelloColors.pink,
                    title: s.settingsTitle,
                    subtitle: s.settingsSubtitle,
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                VCard(
                  padding: EdgeInsets.zero,
                  child: _menuRow(
                    icon: Icons.logout_outlined,
                    iconColor: VirelloColors.danger,
                    title: s.signOut,
                    titleColor: VirelloColors.danger,
                    subtitle: _email.isEmpty ? null : _email,
                    onTap: () => authStore.signOut(),
                  ),
                ),
                const SizedBox(height: 24),
                // Subtle version footer — tap 5x within 3s for the hidden
                // admin PIN entry.
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _onVersionTap,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'v0.1.0',
                        style: TextStyle(
                          color: VirelloColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                    height: 24 + MediaQuery.paddingOf(context).bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Hidden admin entry: 5 taps on the version footer within 3 seconds opens
  /// the PIN screen. A correct PIN elevates server-side; on success we
  /// refresh /users/me and open the admin dashboard.
  Future<void> _onVersionTap() async {
    final now = DateTime.now();
    if (_firstVerTap == null ||
        now.difference(_firstVerTap!) > const Duration(seconds: 3)) {
      _firstVerTap = now;
      _verTaps = 1;
      return;
    }
    _verTaps++;
    if (_verTaps < 5) return;
    _verTaps = 0;
    _firstVerTap = null;
    openAdminPanel(
      context,
      onUnlocked: () {
        apiClient.me().then((m) {
          if (!mounted) return;
          setState(() => _me = m);
        }).catchError((_) {});
      },
    );
  }

  Widget _menuRow({
    Key? key,
    required IconData icon,
    Color? iconColor,
    required String title,
    Color? titleColor,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) =>
      ListTile(
        key: key,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600, color: titleColor),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style:
                    const TextStyle(fontSize: 12, color: VirelloColors.muted),
              ),
        trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      );

  /// Editable profile sheet: name field, Save calls PATCH /users/me,
  /// refreshes profile state, shows a confirmation.
  void _showEditProfileSheet() {
    final s = AppStrings(appState.localeCode);
    final nameCtrl = TextEditingController(text: '${_me?['name'] ?? ''}');
    var saving = false;
    File? avatarFile;
    File? coverFile;
    final picker = ImagePicker();

    Future<void> pickImage(bool isAvatar, ImageSource source, StateSetter setSheet) async {
      try {
        final img = await picker.pickImage(source: source, maxWidth: 1024, imageQuality: 85);
        if (img != null && mounted) {
          setSheet(() {
            if (isAvatar) {
              avatarFile = File(img.path);
            } else {
              coverFile = File(img.path);
            }
          });
        }
      } catch (_) {}
    }

    void showImageOptions(bool isAvatar, StateSetter setSheet) {
      showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(s.takePhoto),
                onTap: () {
                  Navigator.pop(ctx);
                  pickImage(isAvatar, ImageSource.camera, setSheet);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(s.chooseFromGallery),
                onTap: () {
                  Navigator.pop(ctx);
                  pickImage(isAvatar, ImageSource.gallery, setSheet);
                },
              ),
              if ((isAvatar && avatarFile != null) || (!isAvatar && coverFile != null))
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(s.removePhoto, style: const TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setSheet(() {
                      if (isAvatar) {
                        avatarFile = null;
                      } else {
                        coverFile = null;
                      }
                    });
                  },
                ),
            ],
          ),
        ),
      );
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              24 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.editProfile,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                // Cover photo picker
                GestureDetector(
                  onTap: () => showImageOptions(false, setSheet),
                  child: Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: VTheme.card(context),
                    ),
                    child: coverFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(coverFile!, fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  color: VTheme.textSec(context)),
                              const SizedBox(height: 4),
                              Text(s.changeCoverPhoto,
                                  style: TextStyle(
                                      color: VTheme.textSec(context),
                                      fontSize: 12)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                // Avatar picker
                Center(
                  child: GestureDetector(
                    onTap: () => showImageOptions(true, setSheet),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundImage: avatarFile != null
                              ? FileImage(avatarFile!)
                              : null,
                          child: avatarFile == null
                              ? Text(
                                  (_me?['name'] ?? _email).isNotEmpty
                                      ? (_me?['name'] ?? _email)[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(fontSize: 32),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: VirelloColors.pink,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => showImageOptions(true, setSheet),
                    child: Text(s.changeProfilePicture),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: s.nameLabel,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.email_outlined),
                  title: Text(_email.isEmpty ? '—' : _email),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;
                            final messenger = ScaffoldMessenger.of(context);
                            final sheetNav = Navigator.of(sheetCtx);
                            setSheet(() => saving = true);
                            try {
                              await apiClient.updateName(name);
                              // Upload avatar if changed
                              if (avatarFile != null) {
                                try {
                                  final up = await apiClient.uploadFile(avatarFile!.path);
                                  final url = up['url'] as String?;
                                  if (url != null && url.isNotEmpty) {
                                    await apiClient.updateAvatar(url);
                                  }
                                } catch (_) {}
                              }
                              // Upload cover if changed
                              if (coverFile != null) {
                                try {
                                  final up = await apiClient.uploadFile(coverFile!.path);
                                  final url = up['url'] as String?;
                                  if (url != null && url.isNotEmpty) {
                                    await apiClient.updateCover(url);
                                  }
                                } catch (_) {}
                              }
                              final me = await apiClient.me();
                              if (!mounted) return;
                              setState(() => _me = me);
                              authStore.refreshProfile(me);
                              sheetNav.pop();
                              messenger.showSnackBar(
                                SnackBar(content: Text(s.profileUpdated)),
                              );
                            } on AuthException {
                              if (!mounted) return;
                              sheetNav.pop();
                              handleAuthFailure(s.sessionExpired);
                            } catch (_) {
                              if (!mounted) return;
                              setSheet(() => saving = false);
                              messenger.showSnackBar(
                                SnackBar(content: Text(s.growFailed)),
                              );
                            }
                          },
                    child: saving
                        ?  SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: VTheme.text(context),
                            ),
                          )
                        : Text(s.saveChanges),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(nameCtrl.dispose);
  }


  Widget _savedCard(PostAnalysisResult r) {
    final title = r.title.isEmpty ? r.url : r.title;
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => ResultScreen(result: r))),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: r.thumbnailUrl.isEmpty
                  ? Container(
                      width: 140,
                      height: 96,
                      decoration: const BoxDecoration(
                        gradient: VirelloColors.brandGradient,
                      ),
                      child:  Icon(
                        Icons.image_outlined,
                        color: VTheme.onBrand(context),
                        size: 32,
                      ),
                    )
                  : Image.network(AppConfig.resolveImageUrl(r.thumbnailUrl),
                      width: 140,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 140,
                        height: 96,
                        decoration: const BoxDecoration(
                          gradient: VirelloColors.brandGradient,
                        ),
                        child:  Icon(
                          Icons.image_outlined,
                          color: VTheme.onBrand(context),
                          size: 32,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full saved list behind the "See all" action.
class _SavedAllScreen extends StatelessWidget {
  const _SavedAllScreen();

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    final items = savedStore.items;
    return Scaffold(
      appBar: AppBar(title: Text(s.savedCollections)),
      body: items.isEmpty
          ? Center(
              child: Text(
                s.nothingHere,
                style: const TextStyle(color: VirelloColors.muted),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final r = items[i];
                final title = r.title.isEmpty ? r.url : r.title;
                return VCard(
                  padding: EdgeInsets.zero,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ResultScreen(result: r)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: r.thumbnailUrl.isEmpty
                          ? Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                gradient: VirelloColors.brandGradient,
                              ),
                              child:  Icon(
                                Icons.image_outlined,
                                color: VTheme.onBrand(context),
                                size: 22,
                              ),
                            )
                          : Image.network(AppConfig.resolveImageUrl(r.thumbnailUrl),
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  gradient: VirelloColors.brandGradient,
                                ),
                                child:  Icon(
                                  Icons.image_outlined,
                                  color: VTheme.onBrand(context),
                                  size: 22,
                                ),
                              ),
                            ),
                    ),
                    title: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                  ),
                );
              },
            ),
    );
  }
}
