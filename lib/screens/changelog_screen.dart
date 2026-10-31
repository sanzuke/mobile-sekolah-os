import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/update_service.dart';
import '../widgets/surface_cards.dart';

/// "Log perubahan": installed version, whether a newer release exists, its
/// release notes, and a button that downloads and installs it.
class ChangelogScreen extends StatefulWidget {
  const ChangelogScreen({super.key, required this.updater});

  final AppUpdater updater;

  @override
  State<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends State<ChangelogScreen> {
  InstalledVersion? _installed;
  UpdateInfo? _info;
  String? _error;
  bool _checking = true;

  double? _progress; // non-null while downloading
  String? _installError;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
      _installError = null;
    });
    try {
      final installed = await widget.updater.installedVersion();
      final info = await widget.updater.check();
      if (!mounted) return;
      setState(() {
        _installed = installed;
        _info = info;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Tidak dapat memeriksa pembaruan. Periksa koneksi Anda.');
      }
    }
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _install() async {
    final info = _info;
    if (info == null || _progress != null) return;
    setState(() {
      _progress = 0;
      _installError = null;
    });
    try {
      await widget.updater.downloadAndInstall(
        info,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _installError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _installError = 'Gagal mengunduh atau memasang pembaruan.');
      }
    }
    if (mounted) setState(() => _progress = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log perubahan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 64),
        children: [
          _VersionCard(installed: _installed),
          const SizedBox(height: 4),
          if (_checking)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            EmptyState(
              icon: Icons.cloud_off,
              title: 'Gagal memeriksa pembaruan',
              message: _error!,
              actionLabel: 'Coba lagi',
              onAction: _check,
            )
          else
            _result(context),
        ],
      ),
    );
  }

  Widget _result(BuildContext context) {
    final info = _info!;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (!info.hasRelease) {
      return const EmptyState(
        icon: Icons.history,
        title: 'Belum ada catatan rilis',
        message: 'Catatan perubahan akan muncul di sini setelah ada rilis.',
      );
    }

    if (!info.updateAvailable) {
      return Column(
        children: [
          const EmptyState(
            icon: Icons.check_circle_outline,
            title: 'Aplikasi sudah versi terbaru',
            message: 'Tidak ada pembaruan yang perlu dipasang.',
          ),
          TextButton(onPressed: _check, child: const Text('Cek lagi')),
        ],
      );
    }

    return Surface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.system_update, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Pembaruan tersedia',
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Versi ${info.latestVersionName} (build ${info.latestVersionCode})',
                style: text.bodyMedium),
            if (info.isMandatory) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                    'Pembaruan wajib. Versi lama tidak lagi didukung.',
                    style: TextStyle(
                        color: Color(0xFFB91C1C), fontWeight: FontWeight.w700)),
              ),
            ],
            if (info.releaseNotes != null && info.releaseNotes!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Yang baru', style: text.titleSmall),
              const SizedBox(height: 4),
              SelectableText(info.releaseNotes!, style: text.bodyMedium),
            ],
            const SizedBox(height: 16),
            if (_progress != null) ...[
              LinearProgressIndicator(value: _progress == 0 ? null : _progress),
              const SizedBox(height: 6),
              Text('Mengunduh… ${((_progress ?? 0) * 100).round()}%',
                  style: text.bodySmall),
            ] else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _install,
                  icon: const Icon(Icons.download),
                  label: const Text('Unduh & pasang'),
                ),
              ),
            if (_installError != null) ...[
              const SizedBox(height: 8),
              Text(_installError!,
                  style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  const _VersionCard({required this.installed});

  final InstalledVersion? installed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Surface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.school, color: scheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Asatidz PPI 50',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(
                    installed == null
                        ? 'Memeriksa versi…'
                        : 'Versi ${installed!.name} (build ${installed!.code})',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
