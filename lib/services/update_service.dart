import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../config/api_config.dart';
import 'api_client.dart';

/// The `app` channel of `/api/v1/app/version`: SekolahOS Guru releases only
/// (the student CBT app has its own).
const kUpdateChannel = 'teacher';

class InstalledVersion {
  const InstalledVersion({required this.name, required this.code});

  /// `1.0.0` (pubspec `version` before the `+`).
  final String name;

  /// `1` (pubspec build number; what the server compares).
  final int code;
}

class UpdateInfo {
  const UpdateInfo({
    required this.updateAvailable,
    required this.isMandatory,
    required this.latestVersionCode,
    this.latestVersionName,
    this.releaseNotes,
    this.downloadUrl,
  });

  final bool updateAvailable;
  final bool isMandatory;
  final int latestVersionCode;
  final String? latestVersionName;
  final String? releaseNotes;
  final String? downloadUrl;

  /// True when the server has published at least one release for this app.
  bool get hasRelease => latestVersionName != null;

  factory UpdateInfo.fromJson(Map<String, dynamic> j) => UpdateInfo(
        updateAvailable: j['update_available'] as bool? ?? false,
        isMandatory: j['is_mandatory'] as bool? ?? false,
        latestVersionCode: (j['latest_version_code'] as num?)?.toInt() ?? 0,
        latestVersionName: j['latest_version_name'] as String?,
        releaseNotes: j['release_notes'] as String?,
        downloadUrl: j['download_url'] as String?,
      );
}

/// What the "Log perubahan" screen needs. An interface so the screen can be
/// tested without the network, the file system or the Android installer.
abstract class AppUpdater {
  Future<InstalledVersion> installedVersion();

  /// Throws [ApiException] (or any error) when the check cannot be done.
  Future<UpdateInfo> check();

  /// Downloads the APK and opens the system installer.
  Future<void> downloadAndInstall(
    UpdateInfo info, {
    void Function(double progress)? onProgress,
  });
}

class HttpAppUpdater implements AppUpdater {
  HttpAppUpdater({
    required this.client,
    Future<InstalledVersion> Function()? installed,
    http.Client? downloader,
  })  : _installed = installed ?? _fromPlatform,
        _downloader = downloader ?? http.Client();

  final ApiClient client;
  final Future<InstalledVersion> Function() _installed;
  final http.Client _downloader;

  static Future<InstalledVersion> _fromPlatform() async {
    final info = await PackageInfo.fromPlatform();
    return InstalledVersion(
      name: info.version,
      code: int.tryParse(info.buildNumber) ?? 0,
    );
  }

  @override
  Future<InstalledVersion> installedVersion() => _installed();

  @override
  Future<UpdateInfo> check() async {
    final installed = await _installed();
    final data = await client.get('/v1/app/version', query: {
      'app': kUpdateChannel,
      'platform': 'android',
      'current_version_code': '${installed.code}',
    }) as Map<String, dynamic>;
    return UpdateInfo.fromJson(data);
  }

  @override
  Future<void> downloadAndInstall(
    UpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    final url = info.downloadUrl;
    if (url == null) throw ApiException('Tautan unduhan tidak tersedia.');

    final response = await _downloader.send(http.Request('GET', Uri.parse(url)));
    if (response.statusCode != 200) {
      throw ApiException(
          'Gagal mengunduh pembaruan (status ${response.statusCode}).',
          statusCode: response.statusCode);
    }

    final total = response.contentLength ?? 0;
    var received = 0;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sekolahos-guru-update.apk');
    final sink = file.openWrite();
    await response.stream.map((chunk) {
      received += chunk.length;
      if (total > 0) onProgress?.call(received / total);
      return chunk;
    }).pipe(sink);
    await sink.close();

    final result = await OpenFilex.open(file.path,
        type: 'application/vnd.android.package-archive');
    if (result.type != ResultType.done) {
      throw ApiException('Tidak dapat membuka pemasang: ${result.message}');
    }
  }
}

/// Base URL of the API, for screens that show where updates come from.
String get updateApiBase => ApiConfig.baseUrl;
