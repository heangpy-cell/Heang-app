import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _igController = TextEditingController();
  bool _obscure = true;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final sid = prefs.getString('ig_session_id') ?? '';
    _igController.text = sid;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ig_session_id', _igController.text.trim());
    setState(() => _saved = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _saved = false);
  }

  Future<void> _clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ig_session_id');
    _igController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Instagram session cleared')),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F22),
        foregroundColor: Colors.white,
        title: const Text('⚙️ Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Instagram Section ──
            _sectionHeader('📸 Instagram Download'),
            const SizedBox(height: 8),
            _infoCard(
              '🔑 Instagram ត្រូវការ Session ID ដើម្បី download video\n\n'
              'របៀបយក Session ID:\n'
              '1. បើក instagram.com ក្នុង Chrome PC\n'
              '2. Login account របស់អ្នក\n'
              '3. F12 → Application → Cookies → instagram.com\n'
              '4. Copy value នៃ "sessionid"\n'
              '5. Paste ក្នុងช่อng ខាងក្រោម',
            ),
            const SizedBox(height: 16),
            _label('Instagram Session ID'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _igController,
              obscureText: _obscure,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 1,
              decoration: InputDecoration(
                hintText: 'Paste sessionid cookie value here...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF7C3AED).withValues(alpha: 0.4)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF7C3AED).withValues(alpha: 0.4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white54, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    IconButton(
                      icon: const Icon(Icons.paste_rounded, color: Colors.white54, size: 20),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          _igController.text = data!.text!.trim();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: Icon(_saved ? Icons.check : Icons.save_rounded, size: 18),
                    label: Text(_saved ? 'Saved! ✅' : 'Save Session ID'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _saved ? Colors.green : const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
            const Divider(color: Color(0xFF2A2A4A)),
            const SizedBox(height: 20),

            // ── About ──
            _sectionHeader('ℹ️ About'),
            const SizedBox(height: 8),
            _infoCard('LINK GRAB v1.0.0\nDownload videos from TikTok, YouTube, Facebook, Instagram, Telegram & more.'),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFFA855F7),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      );

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      );

  Widget _infoCard(String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.6),
        ),
      );
}
