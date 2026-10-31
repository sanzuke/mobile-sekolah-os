import 'package:flutter/material.dart';

import '../models/teacher_models.dart';
import '../services/api_client.dart';
import '../services/teacher_service.dart';
import '../widgets/date_format.dart';
import '../widgets/surface_cards.dart';

/// Paginated notification cards. Tapping an unread one marks it read
/// (optimistically); [unread] drives the badges in the nav bar and on Beranda.
class NotificationList extends StatefulWidget {
  const NotificationList({
    super.key,
    required this.service,
    required this.unread,
    required this.onUnauthorized,
  });

  final TeacherService service;
  final ValueNotifier<int> unread;
  final VoidCallback onUnauthorized;

  @override
  State<NotificationList> createState() => _NotificationListState();
}

class _NotificationListState extends State<NotificationList> {
  final List<NotificationItem> _items = [];
  int _page = 0;
  int _lastPage = 1;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _refresh() async {
    _items.clear();
    _page = 0;
    _lastPage = 1;
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || (_page > 0 && _page >= _lastPage)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.service.notifications(page: _page + 1);
      _items.addAll(res.items);
      _page += 1;
      _lastPage = res.lastPage;
      widget.unread.value = res.unreadCount;
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      _error = e.message;
    } catch (_) {
      _error = 'Tidak dapat terhubung ke server.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _open(int index) async {
    final item = _items[index];
    if (item.isRead) return;
    setState(() => _items[index] = item.asRead());
    widget.unread.value = (widget.unread.value - 1).clamp(0, 1 << 30);
    try {
      await widget.service.markNotificationRead(item.id);
    } catch (_) {
      // Roll back so the badge never claims a read the server did not record.
      if (!mounted) return;
      setState(() => _items[index] = item);
      widget.unread.value += 1;
    }
  }

  Future<void> _readAll() async {
    try {
      await widget.service.markAllNotificationsRead();
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          _items[i] = _items[i].asRead();
        }
      });
      widget.unread.value = 0;
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: [
            EmptyState(
              icon: _error == null ? Icons.notifications_none : Icons.cloud_off,
              title: _error == null ? 'Belum ada notifikasi baru' : 'Gagal memuat',
              message: _error ??
                  'Persetujuan izin, tugas, dan undangan rapat akan muncul di sini.',
              actionLabel: _error == null ? null : 'Coba lagi',
              onAction: _refresh,
            ),
          ],
        ),
      );
    }

    final hasMore = _page < _lastPage;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 64),
        itemCount: _items.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Align(
              alignment: Alignment.centerRight,
              child: ValueListenableBuilder<int>(
                valueListenable: widget.unread,
                builder: (_, count, _) => TextButton(
                  onPressed: count > 0 ? _readAll : null,
                  child: const Text('Tandai semua dibaca'),
                ),
              ),
            );
          }
          final index = i - 1;
          if (index == _items.length) {
            if (_error != null) {
              return TextButton(
                  onPressed: _loadMore,
                  child: Text('$_error Ketuk untuk coba lagi.'));
            }
            if (!hasMore) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: _loading
                    ? const CircularProgressIndicator()
                    : OutlinedButton(
                        onPressed: _loadMore,
                        child: const Text('Muat lebih banyak')),
              ),
            );
          }
          return _NotificationCard(item: _items[index], onTap: () => _open(index));
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final unread = !item.isRead;
    return Surface(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: unread
                    ? scheme.primary.withValues(alpha: 0.12)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                unread ? Icons.notifications_active : Icons.notifications_none,
                color: unread ? scheme.primary : const Color(0xFF64748B),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
                  if (item.body != null) ...[
                    const SizedBox(height: 2),
                    Text(item.body!, style: text.bodyMedium),
                  ],
                  if (item.createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(formatDateTime(item.createdAt!), style: text.bodySmall),
                  ],
                ],
              ),
            ),
            if (unread)
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 4),
                child: CircleAvatar(
                    radius: 5, backgroundColor: Color(0xFFDC2626)),
              ),
          ],
        ),
      ),
    );
  }
}
