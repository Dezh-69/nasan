import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service that checks GitHub Releases for new APK versions
/// and prompts the user to download and install updates.
///
/// Setup:
/// 1. Create a GitHub repository (public or private).
/// 2. When you build a new APK, create a GitHub Release with:
///    - Tag name matching the version (e.g., "1.0.1+2")
///    - Upload the APK as a release asset.
/// 3. Update [_repoOwner] and [_repoName] below.
class UpdateService {
  // ─── CONFIGURE THESE ───
  static const String _repoOwner = 'Dezh-69';
  static const String _repoName = 'nasan';
  // ────────────────────────

  /// Set to true once per app session to avoid showing the update dialog multiple times.
  static bool updateCheckedThisSession = false;

  static const String _apiUrl =
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';

  /// Check for updates and show a dialog if a new version is available.
  /// Call this from your app's initState or on a button press.
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g., "1.0.0"
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final latestTag = (data['tag_name'] as String?) ?? '';
      final releaseNotes = (data['body'] as String?) ?? 'Bug fixes and improvements.';

      // Parse version and build from tag (e.g., "1.0.1+2" or "v1.0.1")
      final cleanTag = latestTag.replaceFirst(RegExp(r'^v'), '');
      final parts = cleanTag.split('+');
      final latestVersion = parts[0];
      final latestBuild = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

      if (!_isNewerVersion(currentVersion, currentBuild, latestVersion, latestBuild)) {
        return; // Already up to date
      }

      // Find APK download URL from release assets
      String? apkUrl;
      final assets = data['assets'] as List<dynamic>?;
      if (assets != null) {
        for (final asset in assets) {
          final name = (asset['name'] as String?) ?? '';
          if (name.endsWith('.apk')) {
            apkUrl = asset['browser_download_url'] as String?;
            break;
          }
        }
      }

      if (apkUrl == null) return; // No APK attached to this release

      if (!context.mounted) return;

      // Show update dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Update Available'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A new version ($latestVersion) is available!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('What\'s new:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                releaseNotes,
                style: const TextStyle(fontSize: 13, height: 1.4),
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _downloadAndInstall(apkUrl!);
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  /// Compare version strings (semver) and build numbers
  static bool _isNewerVersion(
      String currentVersion, int currentBuild, String latestVersion, int latestBuild) {
    final currentParts = currentVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final latestParts = latestVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Pad to 3 segments
    while (currentParts.length < 3) {
      currentParts.add(0);
    }
    while (latestParts.length < 3) {
      latestParts.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }

    // Same version, check build number
    return latestBuild > currentBuild;
  }

  /// Open the APK download URL in the browser, which triggers Android's install flow
  static Future<void> _downloadAndInstall(String apkUrl) async {
    final uri = Uri.parse(apkUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
