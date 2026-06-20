import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/download_service.dart';
import '../providers/download_provider.dart';

class ReelShortSeriesSheet extends StatefulWidget {
  final String seriesUrl;

  const ReelShortSeriesSheet({super.key, required this.seriesUrl});

  @override
  State<ReelShortSeriesSheet> createState() => _ReelShortSeriesSheetState();
}

class _ReelShortSeriesSheetState extends State<ReelShortSeriesSheet> {
  final DownloadService _service = DownloadService();
  bool _loading = true;
  String? _error;
  ReelShortSeriesResult? _seriesData;
  final Set<int> _selectedIndices = {};

  bool _tgLoading = false;
  String? _tgError;
  String? _tgPhoneHash;
  bool _tgCodeSent = false;
  bool _tgPasswordNeeded = false;

  final TextEditingController _tgPhoneController = TextEditingController();
  final TextEditingController _tgCodeController = TextEditingController();
  final TextEditingController _tgPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSeries();
  }

  @override
  void dispose() {
    _tgPhoneController.dispose();
    _tgCodeController.dispose();
    _tgPasswordController.dispose();
    super.dispose();
  }

  Future<void> _fetchSeries() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final isNetShort = widget.seriesUrl.contains('netshort');
      final isDramaBox = widget.seriesUrl.contains('dramabox') ||
          widget.seriesUrl.contains('dramabite');
      final isTelegram = widget.seriesUrl.contains('t.me') ||
          widget.seriesUrl.contains('telegram');
      final res = isNetShort
          ? await _service.fetchNetShortSeries(widget.seriesUrl)
          : isDramaBox
              ? await _service.fetchDramaBoxSeries(widget.seriesUrl)
              : isTelegram
                  ? await _service.fetchTelegramSeries(widget.seriesUrl)
                  : await _service.fetchReelShortSeries(widget.seriesUrl);
      if (res.success) {
        setState(() {
          _seriesData = res;
          _loading = false;
          // Select all by default
          for (int i = 0; i < res.episodes.length; i++) {
            _selectedIndices.add(i);
          }
        });
      } else {
        setState(() {
          _error = res.error ?? 'មិនអាចទាញទិន្នន័យ Series បានទេ';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  void _toggleSelectAll(bool select) {
    setState(() {
      if (select) {
        for (int i = 0; i < (_seriesData?.episodes.length ?? 0); i++) {
          _selectedIndices.add(i);
        }
      } else {
        _selectedIndices.clear();
      }
    });
  }

  void _toggleEpisode(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _startDownload() {
    if (_seriesData == null || _selectedIndices.isEmpty) return;

    final selectedEpisodes =
        _selectedIndices.map((idx) => _seriesData!.episodes[idx]).toList();

    context.read<DownloadProvider>().startReelShortBulkDownload(
          selectedEpisodes,
          _seriesData!.title,
        );
    Navigator.pop(context);

    final isNetShort = widget.seriesUrl.contains('netshort');
    final isDramaBox = widget.seriesUrl.contains('dramabox') ||
        widget.seriesUrl.contains('dramabite');
    final isTelegram = widget.seriesUrl.contains('t.me') ||
        widget.seriesUrl.contains('telegram');
    final label = isNetShort
        ? 'NetShort'
        : isDramaBox
            ? 'DramaBox'
            : isTelegram
                ? 'Telegram'
                : 'ReelShort';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '⬇️ កំពុងទាញយក $label ចំនួន ${selectedEpisodes.length} ភាគក្នុង Background!',
          style: const TextStyle(fontFamily: 'Roboto'),
        ),
        backgroundColor: const Color(0xFF6366F1),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          children: [
            // Handle Bar
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
            SizedBox(height: 16),
            Text(
              'កំពុងស្កេន Episodes...',
              style: TextStyle(color: Color(0xFF888AAA), fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      if (_error == 'auth_required') {
        return _buildTelegramAuth();
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchSeries,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('ព្យាយាមម្ដងទៀត',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final data = _seriesData!;
    final allSelected = _selectedIndices.length == data.episodes.length;

    return Column(
      children: [
        // Series Info Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 55,
                  height: 75,
                  color: const Color(0xFF13132A),
                  child: data.cover != null && data.cover!.isNotEmpty
                      ? Image.network(
                          data.cover!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.movie_rounded,
                            color: Colors.white54,
                            size: 24,
                          ),
                        )
                      : const Icon(
                          Icons.movie_rounded,
                          color: Colors.white54,
                          size: 24,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.seriesUrl.contains('netshort')
                          ? 'NetShort Series'
                          : (widget.seriesUrl.contains('dramabox') ||
                                  widget.seriesUrl.contains('dramabite'))
                              ? 'DramaBox Series'
                              : (widget.seriesUrl.contains('t.me') ||
                                      widget.seriesUrl.contains('telegram'))
                                  ? 'Telegram Channel/Group'
                                  : 'ReelShort Series',
                      style: const TextStyle(
                        color: Color(0xFF6366F1),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${data.episodes.length} ភាគ',
                    style: const TextStyle(
                      color: Color(0xFF818CF8),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'រកឃើញ',
                    style: TextStyle(color: Color(0xFF888AAA), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Controls bar (Select All / Deselect All)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ជ្រើសរើសភាគដើម្បីទាញយក',
                style: TextStyle(
                  color: Color(0xFF888AAA),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton.icon(
                onPressed: () => _toggleSelectAll(!allSelected),
                icon: Icon(
                  allSelected
                      ? Icons.deselect_rounded
                      : Icons.select_all_rounded,
                  size: 16,
                  color: const Color(0xFF818CF8),
                ),
                label: Text(
                  allSelected ? 'ដកជ្រើសទាំងអស់' : 'ជ្រើសទាំងអស់',
                  style:
                      const TextStyle(color: Color(0xFF818CF8), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Episode Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemCount: data.episodes.length,
            itemBuilder: (context, index) {
              final ep = data.episodes[index];
              final isSelected = _selectedIndices.contains(index);

              return GestureDetector(
                onTap: () => _toggleEpisode(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF6366F1)
                          : const Color(0xFF7C3AED).withValues(alpha: 0.15),
                      width: isSelected ? 2 : 1,
                    ),
                    color: isSelected
                        ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                        : const Color(0xFF13132A),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Episode number
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${ep.episodeNumber}',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF888AAA),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'EPISODE',
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF818CF8)
                                  : Colors.white24,
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),

                      // Checkmark overlay at top-right
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: isSelected
                              ? const Color(0xFF6366F1)
                              : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Download Button at bottom
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _selectedIndices.isEmpty ? null : _startDownload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  disabledBackgroundColor: const Color(0xFF13132A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.5),
                  elevation: _selectedIndices.isEmpty ? 0 : 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.download_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'ទាញយកទាំង ${_selectedIndices.length} ភាគ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _sendCode() async {
    final phone = _tgPhoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _tgError = 'សូមបញ្ចូលលេខទូរស័ព្ទ');
      return;
    }
    setState(() {
      _tgLoading = true;
      _tgError = null;
    });
    try {
      final res = await _service.verifyTelegramAuth(phone: phone);
      if (res['status'] == 'needs_code') {
        setState(() {
          _tgPhoneHash = res['phone_code_hash'];
          _tgCodeSent = true;
          _tgLoading = false;
        });
      } else if (res['status'] == 'error') {
        setState(() {
          _tgError = res['error'];
          _tgLoading = false;
        });
      } else {
        setState(() {
          _tgError = 'ឆ្លើយតបមិនរំពឹងទុកពី Proxy: ${res['status']}';
          _tgLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _tgError = 'Error: $e';
        _tgLoading = false;
      });
    }
  }

  Future<void> _submitCodeOrPassword() async {
    final phone = _tgPhoneController.text.trim();
    final code = _tgCodeController.text.trim();
    final password = _tgPasswordController.text.trim();

    if (!_tgPasswordNeeded && code.isEmpty) {
      setState(() => _tgError = 'សូមបញ្ចូលលេខកូដផ្ទៀងផ្ទាត់');
      return;
    }
    if (_tgPasswordNeeded && password.isEmpty) {
      setState(() => _tgError = 'សូមបញ្ចូលលេខកូដសម្ងាត់ 2FA');
      return;
    }

    setState(() {
      _tgLoading = true;
      _tgError = null;
    });

    try {
      final res = await _service.verifyTelegramAuth(
        phone: phone,
        code: code,
        phoneHash: _tgPhoneHash,
        password: password.isNotEmpty ? password : null,
      );

      if (res['status'] == 'ok') {
        setState(() {
          _tgLoading = false;
          _error = null;
        });
        _fetchSeries();
      } else if (res['status'] == 'needs_password') {
        setState(() {
          _tgPasswordNeeded = true;
          _tgLoading = false;
        });
      } else if (res['status'] == 'error') {
        setState(() {
          _tgError = res['error'];
          _tgLoading = false;
        });
      } else {
        setState(() {
          _tgError = 'ឆ្លើយតបមិនរំពឹងទុកពី Proxy: ${res['status']}';
          _tgLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _tgError = 'Error: $e';
        _tgLoading = false;
      });
    }
  }

  Widget _buildTelegramAuth() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          const Icon(
            Icons.send_rounded,
            color: Color(0xFF0088CC),
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'ភ្ជាប់គណនី Telegram',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Telegram ត្រូវការការ Login ដើម្បីទាញយកវីដេអូពី Private Channel/Group ឬ Public Channel ដែលការពារ។ ព័ត៌មាន Login របស់អ្នកត្រូវបានរក្សាទុកតែនៅលើកុំព្យូទ័ររបស់អ្នកប៉ុណ្ណោះ។',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          if (_tgError != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _tgError!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (!_tgCodeSent) ...[
            TextField(
              controller: _tgPhoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'លេខទូរស័ព្ទ (ឧទាហរណ៍៖ +85512345678)',
                labelStyle:
                    const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF13132A),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF6366F1)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _tgLoading ? null : _sendCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0088CC),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _tgLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'ផ្ញើលេខកូដ',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ] else ...[
            if (!_tgPasswordNeeded) ...[
              TextField(
                controller: _tgCodeController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'លេខកូដផ្ទៀងផ្ទាត់ (ផ្ញើទៅកម្មវិធី Telegram)',
                  labelStyle:
                      const TextStyle(color: Colors.white38, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF13132A),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                ),
              ),
            ] else ...[
              TextField(
                controller: _tgPasswordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'លេខកូដសម្ងាត់ 2FA (Two-Factor Password)',
                  labelStyle:
                      const TextStyle(color: Colors.white38, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF13132A),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _tgLoading
                        ? null
                        : () {
                            setState(() {
                              _tgCodeSent = false;
                              _tgPasswordNeeded = false;
                              _tgError = null;
                            });
                          },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('ត្រឡប់ក្រោយ',
                        style: TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _tgLoading ? null : _submitCodeOrPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0088CC),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _tgLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'ផ្ទៀងផ្ទាត់',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'បោះបង់',
              style: TextStyle(color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }
}
