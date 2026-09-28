import 'package:flutter/material.dart';

import 'strings.dart';
import 'theme.dart';
import '../main.dart';
import '../services/api_client.dart';

/// Bottom sheet listing the user's real broadcast notifications
/// (GET /api/v1/users/notifications). Used from Shop + Discover headers.
/// Never invents notifications — empty state when the server has none.
class NotificationsSheet {
  static Future<void> show(BuildContext context) async {
    final s = AppStrings(appState.localeCode);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF161616) : VirelloColors.cardBg;
    final ink = dark ? Colors.white : VirelloColors.ink;

    List<Map<String, dynamic>> items = [];
    String? error;
    try {
      final data = await apiClient.notifications();
      items = ((data['notifications'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } on AuthException {
      handleAuthFailure(s.sessionExpired);
      return;
    } catch (_) {
      error = s.askFailed;
    }

    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.2)
                        : VirelloColors.divider,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                s.discoverNotifications,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: ink),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: error != null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                            child: Text(error,
                                style: const TextStyle(
                                    color: VirelloColors.muted))),
                      )
                    : items.isEmpty
                        ? Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                      Icons.notifications_none_outlined,
                                      size: 44,
                                      color: VirelloColors.muted),
                                  const SizedBox(height: 10),
                                  Text(s.discoverNoNotifications,
                                      style: const TextStyle(
                                          color: VirelloColors.muted)),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final n = items[i];
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: dark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : VirelloColors.chipBg,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('${n['title'] ?? ''}',
                                        style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: ink)),
                                    if ('${n['body'] ?? ''}'.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text('${n['body']}',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: VirelloColors.muted,
                                              height: 1.45)),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// True when the user has at least one notification (for the red dot).
  static Future<bool> hasAny() async {
    try {
      final data = await apiClient.notifications();
      final items = (data['notifications'] as List?) ?? [];
      return items.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
