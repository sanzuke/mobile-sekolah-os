import 'package:flutter/material.dart';

import '../models/teacher_models.dart';
import '../services/api_client.dart';
import '../services/teacher_service.dart';
import '../widgets/async_view.dart';
import '../widgets/date_format.dart';
import 'announcement_detail_screen.dart';
import 'notification_list.dart';

/// "Kotak masuk" tab: Pengumuman, Agenda and Notifikasi. Laporan from the
/// design lands here when its endpoint exists.
class InboxScreen extends StatefulWidget {
  const InboxScreen({
    super.key,
    required this.service,
    required this.unread,
    required this.onUnauthorized,
  });

  final TeacherService service;
  final ValueNotifier<int> unread;
  final VoidCallback onUnauthorized;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<int>(
            segments: [
              const ButtonSegment(value: 0, label: Text('Pengumuman')),
              const ButtonSegment(value: 1, label: Text('Agenda')),
              ButtonSegment(
                value: 2,
                label: ValueListenableBuilder<int>(
                  valueListenable: widget.unread,
                  builder: (_, count, _) => Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Text('Notifikasi'),
                    ),
                  ),
                ),
              ),
            ],
            selected: {_segment},
            onSelectionChanged: (s) => setState(() => _segment = s.first),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _segment,
            children: [
              AnnouncementList(
                  service: widget.service,
                  onUnauthorized: widget.onUnauthorized),
              AgendaList(
                  service: widget.service,
                  onUnauthorized: widget.onUnauthorized),
              NotificationList(
                  service: widget.service,
                  unread: widget.unread,
                  onUnauthorized: widget.onUnauthorized),
            ],
          ),
        ),
      ],
    );
  }
}

class AnnouncementList extends StatefulWidget {
  const AnnouncementList(
      {super.key, required this.service, required this.onUnauthorized});

  final TeacherService service;
  final VoidCallback onUnauthorized;

  @override
  State<AnnouncementList> createState() => _AnnouncementListState();
}

class _AnnouncementListState extends State<AnnouncementList> {
  final List<Announcement> _items = [];
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
      final res = await widget.service.announcements(page: _page + 1);
      _items.addAll(res.items);
      _page += 1;
      _lastPage = res.lastPage;
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      _error = e.message;
    } catch (_) {
      _error = 'Tidak dapat terhubung ke server.';
    }
    if (mounted) setState(() => _loading = false);
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
            Icon(_error == null ? Icons.campaign_outlined : Icons.cloud_off,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(_error ?? 'Belum ada pengumuman.',
                textAlign: TextAlign.center),
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

    final hasMore = _page < _lastPage;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _items.length + 1,
        itemBuilder: (context, i) {
          if (i == _items.length) {
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
          final a = _items[i];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.campaign_outlined),
            title: Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text([
              if (a.category != null) a.category!,
              if (a.publishedAt != null)
                formatDate(a.publishedAt!.toLocal().toIso8601String()),
            ].join(' · ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AnnouncementDetailScreen(
                id: a.id,
                title: a.title,
                service: widget.service,
                onUnauthorized: widget.onUnauthorized,
              ),
            )),
          );
        },
      ),
    );
  }
}

class AgendaList extends StatelessWidget {
  const AgendaList(
      {super.key, required this.service, required this.onUnauthorized});

  final TeacherService service;
  final VoidCallback onUnauthorized;

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<AgendaItem>>(
      load: () => service.agenda(),
      onUnauthorized: onUnauthorized,
      builder: (context, items) {
        if (items.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: const [
              SizedBox(height: 60),
              Icon(Icons.event_busy, size: 48),
              SizedBox(height: 12),
              Text('Tidak ada agenda dalam 30 hari ke depan.',
                  textAlign: TextAlign.center),
            ],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final a = items[i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(a.title),
              subtitle: Text([
                _dates(a),
                if (a.timeRange != null) a.timeRange!,
                if (a.location != null) a.location!,
                a.typeLabel,
              ].join(' · ')),
            );
          },
        );
      },
    );
  }

  static String _dates(AgendaItem a) {
    final s = a.startDate;
    final e = a.endDate;
    if (s == null) return '';
    if (e == null || e == s) return formatDate(s);
    return formatRange(s, e);
  }
}
