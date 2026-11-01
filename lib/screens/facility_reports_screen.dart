import 'package:flutter/material.dart';

import '../models/facility_models.dart';
import '../services/api_client.dart';
import '../services/teacher_service.dart';
import '../widgets/surface_cards.dart';
import 'facility_detail_screen.dart';
import 'facility_form_screen.dart';
import 'incidents_screen.dart' show incidentWhen;

/// "Sarpras": the facility reports I filed, newest first, with a status filter.
class FacilityReportsScreen extends StatefulWidget {
  const FacilityReportsScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;

  @override
  State<FacilityReportsScreen> createState() => _FacilityReportsScreenState();
}

class _FacilityReportsScreenState extends State<FacilityReportsScreen> {
  final List<FacilityReport> _items = [];
  String? _status;
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
      final res = await widget.service.facilityReports(
        status: _status,
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

  void _filter(String? status) {
    if (status == _status) return;
    setState(() => _status = status);
    _refresh();
  }

  Future<void> _write() async {
    await openFacilityForm(context, widget.service, widget.onUnauthorized);
    if (mounted) _refresh();
  }

  Future<void> _open(FacilityReport r) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FacilityDetailScreen(
          service: widget.service,
          onUnauthorized: widget.onUnauthorized,
          id: r.id,
        ),
      ),
    );
    if (mounted) _refresh(); // it may have been edited or withdrawn
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sarpras')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _write,
        icon: const Icon(Icons.add),
        label: const Text('Lapor'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final (value, label) in facilityStatuses)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _status == value,
                      onSelected: (_) => _filter(value),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
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
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            EmptyState(
              icon: Icons.build_outlined,
              title: _status == null
                  ? 'Belum ada laporan'
                  : 'Tidak ada laporan dengan status ini',
              message: _status == null
                  ? 'Ketuk Lapor untuk melaporkan fasilitas sekolah yang rusak atau bermasalah.'
                  : 'Coba pilih status lain.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
        children: [
          for (final r in _items) _FacilityCard(item: r, onTap: () => _open(r)),
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

class FacilityStatusChip extends StatelessWidget {
  const FacilityStatusChip({
    super.key,
    required this.status,
    required this.label,
  });

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'handling' => (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
      'resolved' => (const Color(0xFFD5EDEA), const Color(0xFF0F766E)),
      'rejected' => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
      'cancelled' => (const Color(0xFFF1F5F9), const Color(0xFF475569)),
      _ => (const Color(0xFFFEF3E2), const Color(0xFF92400E)),
    };
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

class _FacilityCard extends StatelessWidget {
  const _FacilityCard({required this.item, required this.onTap});

  final FacilityReport item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Surface(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.isUrgent
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFFEF3E2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.build_outlined,
                color: item.isUrgent
                    ? const Color(0xFFB91C1C)
                    : const Color(0xFF92400E),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${item.categoryLabel} · ${item.priorityLabel}',
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      FacilityStatusChip(
                        status: item.status,
                        label: item.statusLabel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(item.location, style: text.bodyMedium),
                  const SizedBox(height: 2),
                  Text(incidentWhen(item.createdAt), style: text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
