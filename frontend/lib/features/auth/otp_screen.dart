import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system.dart';
import '../../providers.dart';
import 'auth_gate.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _boxes = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  bool _submitting = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    for (final node in _focusNodes) {
      node.addListener(() => setState(() {}));
    }
    // Show OTP sent toast on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showToast('OTP sent successfully. Valid for 10 minutes.', isError: false);
    });
  }

  @override
  void dispose() {
    for (final c in _boxes) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _boxes.map((c) => c.text).join();

  void _showToast(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _onDigitChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Handle paste (multiple digits)
    if (digits.length > 1) {
      for (var i = 0; i < digits.length && index + i < _boxes.length; i++) {
        _boxes[index + i].text = digits[i];
      }
      final target = (index + digits.length) >= _boxes.length
          ? _boxes.length - 1
          : index + digits.length;
      _focusNodes[target].requestFocus();
      setState(() {});
      return;
    }
    
    // Single digit entered
    if (digits.length == 1) {
      _boxes[index].text = digits;
      _boxes[index].selection = TextSelection.fromPosition(
        TextPosition(offset: _boxes[index].text.length),
      );
      // Move to next box
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      }
    }

    setState(() {});
  }

  void _onKeyEvent(int index, KeyEvent evt) {
    if (evt is! KeyDownEvent) return;
    
    if (evt.logicalKey == LogicalKeyboardKey.backspace) {
      if (_boxes[index].text.isNotEmpty) {
        // Box has value: clear it, stay on same box
        _boxes[index].text = '';
        setState(() {});
      } else if (index > 0) {
        // Box is empty: move to previous box and clear it
        _focusNodes[index - 1].requestFocus();
        _boxes[index - 1].text = '';
        setState(() {});
      }
    }
  }

  Future<void> _submit() async {
    if (_code.length != 6) return;
    setState(() => _submitting = true);

    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyOtp(widget.email, _code);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showToast(e.toString().contains('expired') 
            ? 'OTP expired. Please request a new code.'
            : 'Invalid OTP. Please try again.', 
            isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ref.read(authRepositoryProvider).requestOtp(widget.email);
      if (mounted) {
        _showToast('OTP sent successfully. Valid for 10 minutes.', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showToast(e.toString(), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _resending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final showVerify = _code.length == 6;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              const Spacer(flex: 1),
              // Title
              Text(
                'Verify your email',
                style: textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Email chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.email,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // Instructions
              Text(
                'Enter the 6-digit code',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // OTP boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  final isFocused = _focusNodes[index].hasFocus;
                  final hasValue = _boxes[index].text.isNotEmpty;
                  
                  return Padding(
                    padding: EdgeInsets.only(right: index == 5 ? 0 : 10),
                    child: SizedBox(
                      width: 48,
                      height: 56,
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (e) => _onKeyEvent(index, e),
                        child: TextField(
                          controller: _boxes[index],
                          focusNode: _focusNodes[index],
                          autofocus: index == 0,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          maxLength: 1,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: isFocused || hasValue 
                                ? Colors.white 
                                : AppColors.surface,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: hasValue ? AppColors.accent : AppColors.border,
                                width: hasValue ? 2 : 1.2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.accent,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.only(bottom: 4),
                          ),
                          onChanged: (v) => _onDigitChanged(index, v),
                          onTap: () => _focusNodes[index].requestFocus(),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              // Expiry helper text
              Text(
                'Code expires in 10 minutes',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Verify button
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: showVerify
                    ? ElevatedButton(
                        key: const ValueKey('verify_btn'),
                        style: AppButtonStyles.lightAction,
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
                                  color: AppColors.textPrimary,
                                ),
                              )
                            else ...[
                              Text(
                                'Verify & continue',
                                style: textTheme.labelLarge?.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ],
                        ),
                      )
                    : const SizedBox(height: 52),
              ),
              const Spacer(flex: 2),
              // Resend
              TextButton(
                onPressed: _resending ? null : _resend,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  textStyle: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: _resending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Didn't receive the code? Resend"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
