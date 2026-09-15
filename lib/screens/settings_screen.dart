import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/family_service.dart';
import '../theme.dart';

/// The key used in SharedPreferences to store the selected ringtone.
/// This same key is read by the native Android RingService.
const String _kRingtoneTypeKey = 'ringtone_type';
const String _kRingtonePathKey = 'ringtone_path';
const String _kRingtoneDisplayNameKey = 'ringtone_display_name';

/// Ringtone types
const String kRingtoneDefault = 'default';
const String kRingtoneSystem1 = 'system_alarm_1';
const String kRingtoneSystem2 = 'system_alarm_2';
const String kRingtoneSystem3 = 'system_alarm_3';
const String kRingtoneCustom = 'custom';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _selectedType = kRingtoneDefault;
  String? _customFilePath;
  String? _customDisplayName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedType = prefs.getString(_kRingtoneTypeKey) ?? kRingtoneDefault;
      _customFilePath = prefs.getString(_kRingtonePathKey);
      _customDisplayName = prefs.getString(_kRingtoneDisplayNameKey);
      _isLoading = false;
    });
  }

  Future<void> _saveSelection(String type, {String? path, String? displayName}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRingtoneTypeKey, type);
    if (path != null) {
      await prefs.setString(_kRingtonePathKey, path);
    }
    if (displayName != null) {
      await prefs.setString(_kRingtoneDisplayNameKey, displayName);
    }
    setState(() {
      _selectedType = type;
      if (path != null) _customFilePath = path;
      if (displayName != null) _customDisplayName = displayName;
    });
  }

  Future<void> _importCustomAudio() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
      );

      if (result.isEmpty) return;

      final file = result.first;
      if (file.path == null) return;

      // Copy the file to app's documents directory so it persists
      final appDir = await getApplicationDocumentsDirectory();
      final ringtoneDir = Directory('${appDir.path}/ringtones');
      if (!await ringtoneDir.exists()) {
        await ringtoneDir.create(recursive: true);
      }

      final fileName = file.name;
      final destPath = '${ringtoneDir.path}/$fileName';
      await File(file.path!).copy(destPath);

      await _saveSelection(kRingtoneCustom, path: destPath, displayName: fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ringtone set to: $fileName'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import audio: $e'),
            backgroundColor: AppTheme.primaryRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _editPhoneNumber(BuildContext context, String currentNumber) async {
    final controller = TextEditingController(text: currentNumber);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Edit Phone Number'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Phone Number',
              prefixIcon: Icon(Icons.phone_rounded, color: AppTheme.textSecondary),
            ),
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: AppTheme.textPrimary),
            validator: (value) => value == null || value.isEmpty ? 'Cannot be empty' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result != currentNumber) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'phoneNumber': result,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Profile Section
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'PROFILE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final userAsync = ref.watch(userProvider);
                      return userAsync.when(
                        data: (userData) {
                          final phoneNumber = userData?['phoneNumber'] as String? ?? 'Not set';
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceDark,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.phone_rounded, color: AppTheme.textSecondary, size: 20),
                            ),
                            title: const Text('Phone Number', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                            subtitle: Text(phoneNumber, style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7), fontSize: 12)),
                            trailing: const Icon(Icons.edit_rounded, color: AppTheme.textSecondary, size: 20),
                            onTap: () => _editPhoneNumber(context, userData?['phoneNumber'] ?? ''),
                          );
                        },
                        loading: () => const ListTile(title: Text('Loading...')),
                        error: (_, __) => const ListTile(title: Text('Error loading profile')),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Section header
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'RINGTONE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),

                // Ringtone options container
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildRingtoneOption(
                        title: 'Default System Alarm',
                        subtitle: 'The standard alarm sound',
                        icon: Icons.alarm_rounded,
                        type: kRingtoneDefault,
                        isFirst: true,
                      ),
                      _divider(),
                      _buildRingtoneOption(
                        title: 'System Alarm 2',
                        subtitle: 'Alternative alarm tone',
                        icon: Icons.notifications_active_rounded,
                        type: kRingtoneSystem1,
                      ),
                      _divider(),
                      _buildRingtoneOption(
                        title: 'System Ringtone',
                        subtitle: 'Default phone ringtone',
                        icon: Icons.phone_in_talk_rounded,
                        type: kRingtoneSystem2,
                      ),
                      _divider(),
                      _buildRingtoneOption(
                        title: 'System Notification',
                        subtitle: 'Default notification sound',
                        icon: Icons.notifications_rounded,
                        type: kRingtoneSystem3,
                        isLast: _selectedType != kRingtoneCustom && _customFilePath == null,
                      ),
                      if (_selectedType == kRingtoneCustom && _customDisplayName != null) ...[
                        _divider(),
                        _buildRingtoneOption(
                          title: _customDisplayName!,
                          subtitle: 'Imported audio file',
                          icon: Icons.music_note_rounded,
                          type: kRingtoneCustom,
                          isLast: true,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Import button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _importCustomAudio,
                    icon: const Icon(Icons.file_upload_rounded),
                    label: const Text('Import Custom Audio'),
                  ),
                ),

                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Supported formats: MP3, WAV, OGG, M4A',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRingtoneOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required String type,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final isSelected = _selectedType == type;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _saveSelection(type),
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(16) : Radius.zero,
          bottom: isLast ? const Radius.circular(16) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryRed.withValues(alpha: 0.15)
                      : AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? AppTheme.primaryRed : AppTheme.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryRed,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        color: AppTheme.surfaceDark.withValues(alpha: 0.5),
      ),
    );
  }
}
