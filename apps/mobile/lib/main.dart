import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/strings.dart';
import 'services/api_client.dart';
import 'services/auth_store.dart';
import 'services/saved_store.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/home/home_screen.dart';
import 'features/discovery/discovery_screen.dart';
import 'features/create/create_hub_screen.dart';
import 'features/campaigns/campaigns_screen.dart';
import 'features/profile/profile_screen.dart';

/// Shared app services.
final authStore = AuthStore();
final apiClient = ApiClient(tokenProvider: () => authStore.accessToken);
final savedStore = SavedStore();

/// Cross-tab navigation: set [requestedTab] to jump the bottom nav,
/// [pendingGrowUrl] to pre-fill the Grow flow with a post URL.
/// Tab indices: 0 Home · 1 Discover · 2 Create · 3 Campaigns · 4 Profile.
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
  String localeCode = 'en'; // 'en' | 'ur' | 'ar' (RTL-ready)

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

  @override
  void initState() {
    super.initState();
    appState.addListener(() => setState(() {}));
    authStore.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    authStore.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// Log one app-open visit per session for the admin analytics dashboard
  /// (server-side throttled; failures never affect the app).
  void _onAuthChanged() {
    setState(() {});
    if (!_trackedOpen && authStore.loaded && authStore.signedIn) {
      _trackedOpen = true;
      ApiClient().trackAppOpen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Virello',
      debugShowCheckedModeBanner: false,
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
    // If signed in, go straight to the app (skip splash).
    // If not signed in, show splash first, then login.
    if (!authStore.signedIn) {
      if (!_splashSeen) {
        return SplashScreen(
          onGetStarted: () => setState(() => _splashSeen = true),
        );
      }
      return const SignInScreen();
    }
    return const RootShell();
  }
}

/// Bottom-nav shell per the approved board:
/// Home · Discover · [+] (Create hub) · Campaigns · Profile.
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

  @override
  void initState() {
    super.initState();
    requestedTab.addListener(_onRequestedTab);
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
      return OnboardingScreen(onDone: () => setState(() => _onboarded = true));
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
        page = const ProfileScreen();
        break;
      default:
        page = const HomeScreen();
    }
    return Scaffold(
      body: page,
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _bottomBar() {
    final items = <_NavItem?>[
      _NavItem(Icons.home_outlined, Icons.home, s.home, 0),
      _NavItem(Icons.explore_outlined, Icons.explore, s.discover, 1),
      null, // center + button
      _NavItem(Icons.campaign_outlined, Icons.campaign, s.campaigns, 3),
      _NavItem(Icons.person_outlined, Icons.person, s.profile, 4),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
            top: BorderSide(color: VirelloColors.divider, width: 1)),
        boxShadow: [
          BoxShadow(
            color: VirelloColors.navy.withValues(alpha: 0.06),
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
                        color:
                            active ? VirelloColors.violet : VirelloColors.muted,
                        size: 24,
                      ),
                      const SizedBox(height: 3),
                      Text(it.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                            color: active
                                ? VirelloColors.violet
                                : VirelloColors.muted,
                          )),
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
              gradient: VirelloColors.brandGradient,
              boxShadow: [
                BoxShadow(
                  color: VirelloColors.violet.withValues(alpha: 0.45),
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
