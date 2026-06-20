import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/platform_utils.dart';
import 'webview_extractor_service.dart';

/// លទ្ធផលពេល Fetch URL
class FetchResult {
  final bool success;
  final String? directUrl;
  final String? title;
  final String? thumbnail;
  final String? error;

  FetchResult({
    required this.success,
    this.directUrl,
    this.title,
    this.thumbnail,
    this.error,
  });
}

/// លទ្ធផល TikTok Profile Fetch
class TikTokProfileResult {
  final String username;
  final String? handle;
  final String? avatar;
  final List<FetchResult> videos;
  final String? error;

  TikTokProfileResult({
    required this.username,
    this.handle,
    this.avatar,
    required this.videos,
    this.error,
  });

  bool get success => error == null && videos.isNotEmpty;
}

/// ម៉ូដែលសម្រាប់ ReelShort Series
class ReelShortSeriesResult {
  final String title;
  final String? cover;
  final List<ReelShortEpisode> episodes;
  final String? error;

  ReelShortSeriesResult({
    required this.title,
    this.cover,
    required this.episodes,
    this.error,
  });

  bool get success => error == null && episodes.isNotEmpty;
}

class ReelShortEpisode {
  final int episodeNumber;
  final String url;

  ReelShortEpisode({
    required this.episodeNumber,
    required this.url,
  });
}

class DownloadService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(minutes: 5),
  ));

  // ────────────────────────────────────────────────
  // ១. ស្ងែករក Direct URL ពី Social Media Link
  // ────────────────────────────────────────────────
  Future<FetchResult> fetchDirectUrl(String url) async {
    try {
      final platform = PlatformUtils.detectPlatform(url);

      switch (platform) {
        case 'TikTok':
          return await _fetchTikTok(url);
        case 'YouTube':
          return await _fetchYouTube(url);
        case 'Facebook':
          return await _fetchFacebook(url);
        case 'Instagram':
          return await _fetchInstagram(url);
        case 'ReelShort':
          return await _fetchReelShort(url);
        case 'NetShort':
          return await _fetchNetShort(url);
        case 'DramaBox':
          return await _fetchDramaBox(url);
        case 'Twitter':
          return await _fetchByCobalt(url);
        case 'Telegram':
          return await _fetchTelegram(url);
        default:
          return await _fetchGeneric(url);
      }
    } catch (e) {
      return FetchResult(success: false, error: 'Fetch Error: $e');
    }
  }

  // ────────────────────────────────────────────────
  // ២. TikTok — ប្រើ API tikwm.com (FREE)
  // ────────────────────────────────────────────────
  Future<FetchResult> _fetchTikTok(String url) async {
    try {
      final response = await _dio.get(
        'https://www.tikwm.com/api/',
        queryParameters: {'url': url, 'hd': 1},
      );

      final data = response.data;
      if (data['code'] == 0) {
        final videoData = data['data'];
        final hdUrl = videoData['hdplay'] ?? videoData['play'];
        return FetchResult(
          success: true,
          directUrl: hdUrl,
          title: videoData['title'] ?? 'TikTok Video',
          thumbnail: videoData['cover'],
        );
      }
      return FetchResult(success: false, error: 'TikTok API Error');
    } catch (e) {
      return FetchResult(success: false, error: 'TikTok: $e');
    }
  }

  // ────────────────────────────────────────────────
  // TikTok Profile — Fetch Video List ពី Profile
  // ────────────────────────────────────────────────
  Future<TikTokProfileResult> fetchTikTokProfile(
    String profileUrl, {
    int maxVideos = 50,
  }) async {
    final match =
        RegExp(r'tiktok\.com/@([^/?#\s]+)').firstMatch(profileUrl);
    if (match == null) {
      return TikTokProfileResult(
          username: '', videos: [], error: 'Invalid TikTok profile URL');
    }
    final username = match.group(1)!;

    // Fetch user info first
    String? avatar;
    String? nickname;
    try {
      final userResp = await _dio.get(
        'https://www.tikwm.com/api/user/info',
        queryParameters: {'unique_id': '@$username'},
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );
      final ud = userResp.data;
      if (ud is Map && ud['code'] == 0) {
        avatar = ud['data']?['user']?['avatarMedium']?.toString() ??
            ud['data']?['user']?['avatar_medium']?['url_list']
                    ?.first
                    ?.toString();
        nickname = ud['data']?['user']?['nickname']?.toString() ?? username;
      }
    } catch (_) {}

    final List<FetchResult> results = [];
    int cursor = 0;
    bool hasMore = true;

    while (hasMore && results.length < maxVideos) {
      try {
        final resp = await _dio.get(
          'https://www.tikwm.com/api/user/posts',
          queryParameters: {
            'unique_id': '@$username',
            'count': 20,
            'cursor': cursor,
            'hd': 1,
          },
          options: Options(receiveTimeout: const Duration(seconds: 15)),
        );
        final d = resp.data;
        if (d is! Map || d['code'] != 0) break;

        final videos = d['data']['videos'] as List? ?? [];
        if (videos.isEmpty) break;

        for (final v in videos) {
          final dlUrl =
              v['hdplay']?.toString() ?? v['play']?.toString();
          if (dlUrl != null) {
            results.add(FetchResult(
              success: true,
              directUrl: dlUrl,
              title: v['title']?.toString() ?? 'TikTok Video',
              thumbnail: v['cover']?.toString(),
            ));
          }
          if (results.length >= maxVideos) break;
        }

        final c = d['data']['cursor'];
        cursor = c is int ? c : int.tryParse(c.toString()) ?? 0;
        hasMore =
            d['data']['hasMore'] == true || d['data']['has_more'] == true;
        if (results.length >= maxVideos) break;
      } catch (_) {
        break;
      }
    }

    return TikTokProfileResult(
      username: nickname ?? username,
      handle: '@$username',
      avatar: avatar,
      videos: results,
    );
  }

  // ────────────────────────────────────────────────
  // ៣. YouTube — Multi-API Fallback Chain
  //    Layer 1: yt1s.com  (free yt-dlp wrapper)
  //    Layer 2: y2mate.guru (reliable public API)
  //    Layer 3: cobalt.tools v2 (official REST API)
  //    Layer 4: Invidious public instance (open-source)
  // ────────────────────────────────────────────────

  /// Load quality preference from SharedPreferences
  Future<String> _getYtQuality() async {
    final prefs = await SharedPreferences.getInstance();
    final q = prefs.getString('video_quality') ?? 'Auto';
    // Map UI quality labels → API quality values
    switch (q) {
      case '4K':    return '2160';
      case '1080p': return '1080';
      case '720p':  return '720';
      case '480p':  return '480';
      case '360p':  return '360';
      default:      return '720'; // Auto → default 720p
    }
  }

  Future<FetchResult> _fetchYouTube(String url) async {
    final quality = await _getYtQuality();

    // ── Layer 1: yt1s.com ──────────────────────────────────────
    try {
      final r1 = await _dio.post(
        'https://yt1s.com/api/ajaxSearch/index',
        data: {'q': url, 'vt': 'home'},
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {
            'Referer': 'https://yt1s.com/',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
          },
          validateStatus: (s) => s != null && s < 500,
          receiveTimeout: const Duration(seconds: 15),
          connectTimeout: const Duration(seconds: 10),
        ),
      );
      final d1 = r1.data;
      if (d1 is Map && d1['status'] == 'ok') {
        // Parse available formats — pick quality closest to user preference
        final links = d1['links'] as Map?;
        final mp4Links = links?['mp4'] as Map? ?? {};
        String? bestK;
        final targetQ = int.tryParse(quality) ?? 720;
        int bestDiff = 9999;
        for (final entry in mp4Links.entries) {
          final res = int.tryParse(entry.key.toString().replaceAll('p', ''));
          if (res == null) continue;
          final diff = (res - targetQ).abs();
          if (diff < bestDiff) {
            bestDiff = diff;
            bestK = entry.value['k']?.toString();
          }
        }
        if (bestK != null && d1['vid'] != null) {
          // Step 2: convert to get real URL
          final r2 = await _dio.post(
            'https://yt1s.com/api/ajaxConvert/convert',
            data: {'vid': d1['vid'], 'k': bestK},
            options: Options(
              contentType: 'application/x-www-form-urlencoded',
              headers: {'Referer': 'https://yt1s.com/'},
              validateStatus: (s) => s != null && s < 500,
              receiveTimeout: const Duration(seconds: 20),
            ),
          );
          final d2 = r2.data;
          if (d2 is Map && d2['status'] == 'ok' && d2['dlink'] != null) {
            return FetchResult(
              success: true,
              directUrl: d2['dlink'].toString(),
              title: d1['title']?.toString() ?? 'YouTube Video',
              thumbnail: d1['thumbnail']?.toString(),
            );
          }
        }
      }
    } catch (_) {}

    // ── Layer 2: y2mate.guru ───────────────────────────────────
    try {
      // Analyse URL first
      final r1 = await _dio.post(
        'https://www.y2mate.com/mates/analyzeV2/ajax',
        data: {'k_query': url, 'k_page': 'home', 'hl': 'en', 'q_auto': 0},
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {
            'Referer': 'https://www.y2mate.com/',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
          validateStatus: (s) => s != null && s < 500,
          receiveTimeout: const Duration(seconds: 15),
          connectTimeout: const Duration(seconds: 10),
        ),
      );
      final d1 = r1.data;
      if (d1 is Map && d1['status'] == 'ok') {
        final links = d1['links'] as Map?;
        final mp4 = links?['mp4'] as Map? ?? {};
        String? bestKey;
        int bestDiff = 9999;
        final targetQ = int.tryParse(quality) ?? 720;
        for (final entry in mp4.entries) {
          final res = int.tryParse(entry.key.toString().replaceAll('p', ''));
          if (res == null) continue;
          final diff = (res - targetQ).abs();
          if (diff < bestDiff && entry.value['k'] != null) {
            bestDiff = diff;
            bestKey = entry.value['k'].toString();
          }
        }
        if (bestKey != null && d1['vid'] != null) {
          final r2 = await _dio.post(
            'https://www.y2mate.com/mates/convertV2/index',
            data: {'vid': d1['vid'], 'k': bestKey},
            options: Options(
              contentType: 'application/x-www-form-urlencoded',
              headers: {'Referer': 'https://www.y2mate.com/'},
              validateStatus: (s) => s != null && s < 500,
              receiveTimeout: const Duration(seconds: 20),
            ),
          );
          final d2 = r2.data;
          if (d2 is Map && d2['status'] == 'ok' && d2['dlink'] != null) {
            return FetchResult(
              success: true,
              directUrl: d2['dlink'].toString(),
              title: d1['title']?.toString() ?? 'YouTube Video',
              thumbnail: d1['thumbnail']?.toString(),
            );
          }
        }
      }
    } catch (_) {}

    // ── Layer 3: cobalt.tools v2 REST API ─────────────────────
    // Uses new official spec: POST /
    final cobaltHosts = [
      'https://fox.kittycat.boo/',
      'https://api.cobalt.blackcat.sweeux.org/',
      'https://cobaltapi.cjs.nz/',
      'https://cobalt.tools/',
      'https://api.cobalt.tools/',
      'https://co.lazer.li/',
    ];
    for (final host in cobaltHosts) {
      try {
        final resp = await _dio.post(
          host,
          data: json.encode({
            'url': url,
            'videoQuality': quality,
            'filenameStyle': 'pretty',
            'downloadMode': 'auto',
          }),
          options: Options(
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            validateStatus: (s) => s != null && s < 500,
            receiveTimeout: const Duration(seconds: 15),
            connectTimeout: const Duration(seconds: 8),
          ),
        );
        final d = resp.data;
        if (d is Map) {
          final status = d['status']?.toString();
          if (status == 'stream' || status == 'redirect' || status == 'tunnel') {
            final dlUrl = d['url']?.toString();
            if (dlUrl != null) {
              return FetchResult(
                success: true,
                directUrl: dlUrl,
                title: 'YouTube Video',
              );
            }
          }
          if (status == 'picker') {
            final first = (d['picker'] as List?)?.firstOrNull;
            if (first != null && first['url'] != null) {
              return FetchResult(
                success: true,
                directUrl: first['url'].toString(),
                title: 'YouTube Video',
                thumbnail: first['thumb']?.toString(),
              );
            }
          }
        }
      } catch (_) {
        continue;
      }
    }

    // ── Layer 4: Invidious public instance ────────────────────
    // Invidious is open-source YouTube front-end, provides direct stream URLs
    final invidiousHosts = [
      'https://invidious.fdn.fr',
      'https://vid.puffyan.us',
      'https://inv.nadeko.net',
    ];
    try {
      // Extract videoId
      final vidIdMatch = RegExp(
        r'(?:v=|youtu\.be/|/shorts/)([A-Za-z0-9_-]{11})',
      ).firstMatch(url);
      if (vidIdMatch != null) {
        final videoId = vidIdMatch.group(1)!;
        for (final host in invidiousHosts) {
          try {
            final resp = await _dio.get(
              '$host/api/v1/videos/$videoId',
              options: Options(
                validateStatus: (s) => s != null && s < 500,
                receiveTimeout: const Duration(seconds: 10),
                connectTimeout: const Duration(seconds: 6),
              ),
            );
            final d = resp.data;
            if (d is Map && d['formatStreams'] != null) {
              final formats = d['formatStreams'] as List;
              final targetQ = int.tryParse(quality) ?? 720;
              Map? bestFmt;
              int bestDiff = 9999;
              for (final fmt in formats) {
                final fmtRes = int.tryParse(
                    (fmt['resolution']?.toString() ?? '').replaceAll('p', '')) ??
                    0;
                final diff = (fmtRes - targetQ).abs();
                if (diff < bestDiff && fmt['url'] != null) {
                  bestDiff = diff;
                  bestFmt = fmt;
                }
              }
              if (bestFmt != null) {
                return FetchResult(
                  success: true,
                  directUrl: bestFmt['url'].toString(),
                  title: d['title']?.toString() ?? 'YouTube Video',
                  thumbnail: d['videoThumbnails'] is List
                      ? ((d['videoThumbnails'] as List).isNotEmpty
                          ? (d['videoThumbnails'] as List).last['url']?.toString()
                          : null)
                      : null,
                );
              }
            }
          } catch (_) {
            continue;
          }
        }
      }
    } catch (_) {}

    return FetchResult(
      success: false,
      error: 'YouTube: ទាញ Link បរាជ័យទាំងអស់។\n'
          'Tips:\n'
          '• ពិនិត្យ Internet connection\n'
          '• ប្រើ youtu.be short link ឬ youtube.com/watch?v=... link\n'
          '• YouTube Shorts ✓ ដំណើរការ\n'
          '• ព្យាយាមម្ដងទៀតពេលក្រោយ',
    );
  }

  // ────────────────────────────────────────────────
  // ៤. Facebook — ប្រើ API savefrom.net
  // ────────────────────────────────────────────────
  Future<FetchResult> _fetchFacebook(String url) async {
    try {
      final response = await _dio.get(
        'https://saveFrom.net/api/convert',
        queryParameters: {'url': url, 'lang': 'en'},
        options: Options(headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': 'https://savefrom.net/',
        }),
      );

      final data = response.data;
      if (data != null && data['url'] != null) {
        final urls = data['url'] as List;
        if (urls.isNotEmpty) {
          return FetchResult(
            success: true,
            directUrl: urls.first['url'],
            title: data['meta']?['title'] ?? 'Facebook Video',
            thumbnail: data['meta']?['thumb'],
          );
        }
      }
      return FetchResult(success: false, error: 'Facebook: No URL found');
    } catch (e) {
      return FetchResult(success: false, error: 'Facebook: $e');
    }
  }

  // ────────────────────────────────────────────────
  // ៥. Instagram — Multi-method fallback chain
  //    Method 1: Instagram Mobile API (X-IG-App-ID)
  //    Method 2: yt5s.com (yt-dlp wrapper)
  //    Method 3: reelsaver.net
  //    Method 4: cobalt (last resort)
  // ────────────────────────────────────────────────
  Future<FetchResult> _fetchInstagram(String url) async {
    // ── Method 1: Instagram Mobile API ──
    try {
      final r = await _fetchInstagramInternalApi(url);
      if (r.success) return r;
    } catch (_) {}

    // ── Method 2: yt5s.com ──
    try {
      final r = await _fetchByYtdlpApi(
        apiUrl: 'https://yt5s.com/api/ajaxSearch',
        postData: {'q': url, 'vt': 'homevideo'},
        referer: 'https://yt5s.com/',
      );
      if (r.success) return r;
    } catch (_) {}

    // ── Method 3: reelsaver ──
    try {
      final r = await _fetchInstagramReelsaver(url);
      if (r.success) return r;
    } catch (_) {}

    // ── Method 4: cobalt (last resort) — ហៅ cobalt ផ្ទាល់ (មិនហៅ YouTube APIs) ──
    final cobalt = await _fetchByCobalt(url);
    if (cobalt.success) return cobalt;

    return FetchResult(
      success: false,
      error: 'Instagram: ទាញយកមិនបាន\n'
          'Tips: Paste session ⚙️ Settings ហើយប្រើ Public Reel link',
    );
  }


  /// Instagram Internal API — same approach as IG.py
  /// Uses Instagram's own X-IG-App-ID to get direct CDN video URL
  Future<FetchResult> _fetchInstagramInternalApi(String url) async {
    // Extract shortcode from URL  e.g. /reel/ABC123/ or /p/ABC123/
    final shortcodeMatch =
        RegExp(r'/(?:p|reel|tv)/([A-Za-z0-9_-]+)').firstMatch(url);
    if (shortcodeMatch == null) {
      return FetchResult(success: false, error: 'IG: cannot parse shortcode');
    }
    final shortcode = shortcodeMatch.group(1)!;

    // Load + URL-decode session ID from settings
    final prefs = await SharedPreferences.getInstance();
    final rawSession = prefs.getString('ig_session_id') ?? '';
    // URL-decode: %3A → :  (sessionid stored as URL-encoded from Chrome)
    final sessionId = Uri.decodeComponent(rawSession);
    // Extract numeric user ID from sessionid (format: 12345:xxxx:22:xxx)
    final dsUserId = sessionId.split(':').first;

    final cookieHeader = sessionId.isNotEmpty
        ? 'sessionid=$sessionId; ds_user_id=$dsUserId; ig_did=1;'
        : '';

    // Use Instagram GraphQL API — works with shortcode directly
    final graphqlUrl =
        'https://www.instagram.com/graphql/query/?query_hash='
        'b3055c01b4b222b8a47dc12b090e4e64&variables='
        '{"shortcode":"$shortcode"}';

    final response = await _dio.get(
      graphqlUrl,
      options: Options(
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
          'X-IG-App-ID': '936619743392459',
          'Accept': '*/*',
          'Referer': 'https://www.instagram.com/',
          if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
        },
        validateStatus: (s) => s != null && s < 500,
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    if (response.statusCode != 200) {
      // Try alternate endpoint with cookie
      final altUrl =
          'https://www.instagram.com/p/$shortcode/?__a=1&__d=dis';
      final alt = await _dio.get(
        altUrl,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'X-IG-App-ID': '936619743392459',
            'Accept': 'application/json',
            if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          },
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      return _parseIgJson(alt.data, url);
    }
    return _parseIgJson(response.data, url);
  }

  /// Parse Instagram GraphQL + Mobile API JSON response
  FetchResult _parseIgJson(dynamic data, String fallbackUrl) {
    try {
      if (data is String) data = json.decode(data);
      if (data is! Map) {
        return FetchResult(success: false, error: 'IG: invalid response');
      }

      // ── Format 1: GraphQL {data:{shortcode_media:{video_url}}} ──
      final graphqlData = data['data'];
      if (graphqlData is Map) {
        final media = graphqlData['shortcode_media'] as Map?;
        if (media != null) {
          final videoUrl = media['video_url']?.toString();
          if (videoUrl != null && videoUrl.isNotEmpty) {
            final caption = (media['edge_media_to_caption']?['edges']
                    as List?)
                ?.firstOrNull?['node']?['text']
                ?.toString() ?? 'Instagram Video';
            return FetchResult(
              success: true,
              directUrl: videoUrl,
              title: caption.length > 60 ? '${caption.substring(0, 60)}...' : caption,
              thumbnail: media['display_url']?.toString(),
            );
          }
          // Image post
          final display = media['display_url']?.toString();
          if (display != null) {
            return FetchResult(success: true, directUrl: display, title: 'Instagram Photo');
          }
        }
      }

      // ── Format 2: Mobile API {items:[{video_versions,image_versions2}]} ──
      final items = (data['items'] as List?)?.isNotEmpty == true
          ? data['items'] as List : null;
      final item = items?.first as Map?;
      if (item != null) {
        final videoVersions = item['video_versions'] as List?;
        if (videoVersions != null && videoVersions.isNotEmpty) {
          final best = videoVersions.reduce((a, b) =>
              (a['width'] ?? 0) > (b['width'] ?? 0) ? a : b);
          final videoUrl = best['url']?.toString();
          if (videoUrl != null) {
            final thumb = (item['image_versions2']?['candidates'] as List?)
                ?.firstOrNull?['url']?.toString();
            final caption = item['caption']?['text']?.toString() ?? 'Instagram Video';
            return FetchResult(
              success: true,
              directUrl: videoUrl,
              title: caption.length > 50 ? '${caption.substring(0, 50)}...' : caption,
              thumbnail: thumb,
            );
          }
        }
        final imgCandidates = item['image_versions2']?['candidates'] as List?;
        if (imgCandidates != null && imgCandidates.isNotEmpty) {
          final imgUrl = imgCandidates.first['url']?.toString();
          if (imgUrl != null) {
            return FetchResult(success: true, directUrl: imgUrl, title: 'Instagram Photo');
          }
        }
      }

      // ── Format 3: ?__a=1 {graphql:{shortcode_media}} ──
      final legacyGraphql = data['graphql'];
      if (legacyGraphql is Map) {
        final media = legacyGraphql['shortcode_media'] as Map?;
        if (media != null) {
          final videoUrl = media['video_url']?.toString();
          if (videoUrl != null) {
            return FetchResult(
              success: true,
              directUrl: videoUrl,
              title: 'Instagram Video',
              thumbnail: media['display_url']?.toString(),
            );
          }
        }
      }
    } catch (_) {}
    return FetchResult(success: false, error: 'IG: no media found in response');
  }

  /// Generic yt-dlp API caller (yt5s / y2down / etc.)
  Future<FetchResult> _fetchByYtdlpApi({
    required String apiUrl,
    required Map<String, dynamic> postData,
    required String referer,
  }) async {
    final response = await _dio.post(
      apiUrl,
      data: postData,
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
        headers: {
          'Referer': referer,
          'Origin': Uri.parse(referer).origin,
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
        },
        validateStatus: (s) => s != null && s < 500,
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    final data = response.data;
    if (data is! Map) return FetchResult(success: false, error: 'bad response');
    if (data['status'] == 'ok') {
      final links = data['links'];
      if (links is List && links.isNotEmpty) {
        final best = links.firstWhere(
          (l) => l['ext'] == 'mp4' || (l['type']?.toString() ?? '').contains('video'),
          orElse: () => links.first,
        );
        final dl = best['url'] ?? best['k__id'];
        if (dl != null) {
          return FetchResult(
            success: true,
            directUrl: dl.toString(),
            title: data['title']?.toString() ?? 'Instagram Video',
            thumbnail: data['thumb']?.toString(),
          );
        }
      }
      if (data['url'] != null) {
        return FetchResult(
          success: true,
          directUrl: data['url'].toString(),
          title: data['title']?.toString() ?? 'Instagram Video',
        );
      }
    }
    return FetchResult(success: false, error: 'ytdlp api: ${data['mess'] ?? 'no link'}');
  }

  /// Instagram via reelsaver.net
  Future<FetchResult> _fetchInstagramReelsaver(String url) async {
    final response = await _dio.post(
      'https://reelsaver.net/wp-json/aio-dl/video-data/',
      data: {'url': url},
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
        headers: {
          'Referer': 'https://reelsaver.net/',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
        },
        validateStatus: (s) => s != null && s < 500,
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    final data = response.data;
    if (data is Map) {
      final medias = data['medias'];
      if (medias is List && medias.isNotEmpty) {
        final video = medias.firstWhere(
          (m) => m['extension'] == 'mp4',
          orElse: () => medias.first,
        );
        if (video['url'] != null) {
          return FetchResult(
            success: true,
            directUrl: video['url'].toString(),
            title: data['title']?.toString() ?? 'Instagram Reel',
            thumbnail: data['thumbnail']?.toString(),
          );
        }
      }
    }
    return FetchResult(success: false, error: 'reelsaver: no media');
  }

  // ────────────────────────────────────────────────
  // ៦. ReelShort — API + Proxy Fallback
  // ────────────────────────────────────────────────
  Future<FetchResult> _fetchReelShort(String url) async {
    // ព្យាយាមហៅ Proxy Server លើ PC មុនគេ ដើម្បី Intercept .m3u8 តាម Playwright
    final proxyResult = await _fetchViaLocalProxy(url);
    if (proxyResult.success) {
      return proxyResult;
    }

    // ប្រសិនបើ Proxy ដើរ ប៉ុន្តែបរាជ័យដោយសាររកមិនឃើញវីដេអូ (locked/etc.) ឲ្យបង្ហាញ error ផ្ទាល់ខ្លួន
    if (proxyResult.error != 'Proxy not running') {
      return proxyResult;
    }

    // ព្យាយាមទាញយកដោយប្រើ Client-side WebView Extractor (លាក់ខ្លួននៅក្នុង App)
    final extractedUrl = await WebViewExtractorService().extractMediaUrl(url);
    if (extractedUrl != null) {
      return FetchResult(
        success: true,
        directUrl: extractedUrl,
        title: 'ReelShort Video (WebView)',
      );
    }

    // ប្រសិនបើ Proxy មិនដំណើរការទាល់តែសោះ និង WebView ទាញយកមិនបាន
    return FetchResult(
      success: false,
      error: 'ReelShort: មិនអាចទាញយកវីដេអូបានឡើយ។ សូមប្រាកដថាលីងត្រឹមត្រូវ ឬបើក Proxy Server លើ PC។',
    );
  }

  // ────────────────────────────────────────────────
  // ៦.២ NetShort — Proxy Fallback
  // ────────────────────────────────────────────────
  Future<FetchResult> _fetchNetShort(String url) async {
    final proxyResult = await _fetchViaLocalProxy(url);
    if (proxyResult.success) {
      return proxyResult;
    }

    if (proxyResult.error != 'Proxy not running') {
      return proxyResult;
    }

    // ព្យាយាមទាញយកដោយប្រើ Client-side WebView Extractor (លាក់ខ្លួននៅក្នុង App)
    final extractedUrl = await WebViewExtractorService().extractMediaUrl(url);
    if (extractedUrl != null) {
      return FetchResult(
        success: true,
        directUrl: extractedUrl,
        title: 'NetShort Video (WebView)',
      );
    }

    return FetchResult(
      success: false,
      error: 'NetShort: មិនអាចទាញយកវីដេអូបានឡើយ។ សូមប្រាកដថាលីងត្រឹមត្រូវ ឬបើក Proxy Server លើ PC។',
    );
  }

  // ────────────────────────────────────────────────
  // ៦.៣ DramaBox — Proxy Fallback
  // ────────────────────────────────────────────────
  Future<FetchResult> _fetchDramaBox(String url) async {
    final proxyResult = await _fetchViaLocalProxy(url);
    if (proxyResult.success) {
      return proxyResult;
    }

    if (proxyResult.error != 'Proxy not running') {
      return proxyResult;
    }

    // ព្យាយាមទាញយកដោយប្រើ Client-side WebView Extractor (លាក់ខ្លួននៅក្នុង App)
    final extractedUrl = await WebViewExtractorService().extractMediaUrl(url);
    if (extractedUrl != null) {
      return FetchResult(
        success: true,
        directUrl: extractedUrl,
        title: 'DramaBox Video (WebView)',
      );
    }

    return FetchResult(
      success: false,
      error: 'DramaBox: មិនអាចទាញយកវីដេអូបានឡើយ។ សូមប្រាកដថាលីងត្រឹមត្រូវ ឬបើក Proxy Server លើ PC។',
    );
  }

  /// ហៅ Proxy Server លើ PC (10.0.2.2 សម្រាប់ emulator និង 127.0.0.1 សម្រាប់ adb reverse)
  Future<FetchResult> _fetchViaLocalProxy(String url) async {
    final hosts = ['http://127.0.0.1:8765', 'http://10.0.2.2:8765'];
    for (final host in hosts) {
      try {
        final response = await _dio.get(
          '$host/get',
          queryParameters: {'url': url},
          options: Options(
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 45),
          ),
        );
        final data = response.data;
        if (data is Map) {
          if (data['success'] == true) {
            return FetchResult(
              success: true,
              directUrl: data['url']?.toString(),
              title: data['title']?.toString() ?? 'ReelShort Video',
              thumbnail: data['thumbnail']?.toString() ?? '',
            );
          } else {
            // Proxy is running but returned failure (e.g. locked episode or not found)
            return FetchResult(
              success: false,
              error: data['error']?.toString() ?? 'Failed to extract video',
            );
          }
        }
      } catch (_) {
        continue;
      }
    }
    return FetchResult(success: false, error: 'Proxy not running');
  }

  /// ទាញយកបញ្ជី episodes ទាំងអស់របស់ ReelShort Series
  Future<ReelShortSeriesResult> fetchReelShortSeries(String url) async {
    try {
      String? bookId;
      String? mSlug;

      final epMatch = RegExp(
        r'/episodes/(?:episode-\d+-)?.*?-([a-fA-F0-9]{24})-[a-zA-Z0-9]+',
      ).firstMatch(url);
      final mvMatch = RegExp(r'/movie/.*?-([a-fA-F0-9]{24})').firstMatch(url);

      if (epMatch != null) {
        bookId = epMatch.group(1);
      } else if (mvMatch != null) {
        bookId = mvMatch.group(1);
      }

      final slugMatch = RegExp(
        r'/(?:movie|episodes)/(?:episode-\d+-)?(.*?-[a-fA-F0-9]{24})',
      ).firstMatch(url);
      if (slugMatch != null) {
        var raw = slugMatch.group(1)!;
        if (url.contains('/episodes/')) {
          raw = raw.replaceFirst(RegExp(r'-[a-zA-Z0-9]{10}$'), '');
        }
        mSlug = raw;
      }

      if (bookId == null) {
        return ReelShortSeriesResult(
          title: '',
          episodes: [],
          error: 'មិនអាចស្វែងរក Book ID ពី Link នេះបានទេ',
        );
      }

      final apiResp = await _dio.get(
        'https://www.reelshort.com/api/video/book/getBookInfo?book_id=$bookId',
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'application/json',
            'Referer': 'https://www.reelshort.com/',
          },
          validateStatus: (s) => s != null && s < 500,
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      final data = apiResp.data;
      if (data is Map && data['code'] == 0) {
        final d = data['data'] as Map;
        final title = d['book_title']?.toString() ?? 'ReelShort Series';
        final cover = d['book_pic']?.toString() ?? '';
        final onlineBase = d['online_base'] as List? ?? [];

        mSlug ??= title
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .trim();
        mSlug = '$mSlug-$bookId';

        final List<ReelShortEpisode> episodes = [];
        for (final ch in onlineBase) {
          final cid = ch['chapter_id']?.toString() ?? '';
          final num = ch['serial_number'] ?? 0;
          final ctype = ch['chapter_type'] ?? 1;
          if (cid.isNotEmpty && num > 0 && ctype != 2) {
            episodes.add(ReelShortEpisode(
              episodeNumber: num,
              url: 'https://www.reelshort.com/episodes/episode-$num-$mSlug-$cid',
            ));
          }
        }
        episodes.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));

        return ReelShortSeriesResult(
          title: title,
          cover: cover,
          episodes: episodes,
        );
      }
      return ReelShortSeriesResult(
        title: '',
        episodes: [],
        error: 'API Error: ${data['msg'] ?? 'Unknown error'}',
      );
    } catch (e) {
      return ReelShortSeriesResult(title: '', episodes: [], error: 'Error: $e');
    }
  }

  /// ទាញយកបញ្ជី episodes ទាំងអស់របស់ NetShort Series តាមរយៈ Proxy Server
  Future<ReelShortSeriesResult> fetchNetShortSeries(String url) async {
    // ព្យាយាមហៅ Proxy Server ជាមុនសិន
    final hosts = ['http://10.0.2.2:8765', 'http://127.0.0.1:8765'];
    for (final host in hosts) {
      try {
        final response = await _dio.get(
          '$host/netshort_series',
          queryParameters: {'url': url},
          options: Options(
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 45),
          ),
        );
        final data = response.data;
        if (data is Map && data['success'] == true) {
          final title = data['title']?.toString() ?? 'NetShort Series';
          final cover = data['cover']?.toString() ?? '';
          final List<ReelShortEpisode> episodes = [];
          final list = data['episodes'] as List? ?? [];
          for (final ep in list) {
            final epUrl = ep['url']?.toString() ?? '';
            final num = ep['ep_num'] ?? 1;
            if (epUrl.isNotEmpty) {
              episodes.add(ReelShortEpisode(
                episodeNumber: num,
                url: epUrl,
              ));
            }
          }
          return ReelShortSeriesResult(
            title: title,
            cover: cover,
            episodes: episodes,
          );
        }
      } catch (_) {
        continue;
      }
    }

    // ប្រសិនបើ Proxy មិនដំណើរការ ត្រូវប្រើ WebView Series Extractor ជំនួសវិញ (Client-side)
    try {
      print("fetchNetShortSeries: Proxy failing/not running, trying client-side WebView extraction...");
      final extracted = await WebViewExtractorService().extractSeries(url);
      if (extracted != null) {
        final title = extracted['title']?.toString() ?? 'NetShort Series';
        final cover = extracted['cover']?.toString() ?? '';
        final List<ReelShortEpisode> episodes = [];
        final list = extracted['episodes'] as List? ?? [];
        for (final ep in list) {
          if (ep is Map) {
            episodes.add(ReelShortEpisode(
              episodeNumber: ep['num'] as int? ?? 1,
              url: ep['url']?.toString() ?? '',
            ));
          }
        }
        if (episodes.isNotEmpty) {
          return ReelShortSeriesResult(
            title: title,
            cover: cover,
            episodes: episodes,
          );
        }
      }
    } catch (e) {
      print("fetchNetShortSeries native extractor error: $e");
    }

    return ReelShortSeriesResult(
      title: '',
      episodes: [],
      error: 'NetShort: មិនអាចទាញយកបញ្ជីភាគពី Proxy Server ឬទំព័រដើមបានទេ។',
    );
  }

  /// ទាញយកបញ្ជី episodes ទាំងអស់របស់ DramaBox Series តាមរយៈ Proxy Server
  Future<ReelShortSeriesResult> fetchDramaBoxSeries(String url) async {
    // ព្យាយាមហៅ Proxy Server ជាមុនសិន
    final hosts = ['http://127.0.0.1:8765', 'http://10.0.2.2:8765'];
    for (final host in hosts) {
      try {
        final response = await _dio.get(
          '$host/dramabox_series',
          queryParameters: {'url': url},
          options: Options(
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 45),
          ),
        );
        final data = response.data;
        if (data is Map && data['success'] == true) {
          final title = data['title']?.toString() ?? 'DramaBox Series';
          final cover = data['cover']?.toString() ?? '';
          final List<ReelShortEpisode> episodes = [];
          final list = data['episodes'] as List? ?? [];
          for (final ep in list) {
            final epUrl = ep['url']?.toString() ?? '';
            final num = ep['ep_num'] ?? 1;
            if (epUrl.isNotEmpty) {
              episodes.add(ReelShortEpisode(
                episodeNumber: num,
                url: epUrl,
              ));
            }
          }
          return ReelShortSeriesResult(
            title: title,
            cover: cover,
            episodes: episodes,
          );
        }
      } catch (_) {
        continue;
      }
    }

    // ប្រសិនបើ Proxy មិនដំណើរការ ត្រូវប្រើ WebView Series Extractor ជំនួសវិញ (Client-side)
    try {
      print("fetchDramaBoxSeries: Proxy failing/not running, trying client-side WebView extraction...");
      final extracted = await WebViewExtractorService().extractSeries(url);
      if (extracted != null) {
        final title = extracted['title']?.toString() ?? 'DramaBox Series';
        final cover = extracted['cover']?.toString() ?? '';
        final List<ReelShortEpisode> episodes = [];
        final list = extracted['episodes'] as List? ?? [];
        for (final ep in list) {
          if (ep is Map) {
            episodes.add(ReelShortEpisode(
              episodeNumber: ep['num'] as int? ?? 1,
              url: ep['url']?.toString() ?? '',
            ));
          }
        }
        if (episodes.isNotEmpty) {
          return ReelShortSeriesResult(
            title: title,
            cover: cover,
            episodes: episodes,
          );
        }
      }
    } catch (e) {
      print("fetchDramaBoxSeries native extractor error: $e");
    }

    return ReelShortSeriesResult(
      title: '',
      episodes: [],
      error: 'DramaBox: មិនអាចទាញយកបញ្ជីភាគពី Proxy Server ឬទំព័រដើមបានទេ។',
    );
  }

  // ────────────────────────────────────────────────
  // ៦.៤ Telegram — Proxy Fallback
  // ────────────────────────────────────────────────
  Future<FetchResult> _fetchTelegram(String url) async {
    final proxyResult = await _fetchViaLocalProxy(url);
    if (proxyResult.success) {
      return proxyResult;
    }

    if (proxyResult.error != 'Proxy not running') {
      return proxyResult;
    }

    // ព្យាយាមទាញយកដោយប្រើ Client-side WebView Extractor (លាក់ខ្លួននៅក្នុង App)
    final extractedUrl = await WebViewExtractorService().extractMediaUrl(url);
    if (extractedUrl != null) {
      return FetchResult(
        success: true,
        directUrl: extractedUrl,
        title: 'Telegram Video (WebView)',
      );
    }

    return FetchResult(
      success: false,
      error: 'Telegram: មិនអាចទាញយកវីដេអូបានឡើយ។ សូមប្រាកដថាលីងត្រឹមត្រូវ ឬបើក Proxy Server លើ PC។',
    );
  }

  /// ទាញយកបញ្ជី episodes ទាំងអស់របស់ Telegram Channel/Group តាមរយៈ Proxy Server
  Future<ReelShortSeriesResult> fetchTelegramSeries(String url) async {
    final hosts = ['http://127.0.0.1:8765', 'http://10.0.2.2:8765'];
    for (final host in hosts) {
      try {
        final response = await _dio.get(
          '$host/tg_series',
          queryParameters: {'url': url},
          options: Options(
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 45),
          ),
        );
        final data = response.data;
        if (data is Map && data['success'] == true) {
          final title = data['title']?.toString() ?? 'Telegram Channel';
          final cover = data['cover']?.toString() ?? '';
          final List<ReelShortEpisode> episodes = [];
          final list = data['episodes'] as List? ?? [];
          for (final ep in list) {
            final epUrl = ep['url']?.toString() ?? '';
            final num = ep['ep_num'] ?? 1;
            if (epUrl.isNotEmpty) {
              episodes.add(ReelShortEpisode(
                episodeNumber: num,
                url: epUrl,
              ));
            }
          }
          return ReelShortSeriesResult(
            title: title,
            cover: cover,
            episodes: episodes,
          );
        } else if (data is Map && data['error'] == 'auth_required') {
          return ReelShortSeriesResult(
            title: '',
            episodes: [],
            error: 'auth_required',
          );
        }
      } catch (_) {
        continue;
      }
    }

    // ព្យាយាមទាញយកដោយប្រើ Client-side WebView Extractor (លាក់ខ្លួននៅក្នុង App) ជំនួសវិញ
    try {
      print("fetchTelegramSeries: Proxy not running, trying client-side WebView series extraction...");
      final extracted = await WebViewExtractorService().extractSeries(url);
      if (extracted != null) {
        final title = extracted['title']?.toString() ?? 'Telegram Channel';
        final cover = extracted['cover']?.toString() ?? '';
        final List<ReelShortEpisode> episodes = [];
        final list = extracted['episodes'] as List? ?? [];
        for (final ep in list) {
          if (ep is Map) {
            episodes.add(ReelShortEpisode(
              episodeNumber: ep['num'] as int? ?? 1,
              url: ep['url']?.toString() ?? '',
            ));
          }
        }
        if (episodes.isNotEmpty) {
          return ReelShortSeriesResult(
            title: title,
            cover: cover,
            episodes: episodes,
          );
        }
      }
    } catch (e) {
      print("fetchTelegramSeries native extractor error: $e");
    }

    return ReelShortSeriesResult(
      title: '',
      episodes: [],
      error: 'Telegram: មិនអាចទាញយកបញ្ជីភាគពី Proxy Server ឬទំព័រដើមបានទេ។ ប្រសិនបើមិនបានបើក Proxy លើ PC ទេ សូមប្រាកដថា Telegram Channel នេះជា Public (សាធារណៈ)។',
    );
  }

  /// ផ្ទៀងផ្ទាត់ និង Login Telegram account ជាមួយ Proxy Server
  Future<Map<String, dynamic>> verifyTelegramAuth({
    String? phone,
    String? code,
    String? phoneHash,
    String? password,
  }) async {
    final hosts = ['http://127.0.0.1:8765', 'http://10.0.2.2:8765'];
    for (final host in hosts) {
      try {
        final response = await _dio.get(
          '$host/tg_auth',
          queryParameters: {
            if (phone != null) 'phone': phone,
            if (code != null) 'code': code,
            if (phoneHash != null) 'phone_hash': phoneHash,
            if (password != null) 'password': password,
          },
          options: Options(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );
        final data = response.data;
        if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
      } catch (e) {
        continue;
      }
    }
    return {'status': 'error', 'error': 'មិនអាចទាក់ទងទៅ Proxy Server បានទេ'};
  }

  // ────────────────────────────────────────────────
  // ៧. Generic fallback — cobalt supports many platforms
  // ────────────────────────────────────────────────
  Future<FetchResult> _fetchGeneric(String url) async {
    return await _fetchByCobalt(url);
  }

  // ────────────────────────────────────────────────
  // ៨. Cobalt Direct — ហៅ cobalt ដោយផ្ទាល់
  // ────────────────────────────────────────────────
  Future<FetchResult> _fetchByCobalt(String url) async {
    final cobaltHosts = [
      'https://fox.kittycat.boo/',
      'https://api.cobalt.blackcat.sweeux.org/',
      'https://cobaltapi.cjs.nz/',
      'https://cobalt.tools/',
      'https://api.cobalt.tools/',
      'https://co.lazer.li/',
    ];
    for (final host in cobaltHosts) {
      try {
        final resp = await _dio.post(
          host,
          data: json.encode({
            'url': url,
            'filenameStyle': 'pretty',
            'downloadMode': 'auto',
          }),
          options: Options(
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            validateStatus: (s) => s != null && s < 500,
            receiveTimeout: const Duration(seconds: 15),
            connectTimeout: const Duration(seconds: 8),
          ),
        );
        final d = resp.data;
        if (d is Map) {
          final status = d['status']?.toString();
          if (status == 'stream' || status == 'redirect' || status == 'tunnel') {
            final dlUrl = d['url']?.toString();
            if (dlUrl != null) {
              return FetchResult(success: true, directUrl: dlUrl);
            }
          }
          if (status == 'picker') {
            final first = (d['picker'] as List?)?.firstOrNull;
            if (first != null && first['url'] != null) {
              return FetchResult(
                success: true,
                directUrl: first['url'].toString(),
                thumbnail: first['thumb']?.toString(),
              );
            }
          }
        }
      } catch (_) {
        continue;
      }
    }
    return FetchResult(success: false, error: 'Cobalt: ទាញ Link មិនបាន');
  }


  // ────────────────────────────────────────────────
  // ៧. Download File ពិតប្រាកដ ជាមួយ Progress
  // ────────────────────────────────────────────────
  Future<void> _downloadHls({
    required String m3u8Url,
    required String savePath,
    required Function(double progress, double downloadedMB, double totalMB, double speedMBps) onProgress,
    CancelToken? cancelToken,
  }) async {
    print("HLS Downloader: Starting download from $m3u8Url");
    
    // 1. Fetch the playlist content
    final response = await _dio.get(
      m3u8Url,
      options: Options(
        responseType: ResponseType.plain,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Android 13; Mobile) AppleWebKit/537.36',
          'Referer': m3u8Url,
        },
      ),
      cancelToken: cancelToken,
    );
    
    String m3u8Content = response.data.toString();
    String targetPlaylistUrl = m3u8Url;
    
    // If it's a master playlist, select the best stream
    if (m3u8Content.contains('#EXT-X-STREAM-INF')) {
      print("HLS Downloader: Found master playlist, selecting variant...");
      final lines = m3u8Content.split('\n');
      String? bestVariantUrl;
      int maxBandwidth = -1;
      
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('#EXT-X-STREAM-INF:')) {
          // Parse BANDWIDTH
          final bandwidthMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
          final bandwidth = bandwidthMatch != null ? int.parse(bandwidthMatch.group(1)!) : 0;
          
          // Next line is the URL
          if (i + 1 < lines.length) {
            final variantUrl = lines[i + 1].trim();
            if (variantUrl.isNotEmpty && !variantUrl.startsWith('#')) {
              if (bandwidth > maxBandwidth) {
                maxBandwidth = bandwidth;
                bestVariantUrl = variantUrl;
              }
            }
          }
        }
      }
      
      if (bestVariantUrl != null) {
        targetPlaylistUrl = Uri.parse(m3u8Url).resolve(bestVariantUrl).toString();
        print("HLS Downloader: Selected variant: $targetPlaylistUrl");
        // Fetch the variant playlist
        final variantResponse = await _dio.get(
          targetPlaylistUrl,
          options: Options(
            responseType: ResponseType.plain,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Android 13; Mobile) AppleWebKit/537.36',
              'Referer': m3u8Url,
            },
          ),
          cancelToken: cancelToken,
        );
        m3u8Content = variantResponse.data.toString();
      }
    }
    
    // 2. Parse segments
    final lines = m3u8Content.split('\n');
    final List<String> segmentUrls = [];
    
    for (var line in lines) {
      line = line.trim();
      if (line.isNotEmpty && !line.startsWith('#')) {
        final segmentUrl = Uri.parse(targetPlaylistUrl).resolve(line).toString();
        segmentUrls.add(segmentUrl);
      }
    }
    
    if (segmentUrls.isEmpty) {
      throw Exception("No video segments found in the playlist.");
    }
    
    print("HLS Downloader: Found ${segmentUrls.length} segments to download.");
    
    // 3. Open target file for writing
    final file = File(savePath);
    if (await file.exists()) {
      await file.delete();
    }
    
    final IOSink sink = file.openWrite(mode: FileMode.append);
    int downloadedSegments = 0;
    int totalBytesDownloaded = 0;
    
    try {
      final startTime = DateTime.now();
      
      for (final segmentUrl in segmentUrls) {
        if (cancelToken?.isCancelled == true) {
          throw DioException(
            requestOptions: RequestOptions(path: segmentUrl),
            type: DioExceptionType.cancel,
          );
        }
        
        // Download segment bytes
        final segmentResponse = await _dio.get<List<int>>(
          segmentUrl,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Android 13; Mobile) AppleWebKit/537.36',
              'Referer': targetPlaylistUrl,
            },
          ),
          cancelToken: cancelToken,
        );
        
        final bytes = segmentResponse.data!;
        sink.add(bytes);
        
        downloadedSegments++;
        totalBytesDownloaded += bytes.length;
        
        // Calculate progress & speed
        final now = DateTime.now();
        final elapsedMs = now.difference(startTime).inMilliseconds;
        final speedMBps = elapsedMs > 0 
            ? (totalBytesDownloaded / 1024 / 1024) / (elapsedMs / 1000) 
            : 0.0;
            
        final progress = downloadedSegments / segmentUrls.length;
        
        // Est. total size based on average segment size
        final avgSegmentSize = totalBytesDownloaded / downloadedSegments;
        final estTotalBytes = avgSegmentSize * segmentUrls.length;
        
        onProgress(
          progress,
          totalBytesDownloaded / 1024 / 1024,
          estTotalBytes / 1024 / 1024,
          speedMBps,
        );
      }
      
      await sink.flush();
    } finally {
      await sink.close();
    }
    
    print("HLS Downloader: Completed download successfully! Total size: ${(totalBytesDownloaded / 1024 / 1024).toStringAsFixed(2)} MB");
  }

  Future<String?> downloadFile({
    required String url,
    required String fileName,
    required Function(double progress, double downloadedMB, double totalMB, double speedMBps) onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      // ស្នើ Permission
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        throw Exception('Storage permission denied');
      }

      // រក folder ទុក
      final dir = await _getDownloadDirectory();
      final filePath = '${dir.path}/$fileName';

      // បើសិនជា HLS playlist (.m3u8) ត្រូវប្រើ HLS Downloader
      if (url.toLowerCase().contains('.m3u8')) {
        await _downloadHls(
          m3u8Url: url,
          savePath: filePath,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );
        return filePath;
      }

      // ករណីធម្មតា (Direct MP4) Download ជាមួយ Dio progress
      await _dio.download(
        url,
        filePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            // Track download speed
            final now = DateTime.now();
            final elapsedMs = now.difference(_lastSpeedTime).inMilliseconds;
            double speedMBps = 0;
            if (elapsedMs >= 200) {
              final bytesDiff = received - _lastBytes;
              speedMBps = (bytesDiff / 1024 / 1024) / (elapsedMs / 1000);
              _lastBytes = received;
              _lastSpeedTime = now;
            }
            onProgress(
              received / total,
              received / 1024 / 1024,
              total / 1024 / 1024,
              speedMBps,
            );
          }
        },
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Android 13; Mobile) AppleWebKit/537.36',
          },
        ),
      );

      return filePath;
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        return null; // Cancel ធម្មតា
      }
      rethrow;
    }
  }

  // ────────────────────────────────────────────────
  // ៨. Helper Functions
  // ────────────────────────────────────────────────
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Android 13+ ប្រើ photos permission
      final photos = await Permission.photos.status;
      if (photos.isGranted) return true;

      final videos = await Permission.videos.status;
      if (videos.isGranted) return true;

      // Android < 13 ប្រើ storage
      final storage = await Permission.storage.status;
      if (storage.isGranted) return true;

      // ស្នើ
      final result = await [
        Permission.storage,
        Permission.photos,
        Permission.videos,
      ].request();

      return result.values.any((s) => s.isGranted);
    }
    return true; // iOS មិនត្រូវការ
  }

  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      // ព្យាយាមប្រើ external storage (Downloads folder)
      try {
        final externalDirs = await getExternalStorageDirectories(
          type: StorageDirectory.downloads,
        );
        if (externalDirs != null && externalDirs.isNotEmpty) {
          final dir = Directory(externalDirs.first.path);
          if (!await dir.exists()) await dir.create(recursive: true);
          return dir;
        }
      } catch (_) {}
    }
    // Fallback: app documents directory
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/LinkGrab');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // Speed tracking state
  int _lastBytes = 0;
  DateTime _lastSpeedTime = DateTime.now();

  /// Generate filename unique ពី URL
  String generateFileName(String platform, String url) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    var ext = 'mp4';
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('.jpg') || lowerUrl.contains('.jpeg')) {
      ext = 'jpg';
    } else if (lowerUrl.contains('.png')) {
      ext = 'png';
    } else if (lowerUrl.contains('.webp')) {
      ext = 'webp';
    }
    return '${platform}_$timestamp.$ext';
  }
}
