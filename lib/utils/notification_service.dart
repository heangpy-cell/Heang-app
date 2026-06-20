import 'package:flutter/material.dart';

/// Global Notification Service — ប្រើ ScaffoldMessengerKey
/// ដើម្បីបង្ហាញ SnackBar ពីណាក៏ដោយ (Provider, Service)
class NotificationService {
  NotificationService._();

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void showSuccess(String platform, String title) {
    final name = title.length > 40 ? '${title.substring(0, 40)}...' : title;
    _show(
      '✅ $platform: "$name" Download ជោគជ័យ!',
      const Color(0xFF1B4332),
      Icons.check_circle_rounded,
      Colors.greenAccent,
      const Duration(seconds: 4),
    );
  }

  static void showError(String platform, String error) {
    _show(
      '❌ $platform: $error',
      const Color(0xFF4A0000),
      Icons.error_rounded,
      Colors.redAccent,
      const Duration(seconds: 5),
    );
  }

  static void showInfo(String message) {
    _show(
      message,
      const Color(0xFF1A1A35),
      Icons.info_rounded,
      const Color(0xFFA855F7),
      const Duration(seconds: 3),
    );
  }

  static void _show(
    String message,
    Color bgColor,
    IconData icon,
    Color iconColor,
    Duration duration,
  ) {
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: duration,
        ),
      );
  }
}
