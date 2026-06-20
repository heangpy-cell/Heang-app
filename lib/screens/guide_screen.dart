import 'package:flutter/material.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = [
      {'icon': Icons.copy_rounded, 'color': const Color(0xFF7C3AED), 'title': 'ចម្លង Link', 'desc': 'ចូលទៅ TikTok, YouTube, Facebook ឬ Platform ណាក៏ដោយ ហើយ Copy Link វីដេអូ'},
      {'icon': Icons.content_paste_rounded, 'color': const Color(0xFF0088CC), 'title': 'Paste Link', 'desc': 'ចុចប៊ូតុង PASTE ដើម្បីដាក់ Link ទៅក្នុងប្រអប់ ឬ Type ដោយខ្លួនឯង'},
      {'icon': Icons.analytics_rounded, 'color': const Color(0xFFDC2743), 'title': 'Analyze', 'desc': 'ចុចប៊ូតុង ANALYZE & DOWNLOAD ហើយ App នឹងចាប់ Platform ស្វ័យប្រវត្តិ'},
      {'icon': Icons.download_done_rounded, 'color': Colors.greenAccent, 'title': 'Download រួច', 'desc': 'រង់ចាំពេលវីដេអូ Download រួច ហើយបើកកនៅ MY FILES'},
    ];

    final platforms = [
      {'name': 'TikTok', 'color': Colors.black, 'url': 'tiktok.com'},
      {'name': 'YouTube', 'color': const Color(0xFFFF0000), 'url': 'youtube.com'},
      {'name': 'Facebook', 'color': const Color(0xFF1877F2), 'url': 'facebook.com'},
      {'name': 'Instagram', 'color': const Color(0xFFDC2743), 'url': 'instagram.com'},
      {'name': 'Telegram', 'color': const Color(0xFF0088CC), 'url': 't.me'},
      {'name': 'Pinterest', 'color': const Color(0xFFE60023), 'url': 'pinterest.com'},
      {'name': 'Twitter/X', 'color': Colors.white, 'url': 'x.com'},
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [Colors.white, Color(0xFFC4B5FD)],
              ).createShader(b),
              child: const Text(
                'GUIDE',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 2),
              ),
            ),
            const SizedBox(height: 6),
            const Text('របៀបប្រើ LINK GRAB', style: TextStyle(color: Color(0xFF888AAA), fontSize: 12)),
            const SizedBox(height: 24),

            // Steps
            ...steps.asMap().entries.map((e) {
              final i = e.key;
              final s = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF13132A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: (s['color'] as Color).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (s['color'] as Color).withValues(alpha: 0.15),
                        border: Border.all(color: (s['color'] as Color).withValues(alpha: 0.4)),
                      ),
                      child: Stack(
                        children: [
                          Center(child: Icon(s['icon'] as IconData, color: s['color'] as Color, size: 22)),
                          Positioned(
                            top: 0, right: 0,
                            child: Container(
                              width: 18, height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: s['color'] as Color,
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s['title'] as String, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(s['desc'] as String, style: const TextStyle(color: Color(0xFF888AAA), fontSize: 11, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 20),
            const Text(
              'SUPPORTED PLATFORMS',
              style: TextStyle(color: Color(0xFF888AAA), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: platforms.map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (p['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: (p['color'] as Color).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: p['color'] as Color),
                      ),
                      const SizedBox(width: 6),
                      Text(p['name'] as String, style: TextStyle(color: p['color'] as Color, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF7C3AED).withValues(alpha: 0.2), const Color(0xFF1A1A35)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.tips_and_updates_rounded, color: Color(0xFFA855F7), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tip: ចុចលើ Platform Icon ដើម្បី Auto Fill Link គំរូ!',
                      style: TextStyle(color: Color(0xFFE8E8FF), fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
