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
  final _keyboardFocus = FocusNode();
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
    for (final f in _focusNodes) {
      f.dispose();
    }
    _keyboardFocus.dispose();
    super.dispose();
  }

  String get _code => _boxes.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
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
    if (digits.length == 1) {
      _boxes[index].text = digits;
      _boxes[index].selection = TextSelection.fromPosition(
        TextPosition(offset: _boxes[index].text.length),
      );
    }

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    setState(() {});
  }

  void _onKey(int index, KeyEvent evt) {
    if (evt is! KeyDownEvent) return;
    if (evt.logicalKey == LogicalKeyboardKey.backspace && _boxes[index].text.isEmpty) {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
        _boxes[index - 1].text = '';
      }
      setState(() {});
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

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ref.read(authRepositoryProvider).requestOtp(widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code resent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Verify your email', style: textTheme.headlineMedium),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(widget.email, style: textTheme.bodyLarge),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text('Edit email'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text('Enter the 6-digit code', style: textTheme.bodyMedium),
              const SizedBox(height: 14),
              KeyboardListener(
                focusNode: _keyboardFocus,
                onKeyEvent: (e) {
                  for (var i = 0; i < _boxes.length; i++) {
                    _onKey(i, e);
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: List.generate(6, (index) {
                    final isFocused = _focusNodes[index].hasFocus;
                    return Padding(
                      padding: EdgeInsets.only(right: index == 5 ? 0 : 10),
                      child: SizedBox(
                        width: 48,
                        height: 56,
                        child: TextField(
                          controller: _boxes[index],
                          focusNode: _focusNodes[index],
                          autofocus: index == 0,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          maxLength: 1,
                          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            decoration: InputDecoration(
                              counterText: '',
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: isFocused ? AppColors.accent : AppColors.border,
                                  width: isFocused ? 2 : 1.2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.accent, width: 2),
                              ),
                              contentPadding: const EdgeInsets.only(bottom: 6),
                            ),
                          onChanged: (v) => _onDigitChanged(index, v),
                          onTap: () => _focusNodes[index].requestFocus(),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: showVerify
                    ? ElevatedButton(
                        key: const ValueKey('verify_btn'),
                        style: AppButtonStyles.primary,
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textPrimary,
                                ),
                              )
                            : const Text('Verify & continue'),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 10),
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
