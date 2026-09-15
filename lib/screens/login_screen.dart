import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _phoneController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      if (_isLogin) {
        await authService.login(
          _usernameController.text,
          _passwordController.text,
        );
      } else {
        await authService.register(
          _usernameController.text,
          _passwordController.text,
          _displayNameController.text,
          phoneNumber: _phoneController.text.isNotEmpty ? _phoneController.text : null,
        );
      }
    } catch (e) {
      String message = e.toString();
      if (message.contains('user-not-found') ||
          message.contains('wrong-password') ||
          message.contains('invalid-credential')) {
        message = 'Invalid username or password.';
      } else if (message.contains('email-already-in-use')) {
        message = 'That username is already taken.';
      } else if (message.contains('weak-password')) {
        message = 'Password must be at least 6 characters.';
      }
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App icon
                  Image.asset('assets/screamicon.png', width: 80, height: 80),
                  const SizedBox(height: 24),
                  const Text(
                    'Nasan',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Family Ring & Locate',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Form
                  if (!_isLogin) ...[
                    TextField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(
                        hintText: 'Display Name',
                        prefixIcon: Icon(Icons.person_outline,
                            color: AppTheme.textSecondary),
                      ),
                      style: const TextStyle(color: AppTheme.textPrimary),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        hintText: 'Phone Number (Optional for SMS)',
                        prefixIcon: Icon(Icons.phone_rounded,
                            color: AppTheme.textSecondary),
                      ),
                      style: const TextStyle(color: AppTheme.textPrimary),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      hintText: 'Username',
                      prefixIcon: Icon(Icons.alternate_email,
                          color: AppTheme.textSecondary),
                    ),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      prefixIcon:
                          const Icon(Icons.lock_outline, color: AppTheme.textSecondary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppTheme.textSecondary,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    obscureText: _obscurePassword,
                  ),
                  const SizedBox(height: 8),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            color: AppTheme.primaryRed, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(_isLogin ? 'Sign In' : 'Create Account'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _error = null;
                      });
                    },
                    child: Text(
                      _isLogin
                          ? "Don't have an account? Sign Up"
                          : 'Already have an account? Sign In',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
