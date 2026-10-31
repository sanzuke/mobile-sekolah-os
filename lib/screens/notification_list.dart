import 'package:flutter/material.dart';

import '../models/teacher_models.dart';
import '../services/api_client.dart';
import '../services/teacher_service.dart';
import '../widgets/date_format.dart';

/// Paginated notification list. Tapping an unread item marks it read
/// (optimistically); [unread] drives the badge shown in the nav bar.
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
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 60),
            Icon(_error == null ? Icons.notifications_none : Icons.cloud_off,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              _error ??
                  'Belum ada notifikasi baru.\nPersetujuan izin, tugas, dan undangan rapat akan muncul di sini.',
              textAlign: TextAlign.center,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Center(
                  child: FilledButton(
                      onPressed: _refresh, child: const Text('Coba lagi'))),
            ],
          ],
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final hasMore = _page < _lastPage;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
            if (!hasMore) return const SizedBox(height: 24);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: _loading
                    ? const CircularProgressIndicator()
                    : OutlinedButton(
                        onPressed: _loadMore,
                        child: const Text('Muat lebih banyak')),
              ),
            );
          }
          final n = _items[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              n.isRead ? Icons.notifications_none : Icons.notifications_active,
              color: n.isRead ? scheme.outline : scheme.primary,
            ),
            title: Text(n.title,
                style: TextStyle(
                    fontWeight: n.isRead ? FontWeight.normal : FontWeight.w700)),
            subtitle: Text([
              if (n.body != null) n.body!,
              if (n.createdAt != null) formatDateTime(n.createdAt!),
            ].join('\n')),
            isThreeLine: n.body != null,
            onTap: () => _open(index),
          );
        },
      ),
    );
  }
}
