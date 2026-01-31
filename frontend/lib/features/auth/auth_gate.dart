import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../shell/main_shell.dart';
import 'email_screen.dart';
import 'onboarding_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);

    return state.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Something went wrong: $err'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
                child: const Text('Back to login'),
              ),
            ],
          ),
        ),
      ),
      data: (auth) =>
          auth.isAuthenticated
              ? _OnboardingSwitch(profileId: auth.profile!.id, profileEmail: auth.profile!.email)
              : const EmailScreen(),
    );
  }
}

class _OnboardingSwitch extends ConsumerWidget {
  const _OnboardingSwitch({required this.profileId, required this.profileEmail});

  final String profileId;
  final String profileEmail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingStatusProvider(profileId));

    return onboarding.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Something went wrong: $err'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(onboardingStatusProvider(profileId)),
                child: const Text('Retry'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
                child: const Text('Back to login'),
              ),
            ],
          ),
        ),
      ),
      data: (complete) => complete
          ? const MainShell()
          : OnboardingScreen(profileId: profileId, email: profileEmail),
    );
  }
}
