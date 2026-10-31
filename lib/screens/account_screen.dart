import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/update_service.dart';
import '../state/session_controller.dart';
import '../widgets/date_format.dart';
import '../widgets/surface_cards.dart';
import 'changelog_screen.dart';

/// "Akun" as in the design: profile card, a list of settings rows, and Keluar.
/// The settings rows have no backend yet and say so; Keluar asks first.
class AccountScreen extends StatelessWidget {
  const AccountScreen({
    super.key,
    required this.teacher,
    required this.academicYear,
    required this.onLogout,
    required this.updater,
    this.session,
    this.now,
  });

  /// Source of the "Login biometrik" setting; the row is hidden when null or when
  /// the device has no biometrics enrolled.
  final SessionController? session;

  final AuthenticatedTeacher teacher;

  /// Academic year of the active semester, once Beranda has loaded it.
  final ValueListenable<String?> academicYear;
  final Future<void> Function() onLogout;

  /// Checks for and installs newer SekolahOS Guru releases (Log perubahan).
  final AppUpdater updater;

  /// Injectable clock for tests; defaults to the device clock.
  final DateTime? now;

  String get _role => teacher.isHomeroom ? 'Wali Kelas' : 'Guru Mapel';

  void _soon(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label akan segera hadir')));
  }

  Future<void> _toggleBiometric(BuildContext context, bool on) async {
    final session = this.session!;
    final messenger = ScaffoldMessenger.of(context);
    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

    if (!on) {
      await session.disableBiometric();
      say('Login biometrik dimatikan');
      return;
    }
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordDialog(),
    );
    if (password == null || password.isEmpty) return;
    final error = await session.enableBiometric(password);
    say(error ?? 'Login biometrik diaktifkan');
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text(
            'Sesi di perangkat ini akan diakhiri. Anda perlu masuk lagi untuk memakai aplikasi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB91C1C)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Keluar')),
        ],
      ),
    );
    if (ok == true) await onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final n = now ?? DateTime.now();
    final month = formatMonth('${n.year}-${n.month.toString().padLeft(2, '0')}');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 64),
      children: [
        Text('Akun',
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Surface(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _Avatar(teacher: teacher),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(teacher.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        [_role, ?teacher.nip].join(' · '),
                        style: text.bodyMedium,
                      ),
                      ValueListenableBuilder<String?>(
                        valueListenable: academicYear,
                        builder: (_, year, _) => year == null
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text('TA $year · Periode $month',
                                    style: text.bodySmall),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Surface(
          child: Column(
            children: [
              _Row(
                icon: Icons.settings_outlined,
                label: 'Pengaturan profil',
                sub: 'Data diri, foto, kata sandi',
                onTap: () => _soon(context, 'Pengaturan profil'),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _Row(
                icon: Icons.work_outline,
                label: 'Data kepegawaian',
                sub: 'Data & dokumen pegawai',
                onTap: () => _soon(context, 'Data kepegawaian'),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _Row(
                icon: Icons.swap_horiz,
                label: 'Ganti mode workspace',
                sub: 'Saat ini: $_role',
                onTap: () => _soon(context, 'Ganti mode workspace'),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              if (session != null)
                ListenableBuilder(
                  listenable: session!,
                  builder: (context, _) {
                    if (!session!.biometricAvailable) {
                      return const SizedBox.shrink();
                    }
                    return Column(children: [
                      _Row(
                        icon: Icons.fingerprint,
                        label: 'Login biometrik',
                        sub: 'Masuk dengan sidik jari atau wajah',
                        trailing: Switch(
                          value: session!.biometricEnabled,
                          onChanged: (v) => _toggleBiometric(context, v),
                        ),
                        onTap: () => _toggleBiometric(
                            context, !session!.biometricEnabled),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    ]);
                  },
                ),
              _Row(
                icon: Icons.history,
                label: 'Log perubahan',
                sub: 'Versi aplikasi & pembaruan',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChangelogScreen(updater: updater))),
              ),
            ],
          ),
        ),
        Surface(
          child: _Row(
            icon: Icons.logout,
            label: 'Keluar',
            sub: 'Akhiri sesi di perangkat ini',
            danger: true,
            onTap: () => _confirmLogout(context),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.teacher});

  final AuthenticatedTeacher teacher;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initials = Container(
      color: scheme.primary,
      alignment: Alignment.center,
      child: Text(teacher.initials,
          style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
    );
    return ClipOval(
      child: SizedBox(
        width: 60,
        height: 60,
        child: teacher.photoUrl == null
            ? initials
            : Image.network(teacher.photoUrl!,
                fit: BoxFit.cover, errorBuilder: (_, _, _) => initials),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
    this.danger = false,
    this.trailing,
  });

  final Widget? trailing;
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFB91C1C);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: danger ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: danger ? red : const Color(0xFF0F172A)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: danger ? red : null)),
                  Text(sub, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (!danger)
              const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }
}

/// Asks for the password once; it is checked against the server before the
/// biometric login is switched on.
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Aktifkan login biometrik'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              'Masukkan kata sandi akun Anda. Kata sandi disimpan terenkripsi di perangkat ini dan hanya dipakai setelah biometrik berhasil.'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            onSubmitted: (v) => Navigator.pop(context, v),
            decoration: const InputDecoration(
                labelText: 'Kata sandi', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            child: const Text('Lanjut')),
      ],
    );
  }
}
