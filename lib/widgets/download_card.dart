import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/download_item.dart';
import '../providers/download_provider.dart';

class DownloadCard extends StatelessWidget {
  final DownloadItem item;
  const DownloadCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, provider, __) {
        final isFetching = item.status == DownloadStatus.fetching;
        final isPaused   = item.status == DownloadStatus.paused;
        final isFailed   = item.status == DownloadStatus.failed;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF13132A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isFailed
                  ? Colors.redAccent.withValues(alpha: 0.4)
                  : isPaused
                      ? Colors.orangeAccent.withValues(alpha: 0.3)
                      : const Color(0xFF7C3AED).withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Thumbnail / Icon
                  _buildThumb(),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title ?? item.platform,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isFetching
                              ? '🔍 ស្វែងរក Link...'
                              : isPaused
                                  ? '⏸ ផ្អាក...'
                                  : isFailed
                                      ? '❌ ${item.errorMessage ?? 'Error'}'
                                      : item.speedMBps > 0
                                          ? '⬇️ ${item.speedMBps.toStringAsFixed(1)} MB/s'
                                          : '⬇️ កំពុង Download...',
                          style: TextStyle(
                            color: isFailed
                                ? Colors.redAccent
                                : isPaused
                                    ? Colors.orangeAccent
                                    : isFetching
                                        ? const Color(0xFFA855F7)
                                        : const Color(0xFF888AAA),
                            fontSize: 10,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Controls
                  Row(
                    children: [
                      if (isFailed)
                        // Retry button
                        _ControlBtn(
                          color: Colors.greenAccent.withValues(alpha: 0.8),
                          icon: Icons.refresh_rounded,
                          onTap: () => provider.retryDownload(item),
                        )
                      else
                        _ControlBtn(
                          color: isPaused
                              ? Colors.orangeAccent
                              : const Color(0xFF7C3AED),
                          icon: isPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          onTap: () => provider.togglePause(item),
                        ),
                      const SizedBox(width: 6),
                      _ControlBtn(
                        color: const Color(0xFF374151),
                        icon: Icons.stop_rounded,
                        onTap: () => provider.cancelDownload(item),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Progress bar
              if (isFetching)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 5,
                    backgroundColor:
                        const Color(0xFF7C3AED).withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFA855F7)),
                  ),
                )
              else if (!isFailed)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: item.progress),
                    duration: const Duration(milliseconds: 250),
                    builder: (_, value, __) => LinearProgressIndicator(
                      value: value,
                      minHeight: 5,
                      backgroundColor:
                          const Color(0xFF7C3AED).withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isPaused
                            ? Colors.orangeAccent
                            : const Color(0xFFA855F7),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 6),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isFetching
                        ? 'ស្វែងរក...'
                        : isFailed
                            ? 'ចុច 🔄 Retry'
                            : '${(item.progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: isFailed ? Colors.redAccent.withValues(alpha: 0.8) : const Color(0xFF888AAA),
                      fontSize: 10,
                    ),
                  ),
                  if (!isFetching && !isFailed && item.totalMB > 0)
                    Text(
                      '${item.downloadedMB.toStringAsFixed(1)} / ${item.totalMB.toStringAsFixed(1)} MB',
                      style: const TextStyle(
                          color: Color(0xFF888AAA), fontSize: 10),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThumb() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: [
            item.platformColor.withValues(alpha: 0.5),
            item.platformColor.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: item.thumbnail != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                item.thumbnail!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _platformIcon(),
              ),
            )
          : _platformIcon(),
    );
  }

  Widget _platformIcon() {
    return Icon(
      Icons.video_library_rounded,
      color: item.platformColor == const Color(0xFF000000)
          ? Colors.white70
          : item.platformColor,
      size: 22,
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _ControlBtn({required this.color, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 30,
        height: 30,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}
