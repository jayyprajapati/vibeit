import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system.dart';
import '../../providers.dart';
import 'otp_screen.dart';

class EmailScreen extends ConsumerStatefulWidget {
  const EmailScreen({super.key});

  @override
  ConsumerState<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends ConsumerState<EmailScreen> {
  final _emailController = TextEditingController();
  final _focusNode = FocusNode();
  bool _submitting = false;
  bool _hasBlurred = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _emailController.text.isNotEmpty) {
      // Blur happened and field has content
      _hasBlurred = true;
      _validate();
    }
  }

  void _validate() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorText = 'Enter your email');
      return;
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _errorText = 'Enter a valid email');
    } else {
      setState(() => _errorText = null);
    }
  }

  bool get _isEmailValid {
    final email = _emailController.text.trim();
    if (email.isEmpty) return false;
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email);
  }

  void _onEmailChanged(String value) {
    // Clear error when user starts editing again
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
    setState(() {}); // Rebuild to update button visibility
  }

  Future<void> _submit() async {
    if (!_isEmailValid) return;
    setState(() => _submitting = true);
    final email = _emailController.text.trim();

    try {
      await ref.read(authRepositoryProvider).requestOtp(email);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OtpScreen(email: email)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final showButton = _isEmailValid;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Subtle decorative background icons
            Positioned(
              top: 60,
              right: -30,
              child: Opacity(
                opacity: 0.04,
                child: Icon(Icons.music_note_rounded, size: 180, color: AppColors.textPrimary),
              ),
            ),
            Positioned(
              bottom: 100,
              left: -40,
              child: Opacity(
                opacity: 0.03,
                child: Icon(Icons.headphones_rounded, size: 200, color: AppColors.textPrimary),
              ),
            ),
            // Main content - aligned like OTP screen
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                children: [
                  const Spacer(flex: 1),
                  // Title
                  Text(
                    'Sign in to continue',
                    style: textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // Subtitle
                  Text(
                    'Create playlists once.\nPlay them anywhere.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  // Email input with validation
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        TextField(
                          controller: _emailController,
                          focusNode: _focusNode,
                          autofocus: true,
                          keyboardType: TextInputType.emailAddress,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter your email',
                            hintStyle: TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                            filled: false,
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: _hasBlurred && _errorText != null 
                                    ? AppColors.error 
                                    : AppColors.border,
                                width: 1.2,
                              ),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: _errorText != null 
                                    ? AppColors.error 
                                    : AppColors.accent,
                                width: 1.6,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: _onEmailChanged,
                        ),
                        if (_hasBlurred && _errorText != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _errorText!,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Get OTP button - only shows when valid
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: showButton
                        ? ElevatedButton(
                            key: const ValueKey('get_otp_btn'),
                            style: AppButtonStyles.primary,
                            onPressed: _submitting ? null : _submit,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_submitting)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                else ...[
                                  const Text('Get OTP'),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_rounded, size: 18),
                                ],
                              ],
                            ),
                          )
                        : const SizedBox(height: 52),
                  ),
                  const Spacer(flex: 2),
                  // Helper text
                  Text(
                    "We'll send a one-time code to verify you",
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
