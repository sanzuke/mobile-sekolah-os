import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/vehicle_models.dart';
import '../services/api_client.dart';
import '../services/teacher_service.dart';
import '../widgets/confirm_dialog.dart';

/// Opens the request form (new, or an [existing] one nobody has decided yet).
/// Returns the saved request, or null when the teacher backed out.
Future<VehicleRequest?> openVehicleForm(
  BuildContext context,
  TeacherService service,
  VoidCallback onUnauthorized, {
  VehicleRequest? existing,
}) => Navigator.of(context).push<VehicleRequest>(
  MaterialPageRoute(
    builder: (_) => VehicleFormScreen(
      service: service,
      onUnauthorized: onUnauthorized,
      existing: existing,
    ),
  ),
);

/// Ask to borrow a school vehicle: what for, where, when, how many people. Shows
/// which vehicles are free in that time as a guide; the manager picks the vehicle.
class VehicleFormScreen extends StatefulWidget {
  const VehicleFormScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
    this.existing,
    this.now,
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;
  final VehicleRequest? existing;

  /// Overridable clock for tests.
  final DateTime? now;

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  // The server's limits; checked here too so the teacher is told before sending.
  static const _maxDaysAhead = 60;
  static const _maxDurationDays = 7;

  final _purpose = TextEditingController();
  final _destination = TextEditingController();
  final _passengers = TextEditingController(text: '1');

  late DateTime _start;
  late DateTime _end;

  List<VehicleOption>? _vehicles;
  bool _vehiclesLoading = false;
  String? _vehiclesError;
  int _vehiclesToken =
      0; // a slow answer for old dates must not overwrite a newer one

  bool _busy = false;
  bool _dirty = false;
  String? _error;
  Map<String, String> _fieldErrors = {};

  DateTime get _now => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final tomorrow = _now.add(const Duration(days: 1));
    _start = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 7);
    _end = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 15);
    final r = widget.existing;
    if (r != null) {
      _start = _parse(r.startAt) ?? _start;
      _end = _parse(r.endAt) ?? _end;
      _purpose.text = r.purpose;
      _destination.text = r.destination;
      _passengers.text = '${r.passengerCount}';
    }
    for (final c in [_purpose, _destination, _passengers]) {
      c.addListener(_markDirty);
    }
    _loadVehicles();
  }

  DateTime? _parse(String api) => DateTime.tryParse(api.replaceFirst(' ', 'T'));

  // PopScope reads `_dirty` at build time, so the first edit must rebuild.
  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final c in [_purpose, _destination, _passengers]) {
      c.dispose();
    }
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _api(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

  String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';

  String _time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  bool get _rangeValid => _end.isAfter(_start);

  /// Which vehicles are free in the chosen time. Only a guide: nothing is reserved.
  Future<void> _loadVehicles() async {
    if (!_rangeValid) {
      setState(() => _vehicles = null);
      return;
    }
    final token = ++_vehiclesToken;
    setState(() {
      _vehiclesLoading = true;
      _vehiclesError = null;
    });
    try {
      final res = await widget.service.vehicleAvailability(
        _api(_start),
        _api(_end),
      );
      if (token != _vehiclesToken || !mounted) return;
      _vehicles = res;
    } on ApiException catch (e) {
      if (token != _vehiclesToken) return;
      if (e.isUnauthorized) widget.onUnauthorized();
      _vehiclesError = e.message;
    } catch (_) {
      if (token != _vehiclesToken) return;
      _vehiclesError = 'Ketersediaan tidak dapat dimuat.';
    }
    if (mounted && token == _vehiclesToken) {
      setState(() => _vehiclesLoading = false);
    }
  }

  void _setTimes(DateTime start, DateTime end) {
    setState(() {
      _dirty = true;
      _start = start;
      _end = end;
    });
    _loadVehicles();
  }

  Future<void> _pickDate({required bool start}) async {
    final today = DateTime(_now.year, _now.month, _now.day);
    final current = start ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isBefore(today) ? today : current,
      firstDate: today,
      lastDate: today.add(
        const Duration(days: _maxDaysAhead + _maxDurationDays),
      ),
    );
    if (picked == null) return;
    final d = DateTime(
      picked.year,
      picked.month,
      picked.day,
      current.hour,
      current.minute,
    );
    if (start) {
      // Moving the departure carries the return along by the same amount.
      _setTimes(d, _end.add(d.difference(_start)));
    } else {
      _setTimes(_start, d);
    }
  }

  Future<void> _pickTime({required bool start}) async {
    final current = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return;
    final d = DateTime(
      current.year,
      current.month,
      current.day,
      picked.hour,
      picked.minute,
    );
    if (start) {
      _setTimes(d, _end.add(d.difference(_start)));
    } else {
      _setTimes(_start, d);
    }
  }

  Map<String, String> _validate() {
    final errors = <String, String>{};
    if (_purpose.text.trim().length < 3) {
      errors['purpose'] = 'Tuliskan keperluan peminjaman.';
    }
    if (_destination.text.trim().length < 2) {
      errors['destination'] = 'Tuliskan tujuan perjalanan.';
    }
    if (!_start.isAfter(_now)) {
      errors['start_at'] = 'Waktu berangkat harus di masa depan.';
    } else if (_start.isAfter(_now.add(const Duration(days: _maxDaysAhead)))) {
      errors['start_at'] = 'Paling lambat $_maxDaysAhead hari ke depan.';
    }
    if (!_rangeValid) {
      errors['end_at'] = 'Waktu kembali harus setelah waktu berangkat.';
    } else if (_end.isAfter(
      _start.add(const Duration(days: _maxDurationDays)),
    )) {
      errors['end_at'] = 'Peminjaman maksimal $_maxDurationDays hari.';
    }
    final n = int.tryParse(_passengers.text.trim());
    if (n == null || n < 1) {
      errors['passenger_count'] = 'Isi jumlah penumpang, minimal 1.';
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
      title: widget.existing == null ? 'Kirim pengajuan?' : 'Simpan perubahan?',
      message: 'Pengajuan diteruskan ke pengelola kendaraan, yang menentukan kendaraan dan sopirnya.',
      action: widget.existing == null ? 'Kirim' : 'Simpan',
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final saved = await widget.service.saveVehicleRequest({
        'purpose': _purpose.text.trim(),
        'destination': _destination.text.trim(),
        'start_at': _api(_start),
        'end_at': _api(_end),
        'passenger_count': int.parse(_passengers.text.trim()),
      }, id: widget.existing?.id);
      if (!mounted) return;
      _dirty = false;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              widget.existing == null
                  ? 'Pengajuan terkirim.'
                  : 'Pengajuan diperbarui.',
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
            widget.existing == null ? 'Pinjam kendaraan' : 'Ubah pengajuan',
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
                          ? 'Kirim pengajuan'
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
            TextField(
              controller: _purpose,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Keperluan',
                hintText: 'Mis. Study tour kelas 9',
                border: const OutlineInputBorder(),
                errorText: _fieldErrors['purpose'],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _destination,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Tujuan',
                hintText: 'Mis. Museum Geologi Bandung',
                border: const OutlineInputBorder(),
                errorText: _fieldErrors['destination'],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Berangkat',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _Picker(
                    label: 'Tanggal berangkat',
                    value: _date(_start),
                    icon: Icons.event_outlined,
                    errorText: _fieldErrors['start_at'],
                    onTap: () => _pickDate(start: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Picker(
                    label: 'Jam berangkat',
                    value: _time(_start),
                    icon: Icons.schedule,
                    onTap: () => _pickTime(start: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Kembali',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _Picker(
                    label: 'Tanggal kembali',
                    value: _date(_end),
                    icon: Icons.event_outlined,
                    errorText: _fieldErrors['end_at'],
                    onTap: () => _pickDate(start: false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Picker(
                    label: 'Jam kembali',
                    value: _time(_end),
                    icon: Icons.schedule,
                    onTap: () => _pickTime(start: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passengers,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Jumlah penumpang',
                border: const OutlineInputBorder(),
                errorText: _fieldErrors['passenger_count'],
              ),
            ),
            const SizedBox(height: 16),
            _Availability(
              vehicles: _vehicles,
              loading: _vehiclesLoading,
              error: _vehiclesError,
              rangeValid: _rangeValid,
              passengers: int.tryParse(_passengers.text.trim()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Which vehicles are free in the chosen time. A guide only: the manager decides.
class _Availability extends StatelessWidget {
  const _Availability({
    required this.vehicles,
    required this.loading,
    required this.error,
    required this.rangeValid,
    required this.passengers,
  });

  final List<VehicleOption>? vehicles;
  final bool loading;
  final String? error;
  final bool rangeValid;
  final int? passengers;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final Widget body;
    if (!rangeValid) {
      body = const Text(
        'Atur waktu berangkat dan kembali untuk melihat ketersediaan.',
      );
    } else if (loading && vehicles == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (error != null) {
      body = Text(error!);
    } else if (vehicles == null || vehicles!.isEmpty) {
      body = const Text('Belum ada kendaraan yang terdaftar.');
    } else {
      body = Column(
        children: [
          for (final v in vehicles!)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_car_outlined,
                    size: 20,
                    color: v.available
                        ? const Color(0xFF0F766E)
                        : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${v.plateNumber} · ${v.capacity} orang'
                          '${passengers != null && passengers! > v.capacity ? ' · kapasitas kurang' : ''}',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    v.available ? 'Tersedia' : 'Terpakai',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: v.available
                          ? const Color(0xFF0F766E)
                          : const Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ketersediaan kendaraan',
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Hanya gambaran. Kendaraan dan sopir ditetapkan pengelola saat menyetujui.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 10),
          body,
        ],
      ),
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.errorText,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: Icon(icon),
        errorText: errorText,
        errorMaxLines: 3,
      ),
      child: Text(value),
    ),
  );
}
