import 'dart:math' as math;

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
  }

  @override
  void dispose() {
    for (final c in _boxes) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _boxes.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length > 1) {
      // Paste handling
      for (var i = 0; i < digits.length && index + i < _boxes.length; i++) {
        _boxes[index + i].text = digits[i];
      }
      final target = math.min(index + digits.length, _boxes.length - 1);
      _focusNodes[target].requestFocus();
      setState(() {});
      return;
    }

    if (digits.length == 1) {
      _boxes[index].text = digits;
      _boxes[index].selection = TextSelection.fromPosition(
        TextPosition(offset: _boxes[index].text.length),
      );
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
        _boxes[index].text = '';
        setState(() {});
      } else if (index > 0) {
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
        _showToast(
          e.toString().contains('expired')
              ? 'OTP expired. Please request a new code.'
              : 'Invalid OTP. Please try again.',
          isError: true,
        );
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
        _showToast(
          'OTP sent successfully. Valid for 10 minutes.',
          isError: false,
        );
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

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearMaterialBanners();
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: isError ? Colors.redAccent : AppColors.accent,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Icon(
          isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
          color: Colors.white,
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: const [SizedBox.shrink()],
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        messenger.hideCurrentMaterialBanner();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final showVerify = _code.length == 6;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            final isCompact = height < 640;
            final allowScroll = height < 420;

            double topHeight = height * (isCompact ? 0.42 : 0.5);
            topHeight = math.min(topHeight, 210);
            topHeight = math.max(topHeight, 110);

            final vPad = isCompact ? 4.0 : 8.0;
            final tightGap = isCompact ? 12.0 : 18.0;
            final tinyGap = isCompact ? 8.0 : 12.0;

            final content = ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: vPad),
                  Center(
                    child: Text(
                      'Verify your email',
                      style: textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: tightGap - 6),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.email,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Icon(
                            Icons.edit_rounded,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: tightGap),
                  Center(
                    child: Text(
                      'Enter the 6-digit code',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: tightGap + 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      final isFocused = _focusNodes[index].hasFocus;
                      final hasValue = _boxes[index].text.isNotEmpty;

                      return Padding(
                        padding: EdgeInsets.only(right: index == 5 ? 0 : 10),
                        child: SizedBox(
                          width: isCompact ? 42 : 48,
                          height: isCompact ? 46 : 56,
                          child: KeyboardListener(
                            focusNode: FocusNode(),
                            onKeyEvent: (e) => _onKeyEvent(index, e),
                            child: TextField(
                              controller: _boxes[index],
                              focusNode: _focusNodes[index],
                              autofocus: index == 0,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              textInputAction: index == 5
                                  ? TextInputAction.done
                                  : TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
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
                                    color: hasValue
                                        ? AppColors.accent
                                        : AppColors.border,
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
                                contentPadding: const EdgeInsets.only(
                                  bottom: 4,
                                ),
                              ),
                              onChanged: (v) => _onDigitChanged(index, v),
                              onTap: () => _focusNodes[index].requestFocus(),
                              onSubmitted: (_) {
                                if (index < 5) {
                                  _focusNodes[index + 1].requestFocus();
                                } else if (showVerify && !_submitting) {
                                  _submit();
                                }
                              },
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: isCompact ? 28 : 36),
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: showVerify
                          ? ElevatedButton(
                              key: const ValueKey('verify_btn'),
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
                                    const Text('Verify'),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : const SizedBox(height: 52),
                    ),
                  ),
                  SizedBox(height: tinyGap + 8),
                  Center(
                    child: TextButton(
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
                  ),
                  SizedBox(height: tinyGap),
                ],
              ),
            );

            return Column(
              children: [
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
                      Positioned(
                        top: 8,
                        left: 4,
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: allowScroll
                      ? SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(24, vPad, 24, 12),
                          child: Center(child: content),
                        )
                      : Center(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(24, vPad, 24, 12),
                            child: Center(child: content),
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
