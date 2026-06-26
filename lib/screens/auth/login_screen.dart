import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../shell/app_shell.dart';

enum _LoginRole { admin, employee, client }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _LoginRole _selectedRole = _LoginRole.admin;
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => AppShell()),
      );
    } else if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage!)),
      );
      auth.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text('Welcome Back! 👋', style: AppText.h1),
                const SizedBox(height: 6),
                Text(
                  'Login to continue to your account',
                  style: AppText.bodyMuted,
                ),
                const SizedBox(height: 28),

                Text('Login As', style: AppText.label),
                const SizedBox(height: 10),
                _RoleSelector(
                  selected: _selectedRole,
                  onChanged: (role) => setState(() => _selectedRole = role),
                ),
                const SizedBox(height: 24),

                Text('Email Address', style: AppText.label),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Enter your email',
                    prefixIcon: Icon(Icons.mail_outline, size: 20),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Email is required';
                    final emailRegex = RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\-\.]+$');
                    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                Text('Password', style: AppText.label),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleLogin(),
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Password is required';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _rememberMe = !_rememberMe),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: Checkbox(
                              value: _rememberMe,
                              onChanged: (v) => setState(() => _rememberMe = v ?? true),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('Remember me', style: AppText.bodyMuted),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Contact your administrator to reset your password.')),
                        );
                      },
                      child: const Text('Forgot Password?'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _handleLogin,
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text('Log In'),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or continue with', style: AppText.caption),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showComingSoon(context, 'Google sign-in'),
                        icon: const Icon(Icons.g_mobiledata, size: 22),
                        label: const Text('Google'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showComingSoon(context, 'Microsoft sign-in'),
                        icon: const Icon(Icons.window, size: 18),
                        label: const Text('Microsoft'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                Center(
                  child: RichText(
                    text: TextSpan(
                      style: AppText.bodyMuted,
                      children: [
                        const TextSpan(text: "Don't have an account? "),
                        TextSpan(
                          text: 'Contact Administrator',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon.')),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  final _LoginRole selected;
  final ValueChanged<_LoginRole> onChanged;

  const _RoleSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _roleCard(_LoginRole.admin, 'Admin', Icons.shield_outlined, AppColors.primary)),
        const SizedBox(width: 10),
        Expanded(child: _roleCard(_LoginRole.employee, 'Employee', Icons.person_outline, AppColors.info)),
        const SizedBox(width: 10),
        Expanded(child: _roleCard(_LoginRole.client, 'Client', Icons.groups_outlined, AppColors.success)),
      ],
    );
  }

  Widget _roleCard(_LoginRole role, String label, IconData icon, Color tint) {
    final isSelected = role == selected;
    return GestureDetector(
      onTap: () => onChanged(role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : AppColors.neutralBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected ? tint : AppColors.textFaint.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: isSelected ? Colors.white : AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
