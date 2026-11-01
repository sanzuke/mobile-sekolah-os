import 'package:flutter/material.dart';

import '../models/facility_models.dart';
import '../services/api_client.dart';
import '../services/teacher_service.dart';
import '../widgets/confirm_dialog.dart';

/// Opens the report form (new, or an [existing] one nobody has taken up yet).
/// Returns the saved report, or null when the teacher backed out.
Future<FacilityReport?> openFacilityForm(
  BuildContext context,
  TeacherService service,
  VoidCallback onUnauthorized, {
  FacilityReport? existing,
}) => Navigator.of(context).push<FacilityReport>(
  MaterialPageRoute(
    builder: (_) => FacilityFormScreen(
      service: service,
      onUnauthorized: onUnauthorized,
      existing: existing,
    ),
  ),
);

/// File a facility report: what kind of problem, how urgent, where, and what.
class FacilityFormScreen extends StatefulWidget {
  const FacilityFormScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
    this.existing,
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;
  final FacilityReport? existing;

  @override
  State<FacilityFormScreen> createState() => _FacilityFormScreenState();
}

class _FacilityFormScreenState extends State<FacilityFormScreen> {
  static const _minDescription = 10;

  final _location = TextEditingController();
  final _description = TextEditingController();

  String _category = 'bangunan';
  String _priority = 'sedang';

  bool _busy = false;
  bool _dirty = false;
  String? _error;
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    if (r != null) {
      _category = r.category;
      _priority = r.priority;
      _location.text = r.location;
      _description.text = r.description ?? '';
    }
    for (final c in [_location, _description]) {
      c.addListener(_markDirty);
    }
  }

  // PopScope reads `_dirty` at build time, so the first edit must rebuild.
  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  void _touch(VoidCallback change) => setState(() {
    _dirty = true;
    change();
  });

  Map<String, String> _validate() {
    final errors = <String, String>{};
    if (_location.text.trim().length < 2) {
      errors['location'] = 'Tuliskan lokasi, mis. Kelas 8A.';
    }
    if (_description.text.trim().length < _minDescription) {
      errors['description'] =
          'Jelaskan masalahnya minimal $_minDescription karakter.';
    }
    return errors;
  }

  Future<void> _submit() async {
    final errors = _validate();
    setState(() {
      _fieldErrors = errors;
      _error = null;
    });
    if (errors.isNotEmpty) return;

    final ok = await confirmDialog(
      context,
      title: widget.existing == null ? 'Kirim laporan?' : 'Simpan perubahan?',
      message: _priority == 'mendesak'
          ? 'Laporan mendesak akan diteruskan ke petugas sarpras dan kepala sekolah.'
          : 'Laporan akan diteruskan ke petugas sarpras.',
      action: widget.existing == null ? 'Kirim' : 'Simpan',
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final saved = await widget.service.saveFacilityReport({
        'category': _category,
        'priority': _priority,
        'location': _location.text.trim(),
        'description': _description.text.trim(),
      }, id: widget.existing?.id);
      if (!mounted) return;
      _dirty = false;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              widget.existing == null
                  ? 'Laporan terkirim.'
                  : 'Laporan diperbarui.',
            ),
          ),
        );
      Navigator.of(context).pop(saved);
      return;
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      _error = e.message;
      _fieldErrors = {
        for (final entry in (e.details ?? const <String, dynamic>{}).entries)
          entry.key:
              '${entry.value is List && (entry.value as List).isNotEmpty ? (entry.value as List).first : entry.value}',
      };
    } catch (_) {
      _error = 'Tidak dapat terhubung ke server.';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final leave = await confirmDialog(
          context,
          title: 'Keluar tanpa menyimpan?',
          message: 'Perubahan yang belum dikirim akan hilang.',
          action: 'Keluar',
          cancel: 'Lanjut menulis',
          destructive: true,
        );
        if (leave == true) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existing == null ? 'Lapor sarpras' : 'Ubah laporan',
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.existing == null
                          ? 'Kirim laporan'
                          : 'Simpan perubahan',
                    ),
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'Jenis masalah',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (value, label) in facilityCategories)
                  ChoiceChip(
                    label: Text(label),
                    selected: _category == value,
                    onSelected: (_) => _touch(() => _category = value),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Prioritas',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final (value, label) in facilityPriorities)
                  ChoiceChip(
                    label: Text(label),
                    selected: _priority == value,
                    onSelected: (_) => _touch(() => _priority = value),
                  ),
              ],
            ),
            if (_priority == 'mendesak') ...[
              const SizedBox(height: 8),
              const Text(
                'Mendesak juga diberitahukan ke kepala sekolah.',
                style: TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _location,
              maxLength: 150,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Lokasi',
                hintText: 'Mis. Kelas 8A, Lab Komputer, Toilet lantai 2',
                border: const OutlineInputBorder(),
                errorText: _fieldErrors['location'],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              minLines: 4,
              maxLines: 10,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Apa masalahnya',
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
                errorText: _fieldErrors['description'],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
