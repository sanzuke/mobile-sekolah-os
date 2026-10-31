import 'dart:async';

import 'package:mobile_sekolah_os/services/update_service.dart';

/// A scriptable [AppUpdater] for widget tests (no network, no installer).
class FakeUpdater implements AppUpdater {
  FakeUpdater({
    this.installed = const InstalledVersion(name: '1.0.0', code: 1),
    this.info = const UpdateInfo(
        updateAvailable: false, isMandatory: false, latestVersionCode: 1),
    this.error,
  });

  InstalledVersion installed;
  UpdateInfo info;
  Object? error;
  Object? installError;

  int checks = 0;
  final installs = <UpdateInfo>[];

  /// When set, [downloadAndInstall] waits for it (so a test can look at the progress UI).
  Completer<void>? holdDownload;

  @override
  Future<InstalledVersion> installedVersion() async => installed;

  @override
  Future<UpdateInfo> check() async {
    checks++;
    if (error != null) throw error!;
    return info;
  }

  @override
  Future<void> downloadAndInstall(
    UpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    installs.add(info);
    onProgress?.call(0.4);
    if (holdDownload != null) await holdDownload!.future;
    if (installError != null) throw installError!;
    onProgress?.call(1);
  }
}
