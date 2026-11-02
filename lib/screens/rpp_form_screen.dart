import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../models/rpp_models.dart';
import '../services/api_client.dart';
import '../services/attachment_picker.dart';
import '../services/teacher_service.dart';
import '../widgets/date_format.dart';
import '../widgets/rpp_widgets.dart';
import '../widgets/surface_cards.dart';

String _size(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB'
    : '${(bytes / 1024).ceil()} KB';

/// Upload the RPP of one week, or replace it (until it is approved). Pops `true` when
/// something was sent, so the list reloads.
class RppFormScreen extends StatefulWidget {
  const RppFormScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
    required this.week,
    required this.maxBytes,
    this.picker = const RppFilePicker(),
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;
  final RppWeek week;
  final int maxBytes;
  final AttachmentPicker picker;

  @override
  State<RppFormScreen> createState() => _RppFormScreenState();
}

class _RppFormScreenState extends State<RppFormScreen> {
  late final TextEditingController _title = TextEditingController(
    text: widget.week.title ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.week.description ?? '',
  );
  PickedAttachment? _file;
  String? _fileError;
  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _valid =>
      _title.text.trim().length >= 3 && _file != null && _fileError == null;

  Future<void> _pick() async {
    final file = await widget.picker.pick();
    if (file == null) return;
    final ext = file.name.toLowerCase().split('.').last;
    setState(() {
      _file = file;
      _fileError = !const {'pdf', 'doc', 'docx'}.contains(ext)
          ? 'Berkas harus berformat PDF, DOC, atau DOCX.'
          : file.size > widget.maxBytes
          ? 'Ukuran berkas maksimal ${widget.maxBytes ~/ (1024 * 1024)} MB (berkas ini ${_size(file.size)}).'
          : null;
      if (_title.text.trim().isEmpty) {
        _title.text = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      }
    });
  }

  Future<void> _submit() async {
    if (!_valid || _submitting) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await widget.service.submitRpp(
        weekStart: widget.week.weekStart,
        title: _title.text.trim(),
        description: _description.text.trim(),
        fileName: _file!.name,
        fileBytes: _file!.bytes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('RPP terkirim dan menunggu review kepala sekolah.'),
            ),
          );
        Navigator.of(context).pop(true);
      }
      return;
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      _submitError = e.details?['file'] is List
          ? (e.details!['file'] as List).first.toString()
          : e.message;
    } catch (_) {
      _submitError = 'Tidak dapat terhubung ke server.';
    }
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _openCurrent() async {
    final w = widget.week;
    final messenger = ScaffoldMessenger.of(context);
    void say(String m) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
    try {
      final bytes = await widget.service.rppFile(w.id!);
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/rpp-${w.weekStart}.${w.fileExtension ?? 'pdf'}',
      );
      await file.writeAsBytes(bytes, flush: true);
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        say('Tidak ada aplikasi untuk membuka berkas ini.');
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      say(e.message);
    } catch (_) {
      say('Berkas tidak dapat dibuka.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.week;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final canEdit = w.canSubmit;
    return Scaffold(
      appBar: AppBar(title: const Text('RPP pekan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatRange(w.weekStart, w.weekEnd),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              RppStatusChip(state: w.state, overdue: w.overdue),
            ],
          ),
          const SizedBox(height: 4),
          Text('Batas unggah ${formatDate(w.due)}', style: text.bodySmall),
          if (w.state == 'rejected' && (w.reviewNotes ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Surface(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Ditolak: ${w.reviewNotes}',
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                ),
              ),
            ),
          ],
          if (w.hasFile) ...[
            const SizedBox(height: 12),
            Surface(
              child: ListTile(
                leading: Icon(
                  Icons.description_outlined,
                  color: scheme.primary,
                ),
                title: Text(
                  w.title ?? 'RPP',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Berkas terunggah (${(w.fileExtension ?? '').toUpperCase()})',
                ),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: _openCurrent,
              ),
            ),
          ],
          if (!canEdit) ...[
            const SizedBox(height: 12),
            Text(
              w.state == 'approved'
                  ? 'RPP ini sudah disetujui dan tidak bisa diganti.'
                  : 'Pekan ini di luar jendela unggah (pekan lalu, ini, dan depan).',
              style: text.bodyMedium,
            ),
          ] else ...[
            const SizedBox(height: 20),
            Text('Judul', style: text.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _title,
              maxLength: 255,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Mis. RPP Fiqih pekan 2',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text('Keterangan (opsional)', style: text.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 5,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Text('Berkas', style: text.titleSmall),
            const SizedBox(height: 4),
            Text(
              'PDF, DOC, atau DOCX, maks. ${widget.maxBytes ~/ (1024 * 1024)} MB.'
              '${w.hasFile ? ' Berkas baru menggantikan yang lama.' : ''}',
              style: text.bodySmall,
            ),
            const SizedBox(height: 8),
            if (_file == null)
              OutlinedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.attach_file),
                label: Text(
                  w.hasFile ? 'Pilih berkas pengganti' : 'Pilih berkas',
                ),
              )
            else
              Surface(
                child: ListTile(
                  leading: Icon(
                    _file!.name.toLowerCase().endsWith('.pdf')
                        ? Icons.picture_as_pdf_outlined
                        : Icons.description_outlined,
                    color: scheme.primary,
                  ),
                  title: Text(
                    _file!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(_size(_file!.size)),
                  trailing: IconButton(
                    tooltip: 'Hapus pilihan',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _file = null;
                      _fileError = null;
                    }),
                  ),
                ),
              ),
            if (_fileError != null)
              Text(
                _fileError!,
                style: TextStyle(color: scheme.error, fontSize: 12),
              ),
            if (_submitError != null) ...[
              const SizedBox(height: 12),
              Text(_submitError!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _valid && !_submitting ? _submit : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(w.hasFile ? 'Kirim ulang' : 'Kirim RPP'),
            ),
          ],
        ],
      ),
    );
  }
}
