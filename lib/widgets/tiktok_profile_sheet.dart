import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/download_service.dart';
import '../providers/download_provider.dart';

class TikTokProfileSheet extends StatefulWidget {
  final String profileUrl;

  const TikTokProfileSheet({super.key, required this.profileUrl});

  @override
  State<TikTokProfileSheet> createState() => _TikTokProfileSheetState();
}

class _TikTokProfileSheetState extends State<TikTokProfileSheet> {
  final DownloadService _service = DownloadService();
  bool _loading = true;
  String? _error;
  TikTokProfileResult? _profileData;
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _service.fetchTikTokProfile(widget.profileUrl, maxVideos: 2000);
      if (res.success) {
        setState(() {
          _profileData = res;
          _loading = false;
          // Select all by default
          for (int i = 0; i < res.videos.length; i++) {
            _selectedIndices.add(i);
          }
        });
      } else {
        setState(() {
          _error = res.error ?? 'មិនអាចទាញទិន្នន័យ Profile បានទេ';
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
        for (int i = 0; i < (_profileData?.videos.length ?? 0); i++) {
          _selectedIndices.add(i);
        }
      } else {
        _selectedIndices.clear();
      }
    });
  }

  void _toggleVideo(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _startDownload() {
    if (_profileData == null || _selectedIndices.isEmpty) return;

    final selectedVideos = _selectedIndices
        .map((idx) => _profileData!.videos[idx])
        .toList();

    context.read<DownloadProvider>().startBulkDownload(selectedVideos, 'TikTok');
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '⬇️ កំពុងទាញយកវីដេអូចំនួន ${selectedVideos.length} ក្នុង Background!',
          style: const TextStyle(fontFamily: 'Roboto'),
        ),
        backgroundColor: const Color(0xFF2D1B69),
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
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA855F7)),
            ),
            SizedBox(height: 16),
            Text(
              'កំពុងស្កេន Profile...',
              style: TextStyle(color: Color(0xFF888AAA), fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('ព្យាយាមម្ដងទៀត', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final data = _profileData!;
    final allSelected = _selectedIndices.length == data.videos.length;

    return Column(
      children: [
        // Profile Info Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFF13132A),
                backgroundImage: data.avatar != null ? NetworkImage(data.avatar!) : null,
                child: data.avatar == null
                    ? const Icon(Icons.person, color: Colors.white54, size: 30)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (data.handle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        data.handle!,
                        style: const TextStyle(
                          color: Color(0xFF888AAA),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${data.videos.length} វីដេអូ',
                    style: const TextStyle(
                      color: Color(0xFFA855F7),
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
                'ជ្រើសរើសវីដេអូដើម្បីទាញយក',
                style: TextStyle(
                  color: Color(0xFF888AAA),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton.icon(
                onPressed: () => _toggleSelectAll(!allSelected),
                icon: Icon(
                  allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                  size: 16,
                  color: const Color(0xFFA855F7),
                ),
                label: Text(
                  allSelected ? 'ដកជ្រើសទាំងអស់' : 'ជ្រើសទាំងអស់',
                  style: const TextStyle(color: Color(0xFFA855F7), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Video Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            itemCount: data.videos.length,
            itemBuilder: (context, index) {
              final video = data.videos[index];
              final isSelected = _selectedIndices.contains(index);

              return GestureDetector(
                onTap: () => _toggleVideo(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFA855F7)
                          : const Color(0xFF7C3AED).withValues(alpha: 0.15),
                      width: isSelected ? 2 : 1,
                    ),
                    color: const Color(0xFF13132A),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Thumbnail
                      if (video.thumbnail != null)
                        Image.network(
                          video.thumbnail!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.movie_rounded, color: Colors.white24),
                          ),
                        )
                      else
                        const Center(
                          child: Icon(Icons.movie_rounded, color: Colors.white24),
                        ),

                      // Overlay Gradient
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black54,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Selection Checkbox
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? const Color(0xFFA855F7)
                                : Colors.black45,
                            border: Border.all(color: Colors.white24),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: isSelected ? Colors.white : Colors.transparent,
                          ),
                        ),
                      ),

                      // Caption text (first few words)
                      if (video.title != null && video.title!.isNotEmpty)
                        Positioned(
                          bottom: 6,
                          left: 6,
                          right: 6,
                          child: Text(
                            video.title!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
                  backgroundColor: const Color(0xFF7C3AED),
                  disabledBackgroundColor: const Color(0xFF13132A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                  elevation: _selectedIndices.isEmpty ? 0 : 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.download_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'ទាញយកទាំង ${_selectedIndices.length} វីដេអូ',
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
}
