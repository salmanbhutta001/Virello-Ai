import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'core/strings.dart';
import 'services/api_client.dart';
import 'services/auth_store.dart';
import 'services/saved_store.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/language_select_screen.dart';
import 'features/onboarding/interests_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/splash/welcome_screen.dart';
import 'features/home/home_screen.dart';
import 'features/discovery/discovery_screen.dart';
import 'features/create/create_hub_screen.dart';
import 'features/campaigns/campaigns_screen.dart';
import 'features/ask_virello/ask_virello_screen.dart';
import 'features/shop/shop_screen.dart';
import 'features/profile/profile_screen.dart';

/// Shared app services.
final authStore = AuthStore();
final apiClient = ApiClient(tokenProvider: () => authStore.accessToken);
final savedStore = SavedStore();

/// Cross-tab navigation: set [requestedTab] to jump the bottom nav,
/// [pendingGrowUrl] to pre-fill the Grow flow with a post URL.
/// Tab indices: 0 Home · 1 Discover · 2 Create · 3 Grow · 4 Shop · 5 Profile.
final requestedTab = ValueNotifier<int?>(null);
final pendingGrowUrl = ValueNotifier<String?>(null);

/// Drops a dead session and routes to sign-in with an explanatory notice.
Future<void> handleAuthFailure(String notice) async {
  authStore.lastNotice = notice;
  await authStore.signOut();
}

void main() async {
  // Show actual errors instead of blank screens in release mode.
  // This helps diagnose rendering issues on the phone.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Container(
        color: const Color(0xFFFFE0E0),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(
            'ERROR:\n${details.exception}\n\n${details.stack}',
            style: const TextStyle(color: Color(0xFF990000), fontSize: 12),
          ),
        ),
      ),
    );
  };
  WidgetsFlutterBinding.ensureInitialized();
  await savedStore.init();
  await authStore.load();
  runApp(const VirelloApp());
}

/// App-wide state: theme mode + locale. Kept dependency-light on purpose;
/// swap for Riverpod providers as the app grows.
class AppState extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.light;
  String localeCode =
      'en'; // 11 full UI langs: en ur ar hi fr es pt de tr id bn (ur/ar RTL)

  void toggleTheme() {
    themeMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setLocale(String code) {
    localeCode = code;
    notifyListeners();
  }
}

final appState = AppState();

class VirelloApp extends StatefulWidget {
  const VirelloApp({super.key});
  @override
  State<VirelloApp> createState() => _VirelloAppState();
}

class _VirelloAppState extends State<VirelloApp> {
  bool _trackedOpen = false;
  bool _splashSeen = false;
  // Master-board post-sign-in onboarding: 0 = language select, 1 = interests.
  int _boardStep = 0;
  bool _boardOnboarded = false;

  /// Navigator key so auth transitions can reset the route stack.
  /// (Changing MaterialApp.home alone does NOT clear routes that were
  /// pushed on top — e.g. SignInScreen pushed from WelcomeScreen — which
  /// left users staring at the login screen after a successful login.)
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  bool _wasSignedIn = false;
  bool _navResetScheduled = false;

  @override
  void initState() {
    super.initState();
    appState.addListener(() => setState(() {}));
    authStore.addListener(_onAuthChanged);
    _loadBoardFlag();
  }

  Future<void> _loadBoardFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(
          () => _boardOnboarded =
              prefs.getBool('virello_board_onboarded') ?? false,
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    authStore.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// Log one app-open visit per session for the admin analytics dashboard
  /// (server-side throttled; failures never affect the app).
  ///
  /// Also resets the navigation stack on sign-in / sign-out transitions so
  /// the user immediately sees the post-login (or signed-out) screen instead
  /// of a stale pushed route. The replacement route builds `_root()` lazily,
  /// so later state changes (e.g. finishing onboarding) keep working.
  void _onAuthChanged() {
    final nowSignedIn = authStore.loaded && authStore.signedIn;
    final justSignedIn = nowSignedIn && !_wasSignedIn;
    final justSignedOut = !nowSignedIn && _wasSignedIn;
    _wasSignedIn = nowSignedIn;
    setState(() {});
    if (!_trackedOpen && nowSignedIn) {
      _trackedOpen = true;
      ApiClient().trackAppOpen();
    }
    if ((justSignedIn || justSignedOut) && !_navResetScheduled) {
      _navResetScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navResetScheduled = false;
        _navKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => _root()),
          (route) => false,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Virello',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navKey,
      theme: VirelloTheme.light(),
      darkTheme: VirelloTheme.dark(),
      themeMode: appState.themeMode,
      locale: Locale(appState.localeCode),
      home: _root(),
    );
  }

  Widget _root() {
    if (!authStore.loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Signed-out: Splash (board 01) -> Welcome (board 02) -> Sign In.
    if (!authStore.signedIn) {
      if (!_splashSeen) {
        return SplashScreen(
          onGetStarted: () => setState(() => _splashSeen = true),
        );
      }
      return const WelcomeScreen();
    }
    // Signed-in: board Language Select (05) -> Interests (06), once.
    if (!_boardOnboarded) {
      if (_boardStep == 0) {
        return LanguageSelectScreen(
          onDone: () => setState(() => _boardStep = 1),
        );
      }
      return InterestsScreen(
        onDone: () => setState(() {
          _boardStep = 0;
          _boardOnboarded = true;
        }),
      );
    }
    return const RootShell();
  }
}

/// Bottom-nav shell per the approved board (Phase 1 evolution):
/// Home · Discover · [+] (Create hub) · Grow · Shop · Profile.
/// Ask Virello FAB floats above the bar on Home/Discover/Grow tabs.
/// The center + button is a raised violet circle opening the Create hub.
class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  AppStrings get s => AppStrings(appState.localeCode);

  int _index = 0;
  bool _onboarded = false;
  static const _onboardedKey = 'virello_onboarded';

  @override
  void initState() {
    super.initState();
    requestedTab.addListener(_onRequestedTab);
    _loadOnboarded();
  }

  Future<void> _loadOnboarded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() => _onboarded = prefs.getBool(_onboardedKey) ?? false);
      }
    } catch (_) {}
  }

  Future<void> _setOnboarded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardedKey, true);
    } catch (_) {}
    if (mounted) setState(() => _onboarded = true);
  }

  @override
  void dispose() {
    requestedTab.removeListener(_onRequestedTab);
    super.dispose();
  }

  void _onRequestedTab() {
    final i = requestedTab.value;
    if (i != null) {
      requestedTab.value = null;
      setState(() => _index = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_onboarded) {
      return OnboardingScreen(onDone: _setOnboarded);
    }
    // NOTE: Using direct page instead of IndexedStack to avoid nested
    // Scaffold rendering issues. Pages are rebuilt on tab switch.
    Widget page;
    switch (_index) {
      case 0:
        page = const HomeScreen();
        break;
      case 1:
        page = const DiscoveryScreen();
        break;
      case 2:
        page = const CreateHubScreen();
        break;
      case 3:
        page = const CampaignsScreen();
        break;
      case 4:
        page = const ShopScreen();
        break;
      case 5:
        page = const ProfileScreen();
        break;
      default:
        page = const HomeScreen();
    }
    // NOTE: Using Material+Column instead of Scaffold to avoid nested
    // Scaffold issues. Each tab screen has its own Scaffold.
    // Stack overlays the Ask Virello FAB above the bottom bar.
    return Material(
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(child: page),
                _bottomBar(),
              ],
            ),
            if (_showAskFab) _askFab(),
          ],
        ),
      ),
    );
  }

  /// Ask Virello FAB: visible on Home, Discover and Grow tabs.
  bool get _showAskFab => _index == 0 || _index == 1 || _index == 3;

  Widget _askFab() {
    return Positioned(
      right: 16,
      bottom: 96,
      child: GestureDetector(
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AskVirelloScreen()));
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [VirelloColors.pink, Color(0xFFC2274E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: VirelloColors.pink.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final items = <_NavItem?>[
      _NavItem(Icons.home_outlined, Icons.home, s.home, 0),
      _NavItem(Icons.explore_outlined, Icons.explore, s.discover, 1),
      null, // center + button
      _NavItem(Icons.trending_up_outlined, Icons.trending_up, s.grow, 3),
      _NavItem(Icons.shopping_bag_outlined, Icons.shopping_bag, s.shop, 4),
      _NavItem(Icons.person_outlined, Icons.person, s.profile, 5),
    ];
    return Container(
      decoration: BoxDecoration(
        color: VirelloColors.boardBg,
        border: const Border(
          top: BorderSide(color: VirelloColors.boardBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: items.map((it) {
            if (it == null) return Expanded(child: _centerButton());
            final active = _index == it.index;
            return Expanded(
              child: InkWell(
                onTap: () => setState(() => _index = it.index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        active ? it.activeIcon : it.icon,
                        color: active
                            ? VirelloColors.pink
                            : VirelloColors.boardTextSec,
                        size: 24,
                      ),
                      const SizedBox(height: 3),
                      // Pink active indicator dot — board style.
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              active ? VirelloColors.pink : Colors.transparent,
                        ),
                      ),
                      Text(
                        it.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                          color: active
                              ? VirelloColors.pink
                              : VirelloColors.boardTextSec,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _centerButton() {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -10),
        child: GestureDetector(
          onTap: () => setState(() => _index = 2),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [VirelloColors.pink, Color(0xFFC2274E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: VirelloColors.pink.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  const _NavItem(this.icon, this.activeIcon, this.label, this.index);
}
