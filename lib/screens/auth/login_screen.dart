import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/network/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../shell/app_shell.dart';
import 'forgot_password_screen.dart';

enum _LoginRole { admin, employee, client }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final TapGestureRecognizer _contactAdminRecognizer;
  late final TapGestureRecognizer _signUpRecognizer;
  late final TapGestureRecognizer _backToLoginRecognizer;

  _LoginRole _selectedRole = _LoginRole.admin;
  bool _obscurePassword = true;
  bool _rememberMe = true;

  // Sign up is Client-only — Admin/Employee accounts are provisioned by a
  // SuperAdmin, so there's nothing to self-register for those roles.
  bool _isSignUpMode = false;
  bool _isSigningUp = false;
  String? _signUpError;

  static const String _adminEmail = 'digitalmitrous@gmail.com';

  @override
  void initState() {
    super.initState();
    _contactAdminRecognizer = TapGestureRecognizer()..onTap = _contactAdministrator;
    _signUpRecognizer = TapGestureRecognizer()..onTap = _enterSignUpMode;
    _backToLoginRecognizer = TapGestureRecognizer()..onTap = _exitSignUpMode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _contactAdminRecognizer.dispose();
    _signUpRecognizer.dispose();
    _backToLoginRecognizer.dispose();
    super.dispose();
  }

  void _enterSignUpMode() {
    setState(() {
      _isSignUpMode = true;
      _signUpError = null;
    });
  }

  void _exitSignUpMode() {
    setState(() {
      _isSignUpMode = false;
      _signUpError = null;
      _nameController.clear();
      _passwordController.clear();
    });
  }

  void _onRoleChanged(_LoginRole role) {
    setState(() {
      _selectedRole = role;
      // Sign up only exists for Client — bail out of it if the role
      // changes away, so an Admin/Employee never ends up on the signup form.
      if (role != _LoginRole.client && _isSignUpMode) {
        _isSignUpMode = false;
        _signUpError = null;
        _nameController.clear();
        _passwordController.clear();
      }
    });
  }

  // Opens the user's email app pre-addressed to the administrator, for
  // Admin/Employee roles which have no self-signup.
  Future<void> _contactAdministrator() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _adminEmail,
      query: 'subject=${Uri.encodeComponent('Digital Mitro app — account request')}',
    );
    final opened = await launchUrl(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open your email app. Please email $_adminEmail directly.')),
      );
    }
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

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isSigningUp = true;
      _signUpError = null;
    });
    try {
      await AuthService.instance.clientSignUp(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      // Drop back to the login form with the new email pre-filled, rather
      // than auto-logging in — signup doesn't return a token, only a
      // confirmation, so a normal login right after is the simplest path.
      setState(() {
        _isSigningUp = false;
        _isSignUpMode = false;
        _passwordController.clear();
        _nameController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created! Log in with your email and password.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _signUpError = e.message;
        _isSigningUp = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _signUpError = 'Something went wrong. Please try again.';
        _isSigningUp = false;
      });
    }
  }

  void _handleForgotPassword() {
    if (_selectedRole == _LoginRole.client) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
      );
      return;
    }
    // Admin/Employee — unchanged: no self-service reset, direct them to
    // their administrator instead.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contact your administrator to reset your password.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isClient = _selectedRole == _LoginRole.client;

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
                Text(_isSignUpMode ? 'Create Account 👋' : 'Welcome Back! 👋', style: AppText.h1),
                const SizedBox(height: 6),
                Text(
                  _isSignUpMode
                      ? 'Sign up to get started as a client'
                      : 'Login to continue to your account',
                  style: AppText.bodyMuted,
                ),
                const SizedBox(height: 28),

                Text('Login As', style: AppText.label),
                const SizedBox(height: 10),
                _RoleSelector(
                  selected: _selectedRole,
                  onChanged: _onRoleChanged,
                ),
                const SizedBox(height: 24),

                if (_isSignUpMode) ...[
                  if (_signUpError != null) ...[
                    Text(_signUpError!, style: TextStyle(color: AppColors.danger)),
                    const SizedBox(height: 12),
                  ],
                  Text('Full Name', style: AppText.label),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Enter your name',
                      prefixIcon: Icon(Icons.person_outline, size: 20),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Name is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                ],

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
                  onFieldSubmitted: (_) => _isSignUpMode ? _handleSignUp() : _handleLogin(),
                  decoration: InputDecoration(
                    hintText: _isSignUpMode ? 'Create a password' : 'Enter your password',
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
                    if (_isSignUpMode && value.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                if (!_isSignUpMode) ...[
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
                        onPressed: _handleForgotPassword,
                        child: const Text('Forgot Password?'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSignUpMode
                        ? (_isSigningUp ? null : _handleSignUp)
                        : (auth.isLoading ? null : _handleLogin),
                    child: (_isSignUpMode ? _isSigningUp : auth.isLoading)
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(_isSignUpMode ? 'Sign Up' : 'Log In'),
                  ),
                ),
                const SizedBox(height: 28),

                Center(
                  child: _isSignUpMode
                      ? RichText(
                          text: TextSpan(
                            style: AppText.bodyMuted,
                            children: [
                              const TextSpan(text: 'Already have an account? '),
                              TextSpan(
                                text: 'Log In',
                                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                                recognizer: _backToLoginRecognizer,
                              ),
                            ],
                          ),
                        )
                      : RichText(
                          text: TextSpan(
                            style: AppText.bodyMuted,
                            children: [
                              const TextSpan(text: "Don't have an account? "),
                              TextSpan(
                                text: isClient ? 'Sign Up' : 'Contact Administrator',
                                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                                recognizer: isClient ? _signUpRecognizer : _contactAdminRecognizer,
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
