import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

class AvailableUpdate {
  const AvailableUpdate({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
  });

  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
}

class GithubReleaseUpdater {
  static const String _owner = 'JPerrut';
  static const String _repo = 'ShauMsi';
  static const String _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  Future<AvailableUpdate?> checkForUpdates() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = _VersionNumber.tryParse(packageInfo.version);
    if (currentVersion == null) return null;

    final release = await _fetchLatestRelease();
    if (release == null) return null;

    final latestVersion = _VersionNumber.tryParse(release.versionTag);
    if (latestVersion == null) return null;
    if (!latestVersion.isGreaterThan(currentVersion)) return null;

    return AvailableUpdate(
      currentVersion: currentVersion.raw,
      latestVersion: latestVersion.raw,
      downloadUrl: release.apkUrl,
      releaseNotes: release.body,
    );
  }

  Future<_GithubRelease?> _fetchLatestRelease() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(_apiUrl));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'shaumsi-updater');

      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        return null;
      }

      final payload = await response.transform(utf8.decoder).join();
      final data = jsonDecode(payload);
      if (data is! Map<String, dynamic>) {
        return null;
      }

      final tagName = (data['tag_name'] as String?) ?? '';
      final body = (data['body'] as String?) ?? '';
      final assets = (data['assets'] as List?) ?? const [];
      final apkAsset = assets.cast<Map<String, dynamic>?>().firstWhere((asset) {
        final name = ((asset?['name'] as String?) ?? '').toLowerCase();
        return name.endsWith('.apk');
      }, orElse: () => null);

      final apkUrl = apkAsset?['browser_download_url'] as String?;
      if (apkUrl == null || apkUrl.isEmpty) {
        return null;
      }

      return _GithubRelease(versionTag: tagName, apkUrl: apkUrl, body: body);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

class _GithubRelease {
  const _GithubRelease({
    required this.versionTag,
    required this.apkUrl,
    required this.body,
  });

  final String versionTag;
  final String apkUrl;
  final String body;
}

class _VersionNumber {
  const _VersionNumber({
    required this.raw,
    required this.major,
    required this.minor,
    required this.patch,
  });

  final String raw;
  final int major;
  final int minor;
  final int patch;

  static _VersionNumber? tryParse(String source) {
    final normalized = source.trim().toLowerCase().replaceFirst('v', '');
    final clean = normalized.split('+').first;
    final chunks = clean.split('.');
    if (chunks.length < 3) return null;

    final major = int.tryParse(chunks[0]);
    final minor = int.tryParse(chunks[1]);
    final patch = int.tryParse(chunks[2]);
    if (major == null || minor == null || patch == null) return null;

    return _VersionNumber(
      raw: '$major.$minor.$patch',
      major: major,
      minor: minor,
      patch: patch,
    );
  }

  bool isGreaterThan(_VersionNumber other) {
    if (major != other.major) return major > other.major;
    if (minor != other.minor) return minor > other.minor;
    return patch > other.patch;
  }
}
