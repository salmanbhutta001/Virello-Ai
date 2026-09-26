import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../main.dart';

/// User-facing notifications: admin broadcasts localized to the user's
/// preferred language when a translation exists. When it doesn't, the
/// base-language text is shown with an honest fallback note — never
/// silently substituted.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await apiClient.notifications();
      if (!mounted) return;
      setState(() {
        _items = (r['notifications'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    return Scaffold(
      appBar: AppBar(title: Text(s.notifications)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _items.isEmpty
                  ? Center(child: Text(s.noNotifications))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final n = _items[i];
                          final fallback = n['fallback_used'] == true;
                          return Card(
                            child: ListTile(
                              leading: const Icon(
                                  Icons.notifications_outlined),
                              title: Text('${n['title'] ?? ''}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text('${n['body'] ?? ''}'),
                                  const SizedBox(height: 4),
                                  Text(
                                    fallback
                                        ? '⚠ ${s.langFallbackNote}'
                                        : '${s.langOriginal}: '
                                            '${n['language_requested'] ?? ''}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: fallback
                                                ? Colors.amber[800]
                                                : Colors.grey),
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
