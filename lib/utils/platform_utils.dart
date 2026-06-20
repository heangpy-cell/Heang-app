import 'package:flutter/material.dart';

/// Utility class ចែករំលែក Platform Detection ហើយ ប្រើបានគ្រប់ File
class PlatformUtils {
  PlatformUtils._();

  /// ចាប់ Platform ពី URL
  static String detectPlatform(String url) {
    final u = url.toLowerCase();
    if (u.contains('tiktok')) return 'TikTok';
    if (u.contains('youtu')) return 'YouTube';
    if (u.contains('facebook') || u.contains('fb.watch')) return 'Facebook';
    if (u.contains('instagram') || u.contains('instagr')) return 'Instagram';
    if (u.contains('reelshort')) return 'ReelShort';
    if (u.contains('netshort')) return 'NetShort';
    if (u.contains('dramabox') || u.contains('dramabite')) return 'DramaBox';
    if (u.contains('t.me') || u.contains('telegram')) return 'Telegram';
    if (u.contains('pinterest') || u.contains('pin.it')) return 'Pinterest';
    if (u.contains('twitter') || u.contains('x.com')) return 'Twitter';
    return 'Unknown';
  }

  /// ពណ៌ Platform
  static const Map<String, Color> platformColors = {
    'TikTok': Color(0xFF000000),
    'YouTube': Color(0xFFFF0000),
    'Facebook': Color(0xFF1877F2),
    'Instagram': Color(0xFFDC2743),
    'ReelShort': Color(0xFFFF4500),
    'NetShort': Color(0xFFFF2D55),
    'DramaBox': Color(0xFF8B5CF6),
    'Telegram': Color(0xFF0088CC),
    'Pinterest': Color(0xFFE60023),
    'Twitter': Color(0xFF1DA1F2),
    'Unknown': Color(0xFF7C3AED),
  };

  static Color colorFor(String platform) =>
      platformColors[platform] ?? const Color(0xFF7C3AED);

  /// Icon Platform
  static const Map<String, IconData> platformIcons = {
    'TikTok': Icons.music_note_rounded,
    'YouTube': Icons.play_circle_fill_rounded,
    'Facebook': Icons.facebook_rounded,
    'Instagram': Icons.camera_alt_rounded,
    'ReelShort': Icons.movie_filter_rounded,
    'NetShort': Icons.video_library_rounded,
    'DramaBox': Icons.video_collection_rounded,
    'Telegram': Icons.send_rounded,
    'Pinterest': Icons.push_pin_rounded,
    'Twitter': Icons.alternate_email_rounded,
    'Unknown': Icons.link_rounded,
  };

  static IconData iconFor(String platform) =>
      platformIcons[platform] ?? Icons.link_rounded;
}
