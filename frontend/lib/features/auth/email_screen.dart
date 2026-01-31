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
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => OtpScreen(email: email)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            const minFormSpace = 320.0;
            const minTop = 220.0;

            // Allocate hero height while guaranteeing room for the form; avoid overflow on short screens
            double topHeight = height * 0.55;
            if (height - topHeight < minFormSpace) {
              topHeight = (height - minFormSpace).clamp(minTop, height * 0.6);
            }
            final useScroll = height - topHeight < minFormSpace;

            return Column(
              children: [
                // Hero band with logo, title, tagline
                SizedBox(
                  height: topHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E4ED8), Color(0xFF5B8CFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(28),
                            bottomRight: Radius.circular(28),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 52,
                        right: -24,
                        child: Opacity(
                          opacity: 0.08,
                          child: Icon(
                            Icons.music_note_rounded,
                            size: 200,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: -28,
                        child: Opacity(
                          opacity: 0.06,
                          child: Icon(
                            Icons.headphones_rounded,
                            size: 220,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 76,
                                      height: 76,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        gradient: AppGradients.blue,
                                        boxShadow: AppShadows.soft,
                                      ),
                                      child: const Icon(
                                        Icons.graphic_eq_rounded,
                                        color: Color(0xFF0F172A),
                                        size: 36,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'VibeIt',
                                          style: textTheme.displayLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                letterSpacing: -0.8,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Sync your music universe.',
                                          style: textTheme.bodyLarge?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.9,
                                            ),
                                            height: 1.35,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Removed center cut-out; clean separation handled by curved radius
                    ],
                  ),
                ),

                // Form section
                Expanded(
                  child: useScroll
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                          child: _FormContent(
                            textTheme: textTheme,
                            hasBlurred: _hasBlurred,
                            errorText: _errorText,
                            emailController: _emailController,
                            focusNode: _focusNode,
                            onEmailChanged: _onEmailChanged,
                            showButton: showButton,
                            submitting: _submitting,
                            onSubmit: _submit,
                          ),
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                            child: _FormContent(
                              textTheme: textTheme,
                              hasBlurred: _hasBlurred,
                              errorText: _errorText,
                              emailController: _emailController,
                              focusNode: _focusNode,
                              onEmailChanged: _onEmailChanged,
                              showButton: showButton,
                              submitting: _submitting,
                              onSubmit: _submit,
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FormContent extends StatelessWidget {
  const _FormContent({
    required this.textTheme,
    required this.hasBlurred,
    required this.errorText,
    required this.emailController,
    required this.focusNode,
    required this.onEmailChanged,
    required this.showButton,
    required this.submitting,
    required this.onSubmit,
  });

  final TextTheme textTheme;
  final bool hasBlurred;
  final String? errorText;
  final TextEditingController emailController;
  final FocusNode focusNode;
  final ValueChanged<String> onEmailChanged;
  final bool showButton;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Sign in to continue',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TextField(
                  controller: emailController,
                  focusNode: focusNode,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
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
                        color: hasBlurred && errorText != null
                            ? AppColors.error
                            : AppColors.border,
                        width: 1.2,
                      ),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: errorText != null
                            ? AppColors.error
                            : AppColors.accent,
                        width: 1.6,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: onEmailChanged,
                  onSubmitted: (_) {
                    if (showButton && !submitting) {
                      onSubmit();
                    }
                  },
                ),
                if (hasBlurred && errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorText!,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: showButton
                ? ElevatedButton(
                    key: const ValueKey('get_otp_btn'),
                    style: AppButtonStyles.primary,
                    onPressed: submitting ? null : onSubmit,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (submitting)
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
          const SizedBox(height: 26),
          Text(
            "We'll send a one-time code to verify you",
            style: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
