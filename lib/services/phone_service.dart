// Élan — Open the phone dialler.
// Backed by the "elan/phone" platform channel (MainActivity.kt / AppDelegate),
// so no plugin dependency is needed.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhoneService {
  static const _channel = MethodChannel('elan/phone');

  /// The number to call when no hospital can be reached (India: 112).
  static const emergencyNumber = '112';

  /// Open the dialler with [number]. Where that isn't possible (web, tests,
  /// a device without telephony) the number is copied to the clipboard and
  /// the user is told, so a tap is never silently lost.
  static Future<void> dial(BuildContext context, String number) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var opened = false;
    try {
      opened = await _channel.invokeMethod<bool>('dial', {'number': number}) ??
          false;
    } catch (_) {
      opened = false;
    }
    if (opened) return;

    await Clipboard.setData(ClipboardData(text: number));
    messenger?.showSnackBar(
      SnackBar(content: Text('Could not open the dialler. $number copied.')),
    );
  }
}
