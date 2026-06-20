import 'dart:convert';
import 'package:flutter/material.dart';

enum DownloadStatus { fetching, downloading, paused, completed, failed }

class DownloadItem {
  final String id;
  final String url;
  final String platform;
  final Color platformColor;
  double progress;
  double downloadedMB;
  double totalMB;
  double speedMBps;       // ល្បឿន Download (MB/s)
  DownloadStatus status;
  final DateTime createdAt;

  String? title;
  String? thumbnail;
  String? filePath;
  String? errorMessage;
  int? fileSizeBytes;     // ទំហំ File ពិតប្រាកដ

  DownloadItem({
    required this.id,
    required this.url,
    required this.platform,
    required this.platformColor,
    this.progress = 0,
    this.downloadedMB = 0,
    this.totalMB = 0,
    this.speedMBps = 0,
    this.status = DownloadStatus.fetching,
    required this.createdAt,
    this.title,
    this.thumbnail,
    this.filePath,
    this.errorMessage,
    this.fileSizeBytes,
  });

  // ── JSON Serialization ── ​ (សម្រាប់ Persistence)
  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'platform': platform,
        'platformColor': platformColor.toARGB32(),
        'progress': progress,
        'downloadedMB': downloadedMB,
        'totalMB': totalMB,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'title': title,
        'thumbnail': thumbnail,
        'filePath': filePath,
        'errorMessage': errorMessage,
        'fileSizeBytes': fileSizeBytes,
      };

  factory DownloadItem.fromJson(Map<String, dynamic> json) => DownloadItem(
        id: json['id'] as String,
        url: json['url'] as String,
        platform: json['platform'] as String,
        platformColor: Color(json['platformColor'] as int),
        progress: (json['progress'] as num).toDouble(),
        downloadedMB: (json['downloadedMB'] as num).toDouble(),
        totalMB: (json['totalMB'] as num).toDouble(),
        status: DownloadStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => DownloadStatus.completed,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        title: json['title'] as String?,
        thumbnail: json['thumbnail'] as String?,
        filePath: json['filePath'] as String?,
        errorMessage: json['errorMessage'] as String?,
        fileSizeBytes: json['fileSizeBytes'] as int?,
      );

  /// Encode list → JSON string
  static String encodeList(List<DownloadItem> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  /// Decode JSON string → list
  static List<DownloadItem> decodeList(String raw) {
    final list = jsonDecode(raw) as List;
    return list.map((e) => DownloadItem.fromJson(e as Map<String, dynamic>)).toList();
  }
}
