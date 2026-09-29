import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/discovery_models.dart';
import '../../services/api_client.dart';
import '../../main.dart';
import '../admin/admin_screen.dart';
import '../analytics/analytics_screen.dart';
import '../discovery/result_screen.dart';
import '../settings/language_settings_screen.dart';
import '../settings/notifications_screen.dart';
import '../settings/settings_screen.dart';
import '../social/activity_screen.dart';
import '../social/creator_dashboard_screen.dart';
import '../social/following_screen.dart';
import '../tutorial/tutorial_guide_screen.dart';
import 'billing_screen.dart';
import 'support_chat_screen.dart';

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

  @override
  void initState() {
    super.initState();
    apiClient
        .me()
        .then((m) {
          if (mounted) setState(() => _me = m);
        })
        .catchError((_) {});
    apiClient
        .listCampaigns()
        .then((l) {
          if (mounted) setState(() => _campaignCount = l.length);
        })
        .catchError((_) {});
    Future.wait([apiClient.getTopics(), apiClient.getInterests()])
        .then((r) {
          if (!mounted) return;
          final topics = r[0] as List<Topic>;
          final interests = r[1] as Set<String>;
          setState(() {
            _topicNames = {
              for (final t in topics) t.slug: t.name(appState.localeCode),
            };
            _interests = interests;
          });
        })
        .catchError((_) {});
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

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    final isAdmin = _me?['is_admin'] == true;
    final initial = _name.isNotEmpty ? _name[0].toUpperCase() : 'V';
    final handle = _email.contains('@') ? '@${_email.split('@').first}' : '';
    final planLabel = _plan.isEmpty
        ? ''
        : '${_plan[0].toUpperCase()}${_plan.substring(1)}';

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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: AppStrings(appState.localeCode)
                              .settingsTitle,
                          icon: const Icon(
                            Icons.settings_outlined,
                            color: Colors.white,
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
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: VirelloColors.cardShadow,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: VirelloColors.violet,
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
                    color: VirelloColors.violet,
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
                        title: s.analyticsMenu,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AnalyticsScreen(),
                          ),
                        ),
                      ),
                      _menuRow(
                        icon: Icons.people_outline,
                        title: s.boardFollowing,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const FollowingScreen(),
                          ),
                        ),
                      ),
                      _menuRow(
                        icon: Icons.timeline_outlined,
                        title: s.boardActivity,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ActivityScreen(),
                          ),
                        ),
                      ),
                      _menuRow(
                        icon: Icons.dashboard_outlined,
                        title: s.boardCreatorDashboard,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CreatorDashboardScreen(),
                          ),
                        ),
                      ),
                      _menuRow(
                        icon: Icons.language_outlined,
                        title: s.langSettings,
                        subtitle: appState.localeCode.toUpperCase(),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LanguageSettingsScreen(),
                          ),
                        ),
                      ),
                      _menuRow(
                        icon: Icons.notifications_outlined,
                        title: s.notifications,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        ),
                      ),
                      _menuRow(
                        icon: Icons.play_circle_outline_rounded,
                        iconColor: VirelloColors.violet,
                        title: s.tutorialMenu,
                        subtitle: s.tutorialMenuSub,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TutorialGuideScreen(),
                          ),
                        ),
                      ),
                      _menuRow(
                        icon: Icons.dark_mode_outlined,
                        title: 'Theme',
                        trailing: ListenableBuilder(
                          listenable: appState,
                          builder: (_, __) => Switch(
                            value: appState.themeMode == ThemeMode.dark,
                            onChanged: (_) => appState.toggleTheme(),
                          ),
                        ),
                      ),
                      if (isAdmin)
                        _menuRow(
                          icon: Icons.admin_panel_settings_outlined,
                          iconColor: VirelloColors.violet,
                          title: s.adminDashboard,
                          subtitle: s.adminOverview,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AdminScreen(),
                            ),
                          ),
                        ),
                      _menuRow(
                        icon: Icons.credit_card_outlined,
                        title: s.billingTitle,
                        subtitle: '$planLabel Plan · $_credits',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BillingScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                VSectionHeader(title: s.trustTitle),
                const SizedBox(height: 10),
                VCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _menuRow(
                        icon: Icons.verified_user_outlined,
                        iconColor: VirelloColors.violet,
                        title: s.howVirelloGrows,
                        onTap: () => _showDialog(
                          s.howVirelloGrows,
                          '${s.neverFake}\n\n${s.noGuarantees}',
                        ),
                      ),
                      _menuRow(
                        icon: Icons.block_outlined,
                        iconColor: VirelloColors.danger,
                        title: s.whatWeNeverDo,
                        onTap: () =>
                            _showDialog(s.whatWeNeverDo, s.neverDoList),
                      ),
                      _menuRow(
                        icon: Icons.support_agent_outlined,
                        title: s.aiSupport,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SupportChatScreen(),
                          ),
                        ),
                      ),
                    ],
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuRow({
    required IconData icon,
    Color? iconColor,
    required String title,
    Color? titleColor,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) => ListTile(
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
            style: const TextStyle(fontSize: 12, color: VirelloColors.muted),
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
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
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

  void _showDialog(String title, String body) {
    final s = AppStrings(appState.localeCode);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(s.back),
          ),
        ],
      ),
    );
  }

  Widget _savedCard(PostAnalysisResult r) {
    final title = r.title.isEmpty ? r.url : r.title;
    return GestureDetector(
      onTap: () =>
          Navigator.of(context)
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
                      child: const Icon(
                        Icons.image_outlined,
                        color: Colors.white,
                        size: 32,
                      ),
                    )
                  : Image.network(
                      r.thumbnailUrl,
                      width: 140,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 140,
                        height: 96,
                        decoration: const BoxDecoration(
                          gradient: VirelloColors.brandGradient,
                        ),
                        child: const Icon(
                          Icons.image_outlined,
                          color: Colors.white,
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
                              child: const Icon(
                                Icons.image_outlined,
                                color: Colors.white,
                                size: 22,
                              ),
                            )
                          : Image.network(
                              r.thumbnailUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  gradient: VirelloColors.brandGradient,
                                ),
                                child: const Icon(
                                  Icons.image_outlined,
                                  color: Colors.white,
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
