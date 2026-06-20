import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/download_item.dart';
import '../providers/download_provider.dart';

class SavedCard extends StatelessWidget {
  final DownloadItem item;
  const SavedCard({super.key, required this.item});

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

  String _formatSize(int? bytes) {
    if (bytes == null || bytes == 0) return '';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  Future<void> _openFile(BuildContext context) async {
    if (item.filePath == null) { _snack(context, '❌ រកមិនឃើញ File Path'); return; }
    final file = File(item.filePath!);
    if (!await file.exists()) {
      if (!context.mounted) return;
      _snack(context, '❌ File ត្រូវបានលុប');
      return;
    }
    final result = await OpenFilex.open(item.filePath!);
    if (!context.mounted) return;
    if (result.type != ResultType.done) {
      _snack(context, '⚠️ មិនអាចបើក: ${result.message}');
    }
  }

  Future<void> _shareFile(BuildContext context) async {
    if (item.filePath != null && await File(item.filePath!).exists()) {
      await Share.shareXFiles(
        [XFile(item.filePath!)],
        text: item.title ?? item.platform,
      );
    } else {
      await Share.share('${item.title ?? item.platform}\n${item.url}');
    }
  }

  Future<void> _copyUrl(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: item.url));
    if (!context.mounted) return;
    _snack(context, '📋 បានចម្លង URL!');
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF2D1B69),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = item.filePath != null;
    final sizeStr = _formatSize(item.fileSizeBytes);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF13132A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(colors: [
                item.platformColor.withValues(alpha: 0.5),
                item.platformColor.withValues(alpha: 0.1),
              ]),
            ),
            child: item.thumbnail != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      item.thumbnail!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.video_library_rounded,
                              color: item.platformColor, size: 22),
                    ),
                  )
                : Icon(Icons.video_library_rounded,
                    color: item.platformColor, size: 22),
          ),
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
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(_formatDate(item.createdAt),
                        style: const TextStyle(
                            color: Color(0xFF888AAA), fontSize: 10)),
                    if (sizeStr.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(sizeStr,
                            style: const TextStyle(
                                color: Color(0xFFA855F7), fontSize: 9)),
                      ),
                    ],
                  ],
                ),
                if (hasFile)
                  Text(
                    '📁 ${item.filePath!.split('/').last}',
                    style: const TextStyle(
                        color: Color(0xFF7C3AED), fontSize: 9),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Actions
          Column(
            children: [
              Row(
                children: [
                  _ActionBtn(
                    icon: Icons.play_arrow_rounded,
                    color: hasFile
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFF4A4A6A),
                    onTap: () => _openFile(context),
                  ),
                  const SizedBox(width: 4),
                  _ActionBtn(
                    icon: Icons.share_rounded,
                    color: const Color(0xFF1A3A4A),
                    onTap: () => _shareFile(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _ActionBtn(
                    icon: Icons.copy_rounded,
                    color: const Color(0xFF1A2A1A),
                    onTap: () => _copyUrl(context),
                  ),
                  const SizedBox(width: 4),
                  _ActionBtn(
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFF2A1A1A),
                    onTap: () => context
                        .read<DownloadProvider>()
                        .deleteCompleted(item),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: color,
          border: Border.all(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: Colors.white, size: 15),
      ),
    );
  }
}
