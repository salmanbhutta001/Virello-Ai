import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../main.dart';
import '../ask_virello/ask_virello_screen.dart';

/// Shop tab placeholder (Phase 1). Honest "coming in Phase 4" surface with
/// the layout skeleton inspired by Hafiz's reference images — no fake
/// products, prices, or sellers anywhere.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.shop)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search bar skeleton (disabled — honest placeholder).
            TextField(
              enabled: false,
              decoration: InputDecoration(
                hintText: 'Search products…',
                prefixIcon: const Icon(Icons.search_outlined),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: VirelloColors.chipBg,
              ),
            ),
            const SizedBox(height: 12),
            // Category chips skeleton.
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Chip(
                  label:
                      Text(['All', 'Men', 'Women', 'Sale', 'Best Sellers'][i]),
                  backgroundColor: VirelloColors.chipBg,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Coming-soon hero.
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: VirelloColors.brandGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(Icons.shopping_bag_outlined,
                      color: Colors.white, size: 48),
                  const SizedBox(height: 12),
                  Text(s.shopComingSoon,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(s.shopComingSoonDesc,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13, height: 1.5)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: VirelloColors.violet),
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const AskVirelloScreen()));
                    },
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: Text(s.actionAskVirello),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Empty product grid skeleton — visibly empty, no fake items.
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: 4,
              itemBuilder: (_, __) => Container(
                decoration: BoxDecoration(
                  color: VirelloColors.chipBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(Icons.image_outlined,
                      color: VirelloColors.muted, size: 32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Global signal: when true, RootShell opens the Ask Virello screen.
final askVirelloRequested = ValueNotifier<bool>(false);
