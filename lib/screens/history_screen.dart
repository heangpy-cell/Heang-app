import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/download_provider.dart';
import '../models/download_item.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filterStatus = 'All'; // All | completed | failed | downloading

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Consumer<DownloadProvider>(
          builder: (_, provider, __) {
            var items = provider.historyItems.toList();
            if (_filterStatus != 'All') {
              items = items.where((i) => i.status.name == _filterStatus).toList();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        colors: [Colors.white, Color(0xFFC4B5FD)],
                      ).createShader(b),
                      child: const Text('HISTORY',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 2)),
                    ),
                    if (items.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _confirmClear(context, provider),
                        icon: const Icon(Icons.delete_sweep_rounded,
                            size: 16, color: Color(0xFFA855F7)),
                        label: const Text('Clear All',
                            style: TextStyle(
                                color: Color(0xFFA855F7), fontSize: 12)),
                      ),
                  ],
                ),

                // Filter chips
                const SizedBox(height: 12),
                SizedBox(
                  height: 30,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _chip('All', 'ទាំងអស់', const Color(0xFF7C3AED)),
                      const SizedBox(width: 8),
                      _chip('completed', 'ជោគជ័យ', Colors.greenAccent),
                      const SizedBox(width: 8),
                      _chip('failed', 'បរាជ័យ', Colors.redAccent),
                      const SizedBox(width: 8),
                      _chip('downloading', 'កំពុង', const Color(0xFFA855F7)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                if (items.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: const Color(0xFF13132A),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF7C3AED)
                                      .withValues(alpha: 0.2)),
                            ),
                            child: const Icon(Icons.history_rounded,
                                color: Color(0xFF4A4A6A), size: 56),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _filterStatus == 'All'
                                ? 'History ទទេ'
                                : 'គ្មាន $_filterStatus',
                            style: const TextStyle(
                                color: Color(0xFF888AAA), fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final item = items[i];
                        return _HistoryTile(item: item);
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _chip(String value, String label, Color color) {
    final selected = _filterStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.25) : const Color(0xFF13132A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? color : const Color(0xFF888AAA),
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _confirmClear(BuildContext context, DownloadProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF13132A),
        title: const Text('លុប History ទាំងអស់?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('History Download ទាំងអស់នឹងត្រូវបានលុប',
            style: TextStyle(color: Color(0xFF888AAA), fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('បោះបង់',
                style: TextStyle(color: Color(0xFF888AAA))),
          ),
          TextButton(
            onPressed: () {
              provider.clearHistory();
              Navigator.pop(context);
            },
            child: const Text('លុប',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final DownloadItem item;
  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final statusColor = item.status == DownloadStatus.completed
        ? Colors.greenAccent
        : item.status == DownloadStatus.failed
            ? Colors.redAccent
            : item.status == DownloadStatus.downloading
                ? const Color(0xFFA855F7)
                : Colors.orangeAccent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF13132A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: item.platformColor.withValues(alpha: 0.15),
            ),
            child: item.thumbnail != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(item.thumbnail!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                            Icons.video_library_rounded,
                            color: item.platformColor,
                            size: 22)),
                  )
                : Icon(Icons.video_library_rounded,
                    color: item.platformColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title ?? item.platform,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.platform} • ${_formatDate(item.createdAt)}',
                  style: const TextStyle(
                      color: Color(0xFF888AAA), fontSize: 10),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusLabel(item.status),
              style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

  String _statusLabel(DownloadStatus s) {
    switch (s) {
      case DownloadStatus.completed: return '✅ ជោគជ័យ';
      case DownloadStatus.failed: return '❌ បរាជ័យ';
      case DownloadStatus.downloading: return '⬇️ Download';
      case DownloadStatus.paused: return '⏸ ផ្អាក';
      case DownloadStatus.fetching: return '🔍 ស្វែងរក';
    }
  }
}
