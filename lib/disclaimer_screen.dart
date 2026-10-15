// Élan — First-launch safety notice.
// Google Play's Health apps policy expects medical apps to be clear about what
// they are not. Shown once, before sign-in; acceptance is remembered on device.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/api_service.dart';
import 'services/phone_service.dart';
import 'theme.dart';

class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key, required this.next});

  /// Where to go once the notice is accepted.
  final Widget next;

  /// Bump the version if the wording changes materially, so everyone sees it
  /// again.
  static const _prefKey = 'safetyNoticeAccepted_v1';

  static Future<bool> isAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  Future<void> _accept(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    Widget point(IconData icon, Color color, String title, String body) =>
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon: icon, color: color, size: 40, iconSize: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(body, style: text.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        );

    return AppBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.xl, AppSpace.xxl, AppSpace.xl, AppSpace.xl),
          children: [
            const Row(
              children: [
                BrandMark(size: 40),
                SizedBox(width: 10),
                BrandWordmark(size: 24),
              ],
            ),
            const SizedBox(height: 32),
            Text('Before you start', style: text.displayMedium),
            const SizedBox(height: AppSpace.xl),
            point(
              Icons.call_rounded,
              AppColors.emergency,
              'Élan does not replace 112',
              'If someone\'s life is in danger, call 112 (or 108 for an '
                  'ambulance) first. Use Élan alongside them, not instead.',
            ),
            point(
              Icons.local_hospital_rounded,
              AppColors.primary,
              'Hospitals decide whether to respond',
              'Élan sends your location and symptoms to nearby hospitals. '
                  'It cannot guarantee that a hospital accepts or how fast help '
                  'arrives.',
            ),
            point(
              Icons.medical_information_outlined,
              AppColors.primary,
              'Not medical advice',
              'Élan does not diagnose or treat any condition. Follow the '
                  'guidance of medical professionals.',
            ),
            point(
              Icons.privacy_tip_outlined,
              AppColors.primary,
              'Your location is shared only when you ask',
              'Élan reads your location on the Emergency screen and shares '
                  'it with hospitals only when you send an alert.',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () =>
                    PhoneService.openUrl(context, ApiService.privacyPolicyUrl),
                child: const Text('Read the privacy policy'),
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            PrimaryButton(
              label: 'I understand',
              icon: Icons.check_rounded,
              onPressed: () => _accept(context),
            ),
            const SizedBox(height: AppSpace.md),
            OutlinedButton.icon(
              onPressed: () =>
                  PhoneService.dial(context, PhoneService.emergencyNumber),
              icon: const Icon(Icons.call_rounded, size: 18),
              label: const Text('Call 112 now'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.emergency,
                side: BorderSide(
                    color: AppColors.emergency.withValues(alpha: 0.4)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
