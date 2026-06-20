import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_item.dart';
import '../services/download_service.dart';
import '../utils/platform_utils.dart';
import '../utils/notification_service.dart';

class DownloadProvider extends ChangeNotifier {
  final DownloadService _service = DownloadService();

  final List<DownloadItem> _activeDownloads = [];
  final List<DownloadItem> _completedDownloads = [];
  final List<DownloadItem> _historyItems = [];
  final Map<String, CancelToken> _cancelTokens = {};

  bool _isLoaded = false;

  List<DownloadItem> get activeDownloads => List.unmodifiable(_activeDownloads);
  List<DownloadItem> get completedDownloads => List.unmodifiable(_completedDownloads);
  List<DownloadItem> get historyItems => List.unmodifiable(_historyItems);

  // ── Platform utils (ប្រើ PlatformUtils — លែង duplicate) ──
  String detectPlatform(String url) => PlatformUtils.detectPlatform(url);
  Color colorFor(String platform) => PlatformUtils.colorFor(platform);

  // ── Load ពី SharedPreferences (ហៅពី main.dart) ──
  Future<void> loadFromPrefs() async {
    if (_isLoaded) return;
    _isLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load completed downloads (check file still exists)
      final completedRaw = prefs.getString('completed_downloads');
      if (completedRaw != null) {
        final items = DownloadItem.decodeList(completedRaw);
        for (final item in items) {
          if (item.filePath != null && await File(item.filePath!).exists()) {
            _completedDownloads.add(item);
          }
        }
      }

      // Load history (last 100)
      final historyRaw = prefs.getString('history_items');
      if (historyRaw != null) {
        _historyItems.addAll(DownloadItem.decodeList(historyRaw));
      }

      notifyListeners();
    } catch (_) {}
  }

  // ── Save ទៅ SharedPreferences ──
  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'completed_downloads',
        DownloadItem.encodeList(_completedDownloads),
      );
      // Save latest 100 history items
      await prefs.setString(
        'history_items',
        DownloadItem.encodeList(_historyItems.take(100).toList()),
      );
    } catch (_) {}
  }

  // ── Bulk Download ពី TikTok Profile ──
  Future<void> startBulkDownload(
    List<FetchResult> videos,
    String platform,
  ) async {
    for (int i = 0; i < videos.length; i++) {
      final v = videos[i];
      if (!v.success || v.directUrl == null) continue;

      final color = PlatformUtils.colorFor(platform);
      final item = DownloadItem(
        id: '${DateTime.now().millisecondsSinceEpoch}_$i',
        url: v.directUrl!,
        platform: platform,
        platformColor: color,
        createdAt: DateTime.now(),
        status: DownloadStatus.fetching,
        title: v.title,
        thumbnail: v.thumbnail,
      );

      _activeDownloads.add(item);
      _historyItems.insert(0, item);
      notifyListeners();

      // Download ម្ដងមួយ (Sequential)
      await _runDownloadWithDirectUrl(item, v.directUrl!);
    }
  }

  // ── Bulk Download ពី ReelShort ──
  Future<void> startReelShortBulkDownload(
    List<ReelShortEpisode> episodes,
    String seriesTitle,
  ) async {
    for (int i = 0; i < episodes.length; i++) {
      final ep = episodes[i];
      final platform = PlatformUtils.detectPlatform(ep.url);
      final color = PlatformUtils.colorFor(platform);

      final item = DownloadItem(
        id: '${DateTime.now().millisecondsSinceEpoch}_rs_$i',
        url: ep.url,
        platform: platform,
        platformColor: color,
        createdAt: DateTime.now(),
        status: DownloadStatus.fetching,
        title: '$seriesTitle - Episode ${ep.episodeNumber}',
      );

      _activeDownloads.add(item);
      _historyItems.insert(0, item);
      notifyListeners();

      // Download ម្ដងមួយ (Sequential)
      await _runDownload(item);
    }
  }

  Future<void> _runDownloadWithDirectUrl(
      DownloadItem item, String directUrl) async {
    item.status = DownloadStatus.downloading;
    notifyListeners();

    final cancelToken = CancelToken();
    _cancelTokens[item.id] = cancelToken;
    final fileName = _service.generateFileName(item.platform, directUrl);

    try {
      final filePath = await _service.downloadFile(
        url: directUrl,
        fileName: fileName,
        cancelToken: cancelToken,
        onProgress: (progress, downloadedMB, totalMB, speedMBps) {
          item.progress = progress;
          item.downloadedMB = downloadedMB;
          item.totalMB = totalMB;
          item.speedMBps = speedMBps;
          notifyListeners();
        },
      );
      if (filePath != null) {
        item.progress = 1.0;
        item.status = DownloadStatus.completed;
        item.filePath = filePath;
        item.fileSizeBytes = (item.totalMB * 1024 * 1024).round();
        _cancelTokens.remove(item.id);
        await Future.delayed(const Duration(milliseconds: 300));
        _activeDownloads.remove(item);
        _completedDownloads.insert(0, item);
        notifyListeners();
        await _saveToPrefs();
      }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      item.status = DownloadStatus.failed;
      item.errorMessage = 'Error: $e';
      _cancelTokens.remove(item.id);
      _activeDownloads.remove(item);
      notifyListeners();
    }
  }

  // ── ចាប់ផ្ដើម Download ──
  Future<void> startDownload(String url) async {
    final platform = detectPlatform(url);
    final color = PlatformUtils.colorFor(platform);

    final item = DownloadItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: url,
      platform: platform,
      platformColor: color,
      createdAt: DateTime.now(),
      status: DownloadStatus.fetching,
    );

    _activeDownloads.add(item);
    _historyItems.insert(0, item);
    notifyListeners();

    await _runDownload(item);
  }

  // ── Retry Download ពេល Failed ──
  Future<void> retryDownload(DownloadItem item) async {
    item.status = DownloadStatus.fetching;
    item.progress = 0;
    item.downloadedMB = 0;
    item.totalMB = 0;
    item.speedMBps = 0;
    item.errorMessage = null;

    if (!_activeDownloads.contains(item)) {
      _activeDownloads.add(item);
    }
    notifyListeners();

    await _runDownload(item);
  }

  // ── Core Download Logic ──
  Future<void> _runDownload(DownloadItem item) async {
    // Step 1: Fetch direct URL
    final fetchResult = await _service.fetchDirectUrl(item.url);

    if (!fetchResult.success || fetchResult.directUrl == null) {
      item.status = DownloadStatus.failed;
      item.errorMessage = fetchResult.error ?? 'មិនអាច Fetch URL បាន';
      _activeDownloads.remove(item);
      notifyListeners();
      NotificationService.showError(item.platform, item.errorMessage!);
      await _saveToPrefs();
      return;
    }

    item.title = fetchResult.title;
    item.thumbnail = fetchResult.thumbnail;
    item.status = DownloadStatus.downloading;
    notifyListeners();

    // Step 2: Download file
    final cancelToken = CancelToken();
    _cancelTokens[item.id] = cancelToken;
    final fileName = _service.generateFileName(item.platform, fetchResult.directUrl!);

    try {
      final filePath = await _service.downloadFile(
        url: fetchResult.directUrl!,
        fileName: fileName,
        cancelToken: cancelToken,
        onProgress: (progress, downloadedMB, totalMB, speedMBps) {
          item.progress = progress;
          item.downloadedMB = downloadedMB;
          item.totalMB = totalMB;
          item.speedMBps = speedMBps;
          notifyListeners();
        },
      );

      if (filePath != null) {
        item.progress = 1.0;
        item.status = DownloadStatus.completed;
        item.filePath = filePath;
        item.fileSizeBytes = (item.totalMB * 1024 * 1024).round();
        _cancelTokens.remove(item.id);

        await Future.delayed(const Duration(milliseconds: 500));
        _activeDownloads.remove(item);
        _completedDownloads.insert(0, item);
        notifyListeners();

        // ជូនដំណឹង
        NotificationService.showSuccess(
          item.platform,
          item.title ?? item.platform,
        );
        await _saveToPrefs();
      }
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        return; // Cancel ធម្មតា
      }
      item.status = DownloadStatus.failed;
      item.errorMessage = 'Download Error: $e';
      _cancelTokens.remove(item.id);
      _activeDownloads.remove(item);
      notifyListeners();
      NotificationService.showError(item.platform, item.errorMessage!);
    }
  }

  // ── Pause / Resume ──
  void togglePause(DownloadItem item) {
    if (item.status == DownloadStatus.downloading) {
      item.status = DownloadStatus.paused;
      _cancelTokens[item.id]?.cancel('Paused');
      _cancelTokens.remove(item.id);
      notifyListeners();
    } else if (item.status == DownloadStatus.paused) {
      item.status = DownloadStatus.fetching;
      item.progress = 0;
      item.downloadedMB = 0;
      notifyListeners();
      _runDownload(item);
    }
  }

  // ── Cancel Download ──
  void cancelDownload(DownloadItem item) {
    _cancelTokens[item.id]?.cancel('Cancelled by user');
    _cancelTokens.remove(item.id);
    _activeDownloads.remove(item);
    _historyItems.remove(item);
    notifyListeners();
  }

  // ── Delete ពី Completed List ──
  void deleteCompleted(DownloadItem item) {
    _completedDownloads.remove(item);
    notifyListeners();
    _saveToPrefs();
  }

  // ── Clear History ──
  void clearHistory() {
    _historyItems.clear();
    notifyListeners();
    _saveToPrefs();
  }

  @override
  void dispose() {
    for (final token in _cancelTokens.values) {
      token.cancel('App disposed');
    }
    super.dispose();
  }
}
