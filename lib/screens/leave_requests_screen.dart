import 'package:flutter/material.dart';

import '../models/leave_models.dart';
import '../services/api_client.dart';
import '../services/attachment_picker.dart';
import '../services/teacher_service.dart';
import '../widgets/surface_cards.dart';
import '../widgets/leave_widgets.dart';
import 'leave_detail_screen.dart';
import 'leave_form_screen.dart';

/// "Izin / Cuti": the teacher's own requests, newest first, with a status filter
/// and a button to submit a new one.
class LeaveRequestsScreen extends StatefulWidget {
  const LeaveRequestsScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
    this.picker = const FileAttachmentPicker(),
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;
  final AttachmentPicker picker;

  @override
  State<LeaveRequestsScreen> createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends State<LeaveRequestsScreen> {
  final List<LeaveRequest> _items = [];
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
      final res =
          await widget.service.leaveRequests(status: _status, page: _page + 1);
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

  Future<void> _openForm() async {
    final created = await Navigator.of(context).push<LeaveRequest>(
        MaterialPageRoute(
            builder: (_) => LeaveFormScreen(
                service: widget.service,
                onUnauthorized: widget.onUnauthorized,
                picker: widget.picker)));
    if (!mounted) return;
    if (created != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Pengajuan terkirim dan menunggu persetujuan.')));
    }
    _refresh();
  }

  Future<void> _openDetail(LeaveRequest r) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => LeaveDetailScreen(
            service: widget.service,
            onUnauthorized: widget.onUnauthorized,
            id: r.id)));
    if (mounted) _refresh(); // it may have been cancelled
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Izin / Cuti')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('Ajukan'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final (value, label) in leaveStatuses)
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
      return ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 60),
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Center(
            child: FilledButton(
                onPressed: _refresh, child: const Text('Coba lagi'))),
      ]);
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          EmptyState(
            icon: Icons.event_busy_outlined,
            title: _status == null
                ? 'Belum ada pengajuan'
                : 'Tidak ada pengajuan dengan status ini',
            message: _status == null
                ? 'Ketuk Ajukan untuk membuat izin, sakit, cuti, atau dinas luar.'
                : 'Coba pilih status lain.',
          ),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
        children: [
          for (final r in _items) _LeaveCard(item: r, onTap: () => _openDetail(r)),
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

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.item, required this.onTap});

  final LeaveRequest item;
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
                  color: const Color(0xFFD5EDEA),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(leaveTypeIcon(item.type),
                  color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(item.typeLabel,
                            style: text.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800))),
                    const SizedBox(width: 8),
                    Flexible(
                      child: LeaveStatusChip(
                          status: item.status, label: item.statusLabel),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text(leaveRange(item.startDate, item.endDate),
                      style: text.bodyMedium),
                  const SizedBox(height: 4),
                  Text(item.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
