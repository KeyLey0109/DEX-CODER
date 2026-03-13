import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app_preferences.dart';
import '../../data/repositories/user_settings_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repo = UserSettingsRepository();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  bool _inAppNotifications = true;
  bool _emailNotifications = true;
  String _themeMode = 'system';
  String _languageCode = 'vi';

  String? _userId;
  String? _avatarUrl;
  Uint8List? _pendingAvatarBytes;
  String? _pendingAvatarExtension;

  bool _isMissingColumnError(Object error) {
    return error is PostgrestException && error.code == '42703';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _prefDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    _userId = user.id;
    try {
      Map<String, dynamic>? profile;
      try {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('display_name,email,avatar_url,bio')
            .eq('id', user.id)
            .maybeSingle();
        profile = response;
      } catch (e) {
        if (!_isMissingColumnError(e)) rethrow;
        final response = await Supabase.instance.client
            .from('profiles')
            .select('display_name,email,avatar_url')
            .eq('id', user.id)
            .maybeSingle();
        profile = response;
      }

      final settings = await _repo.getSettings(user.id);
      if (!mounted) return;

      setState(() {
        _displayNameController.text = (profile?['display_name'] as String?) ??
            user.email?.split('@').first ??
            '';
        _bioController.text = (profile?['bio'] as String?) ?? '';
        _avatarUrl = profile?['avatar_url'] as String?;
        _inAppNotifications = settings.inAppNotifications;
        _emailNotifications = settings.emailNotifications;
        _themeMode = settings.themeMode;
        _languageCode = settings.languageCode;
      });
    } catch (_) {
      // Ignore load errors
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        _showSnack(_t('Không đọc được dữ liệu ảnh', 'Could not read image data'));
        return;
      }

      final fileName = file.name.toLowerCase();
      String extension = 'jpg';
      if (fileName.endsWith('.png')) {
        extension = 'png';
      } else if (fileName.endsWith('.webp')) {
        extension = 'webp';
      } else if (fileName.endsWith('.gif')) {
        extension = 'gif';
      }

      setState(() {
        _pendingAvatarBytes = file.bytes;
        _pendingAvatarExtension = extension;
      });
    } catch (e) {
      _showSnack('${_t('Chọn ảnh thất bại', 'Image selection failed')}: $e');
    }
  }

  Future<void> _saveSettings() async {
    if (_userId == null) return;

    final displayName = _displayNameController.text.trim();
    final bio = _bioController.text.trim();
    if (displayName.isEmpty) {
      _showSnack(_t('Tên hiển thị không được để trống', 'Display name empty'));
      return;
    }

    setState(() => _saving = true);
    try {
      String? updatedAvatarUrl = _avatarUrl;
      if (_pendingAvatarBytes != null && _pendingAvatarExtension != null) {
        updatedAvatarUrl = await _repo.uploadAvatar(
          userId: _userId!,
          bytes: _pendingAvatarBytes!,
          fileExtension: _pendingAvatarExtension!,
        );
        _pendingAvatarBytes = null;
        _pendingAvatarExtension = null;
      }

      await _repo.updateProfile(
        userId: _userId!,
        displayName: displayName,
        bio: bio,
        avatarUrl: updatedAvatarUrl,
      );

      await _repo.updateSettings(
        userId: _userId!,
        inAppNotifications: _inAppNotifications,
        emailNotifications: _emailNotifications,
        themeMode: _themeMode,
        languageCode: _languageCode,
      );
      
      AppPreferences.apply(themeMode: _themeMode, languageCode: _languageCode);
      setState(() => _avatarUrl = updatedAvatarUrl);
      _showSnack(_t('Đã lưu tất cả thay đổi', 'All changes saved'));
    } catch (e) {
      _showSnack('${_t('Lưu cài đặt thất bại', 'Save failed')}: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _saveBasicSettings() async {
    if (_userId == null) return;
    try {
      await _repo.updateSettings(
        userId: _userId!,
        inAppNotifications: _inAppNotifications,
        emailNotifications: _emailNotifications,
        themeMode: _themeMode,
        languageCode: _languageCode,
      );
    } catch (_) {}
  }

  String _t(String vi, String en) => _languageCode == 'en' ? en : vi;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1A1D21), const Color(0xFF0D0F11)]
                : [const Color(0xFFF6F9FF), const Color(0xFFF8FBFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                        child: Row(
                          children: [
                            _iconShell(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onTap: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _t('Cài đặt', 'Settings'),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF12263F),
                                ),
                              ),
                            ),
                            _saveButton(),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _sectionCard(
                            title: _t('Tài khoản', 'Account'),
                            icon: Icons.person_outline_rounded,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 35,
                                      backgroundColor: const Color(0xFFDFE9FF),
                                      backgroundImage: _pendingAvatarBytes != null
                                          ? MemoryImage(_pendingAvatarBytes!) as ImageProvider
                                          : (_avatarUrl != null
                                              ? NetworkImage(_avatarUrl!) as ImageProvider
                                              : null),
                                      child: (_pendingAvatarBytes == null && _avatarUrl == null)
                                          ? const Icon(Icons.person, color: Color(0xFF2E66FF), size: 35)
                                          : null,
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _saving ? null : _pickAvatar,
                                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                                        label: Text(_t('Đổi ảnh', 'Change Photo')),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _buildTextField(
                                  controller: _displayNameController,
                                  label: _t('Tên hiển thị', 'Display name'),
                                  icon: Icons.badge_outlined,
                                ),
                                const SizedBox(height: 15),
                                _buildTextField(
                                  controller: _bioController,
                                  label: _t('Mô tả', 'Bio'),
                                  icon: Icons.edit_note_rounded,
                                  maxLines: 3,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                          _sectionCard(
                            title: _t('Thông báo', 'Notifications'),
                            icon: Icons.notifications_none_rounded,
                            child: Column(
                              children: [
                                _switchTile(
                                  title: _t('Thông báo trong app', 'In-app'),
                                  subtitle: _t('Badge và chuông', 'Badge & bell'),
                                  value: _inAppNotifications,
                                  onChanged: (v) {
                                    setState(() => _inAppNotifications = v);
                                    _saveBasicSettings();
                                  },
                                ),
                                _switchTile(
                                  title: _t('Email', 'Email'),
                                  subtitle: _t('Nhận tin qua email', 'Get email updates'),
                                  value: _emailNotifications,
                                  onChanged: (v) {
                                    setState(() => _emailNotifications = v);
                                    _saveBasicSettings();
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                          _sectionCard(
                            title: _t('Giao diện', 'Appearance'),
                            icon: Icons.palette_outlined,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    _choiceChip('system', _t('Hệ thống', 'System')),
                                    _choiceChip('light', _t('Sáng', 'Light')),
                                    _choiceChip('dark', _t('Tối', 'Dark')),
                                  ],
                                ),
                                const SizedBox(height: 15),
                                DropdownButtonFormField<String>(
                                  initialValue: _languageCode,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.language),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
                                    DropdownMenuItem(value: 'en', child: Text('English')),
                                  ],
                                  onChanged: (v) => _updatePrefsOptimistically(lang: v),
                                ),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _saveButton() {
    return ElevatedButton(
      onPressed: _saving ? null : _saveSettings,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2E66FF),
        foregroundColor: Colors.white,
        shape: RoundedRectanglePlatform.isIOS 
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _saving 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(_t('Lưu', 'Save')),
    );
  }

  Widget _iconShell({required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }

  Widget _sectionCard({required String title, required IconData icon, required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF2E66FF)),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Widget _switchTile({required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return SwitchListTile.adaptive(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeThumbColor: const Color(0xFF2E66FF),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _choiceChip(String value, String label) {
    final selected = _themeMode == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (s) => _updatePrefsOptimistically(theme: value),
      selectedColor: const Color(0xFF2E66FF),
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black),
    );
  }

  Timer? _prefDebounce;
  void _updatePrefsOptimistically({String? theme, String? lang}) {
    setState(() {
      if (theme != null) _themeMode = theme;
      if (lang != null) _languageCode = lang;
    });
    _prefDebounce?.cancel();
    _prefDebounce = Timer(const Duration(milliseconds: 300), () {
      AppPreferences.apply(themeMode: _themeMode, languageCode: _languageCode);
    });
  }
}

// Helper class đơn giản để kiểm tra platform
class RoundedRectanglePlatform {
  static bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;
}
