import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../tutorial/tutorial_guide_screen.dart';
import '../tour/app_tour.dart';
import 'change_password_screen.dart';
import 'company_screen.dart';
import 'language_analytics_screen.dart';
import 'language_settings_screen.dart';
import 'legal_document_screen.dart';
import 'notifications_screen.dart';
import '../profile/billing_screen.dart';
import '../profile/support_chat_screen.dart';

/// Settings — the concept's central place for account, preferences,
/// plan & billing, trust & legal, and support. Every row opens a real
/// screen; nothing is a dead end.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  AppStrings _s() => AppStrings(appState.localeCode);

  Widget _row({
    required IconData icon,
    Color? iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) =>
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(icon, color: iconColor),
        title: Text(title,
            style: TextStyle(fontWeight: FontWeight.w600, color: titleColor)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle,
                style:
                    const TextStyle(fontSize: 12, color: VirelloColors.muted)),
        trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      );

  Widget _section(String title, List<Widget> rows) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: VirelloColors.muted)),
          ),
          VCard(padding: EdgeInsets.zero, child: Column(children: rows)),
        ],
      );

  void _trustDialog(BuildContext context, String title, String body) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_s().cancelBtn),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache(BuildContext context) async {
    final s = _s();
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.cacheCleared)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.tryAgain)),
      );
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final s = _s();
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s.signOut,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(s.signOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.cancelBtn),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.signOut,
                style: const TextStyle(color: VirelloColors.danger)),
          ),
        ],
      ),
    );
    if (yes == true) {
      await authStore.signOut();
      // main.dart listens to AuthStore and returns to SignInScreen.
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final s = _s();
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s.deleteAccount,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(s.deleteAccountConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.cancelBtn),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.deleteAccount,
                style: const TextStyle(color: VirelloColors.danger)),
          ),
        ],
      ),
    );
    if (yes == true) {
      try {
        await apiClient.deleteAccount();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.deleteAccountDone)),
          );
        }
        await authStore.signOut();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s();
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(s.settingsTitle,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _section(s.accountSection, [
              _row(
                icon: Icons.mail_outline,
                title: s.emailLabel,
                subtitle: authStore.email ?? '',
                trailing: const SizedBox.shrink(),
              ),
              _row(
                icon: Icons.lock_outline,
                title: s.changePasswordTitle,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen())),
              ),
            ]),
            _section(s.preferencesSection, [
              _row(
                icon: Icons.language_outlined,
                title: s.langSettings,
                subtitle: appState.localeCode.toUpperCase(),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const LanguageSettingsScreen())),
              ),
              _row(
                icon: Icons.bar_chart_outlined,
                title: s.p11LanguageAnalytics,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const LanguageAnalyticsScreen())),
              ),
              _row(
                icon: Icons.notifications_outlined,
                title: s.notifications,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const NotificationsScreen())),
              ),
              _row(
                icon: Icons.dark_mode_outlined,
                title: s.appearanceLabel,
                trailing: ListenableBuilder(
                  listenable: appState,
                  builder: (_, __) => Switch(
                    value: appState.themeMode == ThemeMode.dark,
                    onChanged: (_) => appState.toggleTheme(),
                  ),
                ),
              ),
            ]),
            _section(s.planBillingSection, [
              _row(
                icon: Icons.credit_card_outlined,
                title: s.billingTitle,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BillingScreen())),
              ),
            ]),
            _section(s.trustLegalSection, [
              _row(
                icon: Icons.description_outlined,
                title: s.userAgreement,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LegalDocumentScreen(
                      doc: LegalDoc.userAgreement,
                    ),
                  ),
                ),
              ),
              _row(
                icon: Icons.privacy_tip_outlined,
                title: s.privacyPolicy,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LegalDocumentScreen(
                      doc: LegalDoc.privacyPolicy,
                    ),
                  ),
                ),
              ),
              _row(
                icon: Icons.verified_user_outlined,
                iconColor: VirelloColors.pink,
                title: s.howVirelloGrows,
                onTap: () => _trustDialog(context, s.howVirelloGrows,
                    '${s.neverFake}\n\n${s.noGuarantees}'),
              ),
              _row(
                icon: Icons.block_outlined,
                iconColor: VirelloColors.danger,
                title: s.whatWeNeverDo,
                onTap: () =>
                    _trustDialog(context, s.whatWeNeverDo, s.neverDoList),
              ),
            ]),
            _section(s.supportSection, [
              _row(
                icon: Icons.support_agent_outlined,
                title: s.liveChatSupport,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const SupportChatScreen())),
              ),
              _row(
                icon: Icons.play_circle_outline_rounded,
                iconColor: VirelloColors.pink,
                title: s.tutorialMenu,
                subtitle: s.tutorialMenuSub,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const TutorialGuideScreen())),
              ),
              _row(
                icon: Icons.tour_outlined,
                iconColor: VirelloColors.pink,
                title: s.takeAppTour,
                subtitle: s.takeAppTourSub,
                onTap: () async {
                  await AppTourService.resetTour();
                  if (!context.mounted) return;
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  requestedTour.value = true;
                },
              ),
            ]),
            _section(s.aboutSection, [
              _row(
                icon: Icons.business_outlined,
                title: s.p11Company,
                subtitle: 'Virello AI',
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CompanyScreen())),
              ),
              _row(
                icon: Icons.cleaning_services_outlined,
                title: s.clearCache,
                subtitle: s.clearCacheSub,
                onTap: () => _clearCache(context),
              ),
              _row(
                icon: Icons.info_outline,
                title: s.appVersion,
                subtitle: '1.0.0',
                trailing: const SizedBox.shrink(),
              ),
            ]),
            const SizedBox(height: 22),
            OutlinedButton(
              onPressed: () => _confirmSignOut(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
                side: const BorderSide(color: VirelloColors.danger, width: 1.2),
              ),
              child: Text(s.signOut,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: VirelloColors.danger)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _confirmDeleteAccount(context),
              child: Text(s.deleteAccount,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: VirelloColors.danger)),
            ),
          ],
        ),
      ),
    );
  }
}
