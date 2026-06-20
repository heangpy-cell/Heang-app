import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/download_provider.dart';
import '../widgets/platform_chip.dart';
import '../widgets/download_card.dart';
import '../widgets/saved_card.dart';
import '../widgets/tiktok_profile_sheet.dart';
import '../widgets/reelshort_series_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  // Pulses the glow on the paste box border
  late AnimationController _glowController;
  late Animation<double> _glowAnim;
  late AnimationController _buttonController;
  late Animation<double> _buttonScale;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.15, end: 0.55).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _buttonScale = Tween<double>(begin: 1, end: 0.95).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    _buttonController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _paste() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      _urlController.text = data!.text!;
      _showSnack('✅ បានស្នាម Link!');
    }
  }

  void _analyze() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnack('⚠️ សូមដាក់ Link មុន!');
      return;
    }
    if (!url.startsWith('http')) {
      _showSnack('⚠️ Link មិនត្រឹមត្រូវ!');
      return;
    }

    await _buttonController.forward();
    await _buttonController.reverse();

    if (!mounted) return;
    final provider = context.read<DownloadProvider>();
    final platform = provider.detectPlatform(url);

    // ពិនិត្យមើលថាតើជា TikTok Profile URL ឬអត់ (មាន @ តែគ្មាន /video/)
    if (platform == 'TikTok' && url.contains('@') && !url.contains('/video/')) {
      _urlController.clear();
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => TikTokProfileSheet(profileUrl: url),
      );
      return;
    }

    // ពិនិត្យមើលថាតើជា ReelShort, NetShort, DramaBox ឬ Telegram URL ឬអត់
    bool isTelegramSinglePost = false;
    if (platform == 'Telegram') {
      try {
        final uri = Uri.parse(url);
        final segments = uri.pathSegments;
        if (segments.isNotEmpty && RegExp(r'^\d+$').hasMatch(segments.last)) {
          isTelegramSinglePost = true;
        }
      } catch (_) {}
    }

    if (platform == 'ReelShort' || platform == 'NetShort' || platform == 'DramaBox' || (platform == 'Telegram' && !isTelegramSinglePost)) {
      _urlController.clear();
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ReelShortSeriesSheet(seriesUrl: url),
      );
      return;
    }

    _showSnack('🔍 កំពុង Analyze... $platform');

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    provider.startDownload(url);
    _urlController.clear();
    _showSnack('⬇️ Download ចាប់ផ្តើម!');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Roboto')),
        backgroundColor: const Color(0xFF2D1B69),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 18),
                  _buildPasteBox(),
                  const SizedBox(height: 18),
                  _buildPlatformGrid(),
                  const SizedBox(height: 18),
                  _buildAnalyzeButton(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('CURRENT DOWNLOADS'),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          _buildActiveDownloads(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('RECENTLY SAVED'),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          _buildSavedList(),
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const AnimatedHeangTitle(),
        IconButton(
          onPressed: () => _showSettingsSheet(),
          icon: const Icon(Icons.settings_rounded),
          color: const Color(0xFF888AAA),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF13132A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasteBox() {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF7C3AED), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: _glowAnim.value),
                blurRadius: 22,
                spreadRadius: 0,
              ),
            ],
            color: const Color(0xFF13132A),
          ),
          padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  style: const TextStyle(
                    color: Color(0xFFE8E8FF),
                    fontSize: 12,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'PASTE YOUR LINK HERE...',
                    hintStyle: TextStyle(
                      color: Color(0xFF555577),
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _paste,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
                    ),
                  ),
                  child: const Text(
                    'PASTE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlatformGrid() {
    final platforms = [
      {'name': 'TikTok',    'color': const Color(0xFF000000), 'icon': Icons.music_note_rounded},
      {'name': 'YouTube',   'color': const Color(0xFFFF0000), 'icon': Icons.play_circle_fill_rounded},
      {'name': 'Facebook',  'color': const Color(0xFF1877F2), 'icon': Icons.facebook_rounded},
      {'name': 'Instagram', 'color': const Color(0xFFDC2743), 'icon': Icons.camera_alt_rounded},
      {'name': 'ReelShort', 'color': const Color(0xFFFF4500), 'icon': Icons.movie_filter_rounded},
      {'name': 'NetShort',  'color': const Color(0xFFFF2D55), 'icon': Icons.video_library_rounded},
      {'name': 'DramaBox',  'color': const Color(0xFF8B5CF6), 'icon': Icons.video_collection_rounded},
      {'name': 'Telegram',  'color': const Color(0xFF0088CC), 'icon': Icons.send_rounded},
      {'name': 'Pinterest', 'color': const Color(0xFFE60023), 'icon': Icons.push_pin_rounded},
      {'name': 'Twitter',   'color': const Color(0xFF000000), 'icon': Icons.alternate_email_rounded},
    ];

    return GridView.count(
      crossAxisCount: 5, // Expanded grid count to 5 columns so it fits nicely
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 8,
      childAspectRatio: 0.85,
      children: platforms.map((p) {
        return PlatformChip(
          name: p['name'] as String,
          color: p['color'] as Color,
          icon: p['icon'] as IconData,
          onTap: () => _setExampleUrl(p['name'] as String),
        );
      }).toList(),
    );
  }

  void _setExampleUrl(String platform) {
    final examples = {
      'TikTok':    'https://www.tiktok.com/@user/video/123456789',
      'YouTube':   'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      'Facebook':  'https://www.facebook.com/watch?v=123456789',
      'Instagram': 'https://www.instagram.com/p/ABC123/',
      'ReelShort': 'https://www.reelshort.com/episodes/episode-1-my-series-abc123def456ghi789jkl0-chapterid12',
      'NetShort':  'https://www.netshort.com/episode/my-series-ep-1',
      'DramaBox':  'https://www.dramaboxdb.com/movie/42000010883/think-again-im-the-hidden-boss-mom',
      'Telegram':  'https://t.me/channel/123',
      'Pinterest': 'https://www.pinterest.com/pin/123456789/',
      'Twitter':   'https://x.com/user/status/123456789',
    };
    if (examples.containsKey(platform)) {
      _urlController.text = examples[platform]!;
      _showSnack('$platform - បានដាក់ Link គំរូ');
    }
  }

  Widget _buildAnalyzeButton() {
    return ScaleTransition(
      scale: _buttonScale,
      child: GestureDetector(
        onTap: _analyze,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFF6D28D9), Color(0xFFA855F7)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.45),
                blurRadius: 25,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ANALYZE & DOWNLOAD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.download_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF888AAA),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildActiveDownloads() {
    return Consumer<DownloadProvider>(
      builder: (_, provider, __) {
        final items = provider.activeDownloads;
        if (items.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildEmpty(Icons.download_rounded, 'មិនមានការ Download នៅឡើយ'),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: DownloadCard(item: items[i]),
            ),
            childCount: items.length,
          ),
        );
      },
    );
  }

  Widget _buildSavedList() {
    return Consumer<DownloadProvider>(
      builder: (_, provider, __) {
        final items = provider.completedDownloads;
        if (items.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildEmpty(Icons.bookmark_rounded, 'មិនទាន់មានឯកសារ'),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SavedCard(item: items[i]),
            ),
            childCount: items.length,
          ),
        );
      },
    );
  }

  Widget _buildEmpty(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF13132A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF4A4A6A), size: 36),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Color(0xFF888AAA), fontSize: 12)),
        ],
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13132A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const SettingsSheet(),
    );
  }
}

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  bool _hd = true;
  bool _autoDetect = true;
  bool _notifications = true;
  String _quality = 'Auto';
  final _igController = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _igController.text = prefs.getString('ig_session_id') ?? '';
        _quality = prefs.getString('video_quality') ?? 'Auto';
        _hd = prefs.getBool('hd_quality') ?? true;
        _autoDetect = prefs.getBool('auto_detect') ?? true;
        _notifications = prefs.getBool('notifications') ?? true;
      });
    }
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ig_session_id', _igController.text.trim());
    await prefs.setString('video_quality', _quality);
    await prefs.setBool('hd_quality', _hd);
    await prefs.setBool('auto_detect', _autoDetect);
    await prefs.setBool('notifications', _notifications);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Settings saved!')),
      );
    }
  }

  @override
  void dispose() {
    _igController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚙️ ការកំណត់',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          _settingRow('HD Quality', 'Download 1080p/4K', Switch(value: _hd, onChanged: (v) => setState(() => _hd = v), activeThumbColor: const Color(0xFF7C3AED))),
          _settingRow('Auto Detect', 'ចាប់ Link ស្វ័យប្រវត្តិ', Switch(value: _autoDetect, onChanged: (v) => setState(() => _autoDetect = v), activeThumbColor: const Color(0xFF7C3AED))),
          _settingRow('Notifications', 'ជូនដំណឹងពេល Download', Switch(value: _notifications, onChanged: (v) => setState(() => _notifications = v), activeThumbColor: const Color(0xFF7C3AED))),
          _settingRow(
            'Video Quality',
            'ជ្រើស Quality',
            DropdownButton<String>(
              value: _quality,
              dropdownColor: const Color(0xFF1A1A35),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              underline: const SizedBox(),
              onChanged: (v) => setState(() => _quality = v!),
              items: ['Auto', '4K', '1080p', '720p', '480p', '360p']
                  .map((q) => DropdownMenuItem(value: q, child: Text(q)))
                  .toList(),
            ),
          ),
          const Divider(color: Color(0xFF2A2A4A), height: 24),
          // ── Instagram Session ──
          const Text(
            '📸 Instagram Session ID',
            style: TextStyle(color: Color(0xFFA855F7), fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Instagram ត្រូវការ session cookie ដើម្បី download\n'
            'យក sessionid ពី Chrome: F12 → Application → Cookies → instagram.com',
            style: TextStyle(color: Color(0xFF888AAA), fontSize: 11, height: 1.5),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _igController,
            obscureText: _obscure,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Paste Instagram sessionid here...',
              hintStyle: const TextStyle(color: Color(0xFF555577), fontSize: 11),
              filled: true,
              fillColor: const Color(0xFF0D0D1A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: const Color(0xFF7C3AED).withValues(alpha: 0.4)),
              ),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 18),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveSession,
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('Save & Close'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _settingRow(String title, String sub, Widget trailing) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                Text(sub, style: const TextStyle(color: Color(0xFF888AAA), fontSize: 10)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class AnimatedHeangTitle extends StatefulWidget {
  const AnimatedHeangTitle({super.key});

  @override
  State<AnimatedHeangTitle> createState() => _AnimatedHeangTitleState();
}

class _AnimatedHeangTitleState extends State<AnimatedHeangTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 4.0, end: 14.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                      blurRadius: _glowAnimation.value,
                      spreadRadius: _glowAnimation.value / 4,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  colors: const [
                    Color(0xFF7C3AED),
                    Color(0xFFA855F7),
                    Color(0xFFEC4899),
                    Color(0xFF7C3AED),
                  ],
                  transform: GradientRotation(_controller.value * 2 * 3.14159),
                ).createShader(bounds);
              },
              child: Text(
                'HEANG',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2.0,
                  shadows: [
                    Shadow(
                      color: const Color(0xFFA855F7).withValues(alpha: 0.8),
                      blurRadius: _glowAnimation.value / 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  colors: const [
                    Colors.white70,
                    Colors.white,
                    Colors.white70,
                  ],
                  stops: [
                    0.0,
                    _controller.value,
                    1.0,
                  ],
                ).createShader(bounds);
              },
              child: const Text(
                'FLOW',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                  letterSpacing: 2.0,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
