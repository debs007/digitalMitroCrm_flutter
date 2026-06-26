import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/profile_service.dart';
import '../../widgets/app_avatar.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  final _passwordController = TextEditingController();
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      await ProfileService.instance.uploadAvatar(File(picked.path));
      if (mounted) await context.read<AuthProvider>().refreshProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : 'Could not update photo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });
    try {
      await ProfileService.instance.updateMyProfile(
        user,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text.trim().isNotEmpty ? _passwordController.text.trim() : null,
      );
      await auth.refreshProfile();
      _passwordController.clear();
      setState(() {
        _success = 'Profile updated.';
        _saving = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : 'Could not save changes.';
        _saving = false;
      });
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Log out', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isAdmin = user?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  AppAvatar(name: user?.name ?? '', imageUrl: user?.avatar, size: 88),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: _uploadingAvatar
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(_error!, style: TextStyle(color: AppColors.danger)),
              ),
            if (_success != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(_success!, style: TextStyle(color: AppColors.success)),
              ),

            Text('Full name', style: AppText.label),
            const SizedBox(height: 6),
            TextField(controller: _nameController),
            const SizedBox(height: 16),

            Text('Phone', style: AppText.label),
            const SizedBox(height: 6),
            TextField(controller: _phoneController, keyboardType: TextInputType.phone),
            const SizedBox(height: 16),

            Text('Email', style: AppText.label),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(color: AppColors.neutralBg, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(child: Text(user?.email ?? '', style: AppText.bodyMuted)),
                  Icon(Icons.lock_outline, size: 16, color: AppColors.textFaint),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text('Contact your administrator to change your email.', style: AppText.caption),

            if (isAdmin) ...[
              const SizedBox(height: 16),
              Text('New password (optional)', style: AppText.label),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Leave blank to keep current password'),
              ),
            ],

            const SizedBox(height: 24),
            _buildThemeToggle(),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Save changes'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _confirmLogout,
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: BorderSide(color: AppColors.danger)),
                child: const Text('Log out'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    final themeProvider = context.watch<ThemeProvider>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: AppColors.neutralBg, borderRadius: BorderRadius.circular(14)),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(
          themeProvider.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
          color: AppColors.primary,
        ),
        title: const Text('Dark mode'),
        subtitle: Text(themeProvider.isDark ? 'On' : 'Off', style: AppText.caption),
        value: themeProvider.isDark,
        activeColor: AppColors.primary,
        onChanged: (value) => themeProvider.setDark(value),
      ),
    );
  }
}
