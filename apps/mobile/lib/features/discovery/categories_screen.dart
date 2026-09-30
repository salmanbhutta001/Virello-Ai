import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/discovery_models.dart';
import '../../main.dart';
import 'discovery_screen.dart';

/// Board screen 10: "Categories" — pixel-faithful rebuild.
///
/// 2-column grid of category rows (pink-circle icon + label) per the board:
/// Fashion, Food & Recipes, Tech & Gadgets, Beauty & Skincare,
/// Home & Living, Travel, Education, More.
/// Tapping a category opens Discover with a real client-side keyword filter.
/// "More" lists the real backend topics — tapping one filters Discover too.
/// Never shows fake categories or counts.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    final cats = [
      _Cat(s.boardCatFashion, Icons.checkroom_outlined, 'fashion'),
      _Cat(s.boardCatFood, Icons.restaurant_outlined, 'food'),
      _Cat(s.boardCatTech, Icons.devices_outlined, 'tech'),
      _Cat(s.boardCatBeauty, Icons.spa_outlined, 'beauty'),
      _Cat(s.boardCatHome, Icons.home_outlined, 'home'),
      _Cat(s.boardCatTravel, Icons.flight_outlined, 'travel'),
      _Cat(s.boardCatEducation, Icons.school_outlined, 'education'),
    ];
    return Scaffold(
      backgroundColor: VTheme.scaffold(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context, s),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.4,
                ),
                itemCount: cats.length + 1, // + More
                itemBuilder: (_, i) {
                  if (i == cats.length) {
                    return _catCard(
                      context,
                      _Cat(s.boardCatMore, Icons.more_horiz, ''),
                      isMore: true,
                    );
                  }
                  return _catCard(context, cats[i]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AppStrings s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 14),
      child: Row(
        children: [
          IconButton(
            icon:  Icon(Icons.arrow_back, color: VTheme.text(context), size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Text(
            s.boardCategories,
            style:  TextStyle(
              color: VTheme.text(context),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _catCard(BuildContext context, _Cat cat, {bool isMore = false}) {
    return InkWell(
      onTap: () {
        if (isMore) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const _AllTopicsScreen()),
          );
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DiscoveryScreen(initialFilter: cat.keyword),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: VTheme.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VTheme.divider(context)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: VirelloColors.pink.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(cat.icon, color: VirelloColors.pink, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                cat.label,
                style:  TextStyle(
                  color: VTheme.onBrand(context),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _Cat {
  final String label;
  final IconData icon;
  final String keyword;
  const _Cat(this.label, this.icon, this.keyword);
}

/// "More": the real backend topic list — tapping filters Discover.
class _AllTopicsScreen extends StatefulWidget {
  const _AllTopicsScreen();
  @override
  State<_AllTopicsScreen> createState() => _AllTopicsScreenState();
}

class _AllTopicsScreenState extends State<_AllTopicsScreen> {
  AppStrings get s => AppStrings(appState.localeCode);
  late Future<List<Topic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Topic>> _load() async {
    try {
      return await apiClient.getTopics();
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VTheme.scaffold(context),
      appBar: AppBar(
        backgroundColor: VTheme.scaffold(context),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          s.boardTopicsAll,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<List<Topic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: VirelloColors.pink),
            );
          }
          final topics = snap.data ?? const <Topic>[];
          if (topics.isEmpty) {
            return Center(
              child: Text(
                s.nothingHere,
                style: TextStyle(color: VTheme.textSec(context)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: topics.length,
            separatorBuilder: (_, __) =>
                Divider(color: VTheme.divider(context), height: 1),
            itemBuilder: (_, i) {
              final t = topics[i];
              final label = t.name(appState.localeCode);
              final display = label.isEmpty ? t.slug : label;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: VirelloColors.pink.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.tag,
                    color: VirelloColors.pink,
                    size: 22,
                  ),
                ),
                title: Text(
                  display,
                  style:  TextStyle(
                    color: VTheme.onBrand(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing:  Icon(
                  Icons.chevron_right,
                  color: VTheme.textSec(context),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DiscoveryScreen(initialFilter: display),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
