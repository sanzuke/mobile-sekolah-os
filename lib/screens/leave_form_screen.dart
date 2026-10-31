import 'package:flutter/material.dart';

import '../models/leave_models.dart';
import '../services/api_client.dart';
import '../services/attachment_picker.dart';
import '../services/teacher_service.dart';
import '../widgets/leave_widgets.dart';
import '../widgets/surface_cards.dart';

/// Server limits, mirrored so mistakes are caught before the upload.
const kLeaveBackdateDays = 7;
const kLeaveMaxDays = 90;
const kLeaveMaxAttachmentBytes = 5 * 1024 * 1024;

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _size(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB'
    : '${(bytes / 1024).ceil()} KB';

/// Submit a leave request: type, dates, reason, optional attachment. Once the
/// dates are chosen it shows which lessons would be left uncovered and which
/// school heads must approve. Pops with the created [LeaveRequest].
class LeaveFormScreen extends StatefulWidget {
  const LeaveFormScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
    this.picker = const FileAttachmentPicker(),
    this.initialRange,
    this.now,
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;
  final AttachmentPicker picker;
  final DateTimeRange? initialRange;

  /// Injectable clock for tests; defaults to the device clock.
  final DateTime? now;

  @override
  State<LeaveFormScreen> createState() => _LeaveFormScreenState();
}

class _LeaveFormScreenState extends State<LeaveFormScreen> {
  final _reason = TextEditingController();
  String? _type;
  DateTimeRange? _range;
  PickedAttachment? _attachment;
  String? _attachmentError;

  LeavePreview? _preview;
  String? _previewError;
  bool _previewLoading = false;
  int _previewSeq = 0;

  bool _submitting = false;
  String? _submitError;

  DateTime get _today {
    final n = widget.now ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange;
    if (_range != null) _loadPreview();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  int? get _days => _range == null
      ? null
      : _range!.end.difference(_range!.start).inDays + 1;

  String? get _rangeError => _days != null && _days! > kLeaveMaxDays
      ? 'Rentang tanggal maksimal $kLeaveMaxDays hari.'
      : null;

  bool get _valid =>
      _type != null &&
      _range != null &&
      _rangeError == null &&
      _reason.text.trim().length >= 5 &&
      _attachmentError == null &&
      _preview?.overlapsExisting != true &&
      !_previewLoading;

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: _today.subtract(const Duration(days: kLeaveBackdateDays)),
      lastDate: _today.add(const Duration(days: 365)),
      initialDateRange: _range,
      helpText: 'Pilih tanggal izin',
      saveText: 'Pilih',
    );
    if (picked == null) return;
    setState(() => _range = picked);
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    final range = _range;
    if (range == null || _rangeError != null) {
      setState(() => _preview = null);
      return;
    }
    final seq = ++_previewSeq;
    setState(() {
      _previewLoading = true;
      _previewError = null;
    });
    try {
      final p = await widget.service
          .previewLeave(_iso(range.start), _iso(range.end));
      if (!mounted || seq != _previewSeq) return;
      setState(() => _preview = p);
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      if (!mounted || seq != _previewSeq) return;
      setState(() {
        _preview = null;
        _previewError = e.message;
      });
    } catch (_) {
      if (!mounted || seq != _previewSeq) return;
      setState(() {
        _preview = null;
        _previewError = 'Tidak dapat memuat jam terdampak.';
      });
    }
    if (mounted && seq == _previewSeq) setState(() => _previewLoading = false);
  }

  Future<void> _pickAttachment() async {
    final file = await widget.picker.pick();
    if (file == null) return;
    setState(() {
      _attachment = file;
      _attachmentError = file.size > kLeaveMaxAttachmentBytes
          ? 'Lampiran maksimal 5 MB (berkas ini ${_size(file.size)}).'
          : null;
    });
  }

  Future<void> _submit() async {
    if (!_valid || _submitting) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final created = await widget.service.submitLeave(
        type: _type!,
        startDate: _iso(_range!.start),
        endDate: _iso(_range!.end),
        reason: _reason.text.trim(),
        attachmentName: _attachment?.name,
        attachmentBytes: _attachment?.bytes,
      );
      if (mounted) Navigator.of(context).pop(created);
      return;
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      _submitError = e.message;
    } catch (_) {
      _submitError = 'Tidak dapat terhubung ke server.';
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajukan izin / cuti')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('Jenis', style: text.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (value, label) in leaveTypes)
                ChoiceChip(
                  avatar: Icon(leaveTypeIcon(value), size: 18),
                  showCheckmark: false, // it would cover the icon
                  label: Text(label),
                  selected: _type == value,
                  onSelected: (_) => setState(() => _type = value),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Tanggal', style: text.titleSmall),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(_range == null
                  ? 'Pilih tanggal'
                  : '${leaveRange(_iso(_range!.start), _iso(_range!.end))} · $_days hari'),
            ),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
          ),
          if (_rangeError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_rangeError!,
                  style: TextStyle(color: scheme.error, fontSize: 12)),
            ),
          const SizedBox(height: 12),
          _PreviewCard(
              loading: _previewLoading,
              preview: _preview,
              error: _previewError,
              hasRange: _range != null && _rangeError == null),
          const SizedBox(height: 20),
          Text('Alasan', style: text.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _reason,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Jelaskan alasan singkat (minimal 5 karakter)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text('Lampiran (opsional)', style: text.titleSmall),
          const SizedBox(height: 4),
          Text(
              _type == 'sick'
                  ? 'Surat dokter membantu persetujuan. Foto JPG/PNG atau PDF, maks. 5 MB.'
                  : 'Foto JPG/PNG atau PDF, maks. 5 MB.',
              style: text.bodySmall),
          const SizedBox(height: 8),
          if (_attachment == null)
            OutlinedButton.icon(
              onPressed: _pickAttachment,
              icon: const Icon(Icons.attach_file),
              label: const Text('Tambah lampiran'),
            )
          else
            Surface(
              child: ListTile(
                leading: Icon(
                    _attachment!.name.toLowerCase().endsWith('.pdf')
                        ? Icons.picture_as_pdf_outlined
                        : Icons.image_outlined,
                    color: scheme.primary),
                title: Text(_attachment!.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(_size(_attachment!.size)),
                trailing: IconButton(
                  tooltip: 'Hapus lampiran',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _attachment = null;
                    _attachmentError = null;
                  }),
                ),
              ),
            ),
          if (_attachmentError != null)
            Text(_attachmentError!,
                style: TextStyle(color: scheme.error, fontSize: 12)),
          if (_submitError != null) ...[
            const SizedBox(height: 12),
            Text(_submitError!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _valid && !_submitting ? _submit : null,
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Kirim pengajuan'),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.loading,
    required this.preview,
    required this.error,
    required this.hasRange,
  });

  final bool loading;
  final LeavePreview? preview;
  final String? error;
  final bool hasRange;

  @override
  Widget build(BuildContext context) {
    if (!hasRange) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final p = preview;

    Widget body;
    if (loading) {
      body = const Row(children: [
        SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 10),
        Text('Menghitung jam terdampak…'),
      ]);
    } else if (error != null) {
      body = Text(error!, style: TextStyle(color: scheme.error));
    } else if (p == null) {
      return const SizedBox.shrink();
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.overlapsExisting)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                  'Tanggal ini bertumpuk dengan pengajuan lain yang masih menunggu atau sudah disetujui.',
                  style: TextStyle(
                      color: scheme.error, fontWeight: FontWeight.w700)),
            ),
          Text(
              p.lessonCount == 0
                  ? 'Tidak ada jam mengajar pada tanggal ini.'
                  : '${p.lessonCount} jam pelajaran terdampak',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          if (p.lessonCount > 0) LeaveDaysList(days: p.days),
          const SizedBox(height: 8),
          Text('Perlu persetujuan: ${p.approvalsNeeded.join(' dan ')}',
              style: text.bodySmall),
        ],
      );
    }
    return Surface(
      child: Padding(padding: const EdgeInsets.all(14), child: body),
    );
  }
}
