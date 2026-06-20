import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/download_provider.dart';
import '../widgets/saved_card.dart';

class MyFilesScreen extends StatefulWidget {
  const MyFilesScreen({super.key});
  @override
  State<MyFilesScreen> createState() => _MyFilesScreenState();
}

class _MyFilesScreenState extends State<MyFilesScreen> {
  String _filterPlatform = 'All';
  String _sortBy = 'newest'; // newest | oldest | size

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Consumer<DownloadProvider>(
          builder: (_, provider, __) {
            var items = provider.completedDownloads.toList();

            // Filter
            if (_filterPlatform != 'All') {
              items = items.where((i) => i.platform == _filterPlatform).toList();
            }

            // Sort
            switch (_sortBy) {
              case 'oldest':
                items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                break;
              case 'size':
                items.sort((a, b) =>
                    (b.fileSizeBytes ?? 0).compareTo(a.fileSizeBytes ?? 0));
                break;
              default: // newest
                items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            }

            // Unique platforms for filter chips
            final platforms = ['All',
              ...provider.completedDownloads.map((e) => e.platform).toSet()
            ];

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
                      child: const Text('MY FILES',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 2)),
                    ),
                    Row(
                      children: [
                        // Sort menu
                        PopupMenuButton<String>(
                          onSelected: (v) => setState(() => _sortBy = v),
                          color: const Color(0xFF1A1A35),
                          icon: const Icon(Icons.sort_rounded,
                              color: Color(0xFF888AAA), size: 20),
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'newest', child: Text('ថ្មីបំផុត', style: TextStyle(color: Colors.white, fontSize: 13))),
                            const PopupMenuItem(value: 'oldest', child: Text('ចាស់បំផុត', style: TextStyle(color: Colors.white, fontSize: 13))),
                            const PopupMenuItem(value: 'size', child: Text('ទំហំ (ធំ→តូច)', style: TextStyle(color: Colors.white, fontSize: 13))),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFF7C3AED)
                                    .withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '${items.length} ឯកសារ',
                            style: const TextStyle(
                                color: Color(0xFFA855F7),
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Platform filter chips
                if (platforms.length > 1) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 30,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: platforms.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final p = platforms[i];
                        final selected = _filterPlatform == p;
                        return GestureDetector(
                          onTap: () => setState(() => _filterPlatform = p),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF7C3AED)
                                  : const Color(0xFF13132A),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: selected
                                      ? const Color(0xFF7C3AED)
                                      : const Color(0xFF7C3AED)
                                          .withValues(alpha: 0.3)),
                            ),
                            child: Text(p,
                                style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xFF888AAA),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                        );
                      },
                    ),
                  ),
                ],

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
                            child: const Icon(Icons.folder_open_rounded,
                                color: Color(0xFF4A4A6A), size: 56),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _filterPlatform == 'All'
                                ? 'មិនទាន់មានឯកសារ'
                                : 'គ្មាន $_filterPlatform',
                            style: const TextStyle(
                                color: Color(0xFF888AAA), fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          const Text('Download វីដេអូ ហើយ ជួបនៅទីនេះ',
                              style: TextStyle(
                                  color: Color(0xFF4A4A6A), fontSize: 12)),
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
                      itemBuilder: (_, i) => SavedCard(item: items[i]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
