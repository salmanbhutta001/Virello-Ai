import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../profile/support_chat_screen.dart';

/// Board 69 — Company info.
///
/// Static and honest: who Virello AI is, what it does (legitimate
/// discovery — no fake engagement), the app version, and a support link
/// that opens the real AI Support chat. No fake addresses or claims.
class CompanyScreen extends StatelessWidget {
  const CompanyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(s.p11Company,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // Brand block (board style: centered logo + name + tagline).
            Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [VirelloColors.pink, VirelloColors.pinkDeep],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  alignment: Alignment.center,
                  child:  Text('V',
                      style: TextStyle(
                          color: VTheme.onBrand(context),
                          fontSize: 44,
                          fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 14),
                const Text('Virello AI',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(s.appTagline,
                    style: const TextStyle(
                        fontSize: 14, color: VirelloColors.muted)),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: VTheme.chip(context),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('${s.appVersion} 1.0.0',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: VirelloColors.muted)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            VBoardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.p11WhatVirelloDoes,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(s.p11CompanyDesc,
                      style: const TextStyle(fontSize: 14, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            VBoardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user_outlined,
                          color: VirelloColors.pink, size: 20),
                      const SizedBox(width: 8),
                      Text(s.p11WhatWeNeverDo,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(s.neverDoList,
                      style: const TextStyle(fontSize: 14, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            VPinkButton(
              label: s.p11ContactSupport,
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SupportChatScreen())),
            ),
          ],
        ),
      ),
    );
  }
}
