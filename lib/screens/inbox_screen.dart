import 'package:flutter/material.dart';

import '../models/teacher_models.dart';
import '../services/api_client.dart';
import '../services/teacher_service.dart';
import '../widgets/async_view.dart';
import '../widgets/surface_cards.dart';
import 'announcement_detail_screen.dart';
import 'notification_list.dart';
import 'shell_actions.dart';

/// "Kotak masuk" tab as in the design: a title, a Pengumuman / Notifikasi /
/// Laporan switch, and a card list (or a friendly empty state) under it.
/// Agenda is not here: it lives on Beranda and under the "Agenda Sekolah" menu.
class InboxScreen extends StatefulWidget {
  const InboxScreen({
    super.key,
    required this.service,
    required this.unread,
    required this.onUnauthorized,
    this.segmentRequest,
  });

  final TeacherService service;
  final ValueNotifier<int> unread;
  final VoidCallback onUnauthorized;

  /// Other screens (bell, menu tiles) ask for a segment by setting a value >= 0;
  /// it is consumed (reset to -1) so asking for the same segment again works.
  final ValueNotifier<int>? segmentRequest;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  int _segment = kInboxAnnouncements;

  @override
  void initState() {
    super.initState();
    widget.segmentRequest?.addListener(_onSegmentRequest);
  }

  @override
  void dispose() {
    widget.segmentRequest?.removeListener(_onSegmentRequest);
    super.dispose();
  }

  void _onSegmentRequest() {
    final request = widget.segmentRequest;
    if (request == null || request.value < 0) return;
    final segment = request.value;
    request.value = -1;
    setState(() => _segment = segment);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text('Kotak masuk',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _SegmentPills(
            selected: _segment,
            unread: widget.unread,
            onSelect: (i) => setState(() => _segment = i),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _segment,
            children: [
              AnnouncementList(
                  service: widget.service,
                  onUnauthorized: widget.onUnauthorized),
              NotificationList(
                  service: widget.service,
                  unread: widget.unread,
                  onUnauthorized: widget.onUnauthorized),
              const _ReportsEmpty(),
            ],
          ),
        ),
      ],
    );
  }
}

/// The design's switch: a grey track with the active option as a white pill.
class _SegmentPills extends StatelessWidget {
  const _SegmentPills({
    required this.selected,
    required this.unread,
    required this.onSelect,
  });

  final int selected;
  final ValueNotifier<int> unread;
  final ValueChanged<int> onSelect;

  static const _labels = ['Pengumuman', 'Notifikasi', 'Laporan'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                child: InkWell(
                  key: ValueKey('inbox-segment-$i'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onSelect(i),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _label(i),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _label(int i) {
    final text = Text(
      _labels[i],
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: i == selected ? const Color(0xFF0F172A) : const Color(0xFF475569),
      ),
    );
    if (i != kInboxNotifications) return text;
    // Unread count on "Notifikasi".
    return ValueListenableBuilder<int>(
      valueListenable: unread,
      builder: (_, count, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Flexible: with a large system font the label shrinks instead of overflowing.
          Flexible(child: text),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Laporan" (kejadian siswa, sarpras, kendaraan) has no backend yet.
class _ReportsEmpty extends StatelessWidget {
  const _ReportsEmpty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        EmptyState(
          icon: Icons.insert_chart_outlined,
          title: 'Belum ada laporan',
          message:
              'Laporan yang Anda kirim akan muncul di sini beserta status dan balasan staf.',
          actionLabel: 'Buat laporan',
          onAction: () {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(
                  content: Text('Buat laporan akan segera hadir')));
          },
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
          children: [
            EmptyState(
              icon: _error == null ? Icons.campaign_outlined : Icons.cloud_off,
              title: _error == null ? 'Belum ada pengumuman' : 'Gagal memuat',
              message: _error ?? 'Pengumuman sekolah akan muncul di sini.',
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 64),
        itemCount: _items.length + 1,
        itemBuilder: (context, i) {
          if (i == _items.length) {
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
          final a = _items[i];
          return AnnouncementCard(
            item: a,
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

/// Full school agenda (30 days ahead), opened from "Agenda Sekolah" in the menu.
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
            children: const [
              EmptyState(
                icon: Icons.event_busy,
                title: 'Tidak ada agenda',
                message: 'Belum ada agenda sekolah dalam 30 hari ke depan.',
              ),
            ],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: items.length,
          itemBuilder: (context, i) => AgendaCard(item: items[i], showDate: true),
        );
      },
    );
  }
}
