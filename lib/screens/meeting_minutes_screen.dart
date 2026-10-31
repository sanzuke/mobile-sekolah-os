import 'package:flutter/material.dart';

import '../models/meeting_models.dart';
import '../services/api_client.dart';
import '../services/teacher_service.dart';
import '../widgets/date_format.dart';
import '../widgets/surface_cards.dart';
import 'meeting_minute_detail_screen.dart';
import 'meeting_minute_form_screen.dart';

/// "Rapat & Notulen": the minutes I wrote (drafts included) and those of
/// meetings I attended or was given a task in.
class MeetingMinutesScreen extends StatefulWidget {
  const MeetingMinutesScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;

  @override
  State<MeetingMinutesScreen> createState() => _MeetingMinutesScreenState();
}

class _MeetingMinutesScreenState extends State<MeetingMinutesScreen> {
  // Bumped to make both tabs reload (after writing, or coming back from a detail).
  final _version = ValueNotifier<int>(0);

  @override
  void dispose() {
    _version.dispose();
    super.dispose();
  }

  Future<void> _write() async {
    await openMeetingForm(context, widget.service, widget.onUnauthorized);
    if (mounted) _version.value++;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rapat & Notulen'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Notulen saya'),
              Tab(text: 'Saya hadiri'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _write,
          icon: const Icon(Icons.add),
          label: const Text('Tulis notulen'),
        ),
        body: TabBarView(
          children: [
            _MinutesList(
              scope: 'mine',
              service: widget.service,
              onUnauthorized: widget.onUnauthorized,
              version: _version,
            ),
            _MinutesList(
              scope: 'attended',
              service: widget.service,
              onUnauthorized: widget.onUnauthorized,
              version: _version,
            ),
          ],
        ),
      ),
    );
  }
}

class _MinutesList extends StatefulWidget {
  const _MinutesList({
    required this.scope,
    required this.service,
    required this.onUnauthorized,
    required this.version,
  });

  final String scope;
  final TeacherService service;
  final VoidCallback onUnauthorized;
  final ValueNotifier<int> version;

  @override
  State<_MinutesList> createState() => _MinutesListState();
}

class _MinutesListState extends State<_MinutesList>
    with AutomaticKeepAliveClientMixin {
  final List<MeetingMinute> _items = [];
  int _page = 0;
  int _lastPage = 1;
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.version.addListener(_refresh);
    _loadMore();
  }

  @override
  void dispose() {
    widget.version.removeListener(_refresh);
    super.dispose();
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
      final res = await widget.service.meetingMinutes(
        scope: widget.scope,
        page: _page + 1,
      );
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

  Future<void> _open(MeetingMinute m) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MeetingMinuteDetailScreen(
          service: widget.service,
          onUnauthorized: widget.onUnauthorized,
          id: m.id,
        ),
      ),
    );
    if (mounted) widget.version.value++;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty && _error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: FilledButton(
              onPressed: _refresh,
              child: const Text('Coba lagi'),
            ),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      final mine = widget.scope == 'mine';
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            EmptyState(
              icon: Icons.event_note_outlined,
              title: mine
                  ? 'Belum ada notulen'
                  : 'Belum ada notulen untuk Anda',
              message: mine ? 'Ketuk Tulis notulen untuk mencatat rapat.' : 'Notulen rapat yang Anda hadiri atau yang memberi Anda tugas muncul di sini setelah difinalkan.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          for (final m in _items) _MinuteCard(item: m, onTap: () => _open(m)),
          if (_page < _lastPage)
            Center(
              child: TextButton(
                onPressed: _loading ? null : _loadMore,
                child: Text(_loading ? 'Memuat…' : 'Muat lebih banyak'),
              ),
            ),
        ],
      ),
    );
  }
}

class _MinuteCard extends StatelessWidget {
  const _MinuteCard({required this.item, required this.onTap});

  final MeetingMinute item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final open = item.openActionCount ?? 0;
    return Surface(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                MeetingStatusChip(isFinal: item.isFinal),
                Text(item.categoryLabel, style: text.bodySmall),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(meetingWhen(item), style: text.bodyMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 2,
              children: [
                if (item.attendeeCount != null)
                  Text('${item.attendeeCount} peserta', style: text.bodySmall),
                if ((item.actionCount ?? 0) > 0)
                  Text(
                    open > 0
                        ? '$open dari ${item.actionCount} tugas terbuka'
                        : 'Semua tugas selesai',
                    style: text.bodySmall?.copyWith(
                      color: open > 0 ? const Color(0xFF92400E) : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// `Sen, 2 Nov 2026 · 08:00–09:30`.
String meetingWhen(MeetingMinute m) {
  final time = m.startTime == null
      ? ''
      : ' · ${m.startTime}${m.endTime != null ? '–${m.endTime}' : ''}';
  return '${formatDate(m.heldOn)}$time';
}

class MeetingStatusChip extends StatelessWidget {
  const MeetingStatusChip({super.key, required this.isFinal});

  final bool isFinal;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = isFinal
        ? (const Color(0xFFD5EDEA), const Color(0xFF0F766E), 'Final')
        : (const Color(0xFFFEF3E2), const Color(0xFF92400E), 'Draft');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
