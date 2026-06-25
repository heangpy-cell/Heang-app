import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebViewExtractorService {
  static final WebViewExtractorService _instance = WebViewExtractorService._internal();
  factory WebViewExtractorService() => _instance;
  WebViewExtractorService._internal();

  /// Helper to extract m3u8/mp4 from raw HTML source using multiple patterns
  String? _extractFromHtml(String html) {
    // 1. ReelShort / NetShort / DramaBox specific JSON-LD keys (supporting both m3u8 and mp4)
    final contentUrlRegex = RegExp(r'"contentUrl"\s*:\s*"([^"]+\.(?:m3u8|mp4)[^"]*)"', caseSensitive: false);
    final videoUrlRegex = RegExp(r'"video_url"\s*:\s*"([^"]+\.(?:m3u8|mp4)[^"]*)"', caseSensitive: false);
    final embedUrlRegex = RegExp(r'"embedUrl"\s*:\s*"([^"]+\.(?:m3u8|mp4)[^"]*)"', caseSensitive: false);
    final videoUrlGeneralRegex = RegExp(r'"videoUrl"\s*:\s*"([^"]+\.(?:m3u8|mp4)[^"]*)"', caseSensitive: false);

    var match = contentUrlRegex.firstMatch(html);
    if (match != null) return match.group(1)!.replaceAll(r'\/', '/');

    match = videoUrlRegex.firstMatch(html);
    if (match != null) return match.group(1)!.replaceAll(r'\/', '/');

    match = embedUrlRegex.firstMatch(html);
    if (match != null) return match.group(1)!.replaceAll(r'\/', '/');

    match = videoUrlGeneralRegex.firstMatch(html);
    if (match != null) return match.group(1)!.replaceAll(r'\/', '/');

    // 2. Generic HLS/MP4 link capture (excluding segments/ts/ads/analytics/images)
    final rawUrlRegex = RegExp(r'''https?://[^\s"\'<>]+?\.(?:m3u8|mp4)[^\s"\'<>]*''', caseSensitive: false);
    final allMatches = rawUrlRegex.allMatches(html);
    for (final m in allMatches) {
      final url = m.group(0)!.replaceAll(r'\/', '/');
      final lowerUrl = url.toLowerCase();
      if (!lowerUrl.contains('analytics') &&
          !lowerUrl.contains('doubleclick') &&
          !lowerUrl.contains('facebook.com') &&
          !lowerUrl.contains('ads') &&
          !lowerUrl.contains('segment') &&
          !lowerUrl.contains('.ts') &&
          !lowerUrl.contains('.jpg') &&
          !lowerUrl.contains('.jpeg') &&
          !lowerUrl.contains('.png') &&
          !lowerUrl.contains('.webp')) {
        return url;
      }
    }

    return null;
  }

  /// Helper to extract all matching m3u8/mp4 URLs from raw HTML source
  List<String> _extractAllFromHtml(String html) {
    final List<String> results = [];
    
    // 1. Specific JSON-LD keys
    final contentUrlRegex = RegExp(r'"contentUrl"\s*:\s*"([^"]+\.(?:m3u8|mp4)[^"]*)"', caseSensitive: false);
    final videoUrlRegex = RegExp(r'"video_url"\s*:\s*"([^"]+\.(?:m3u8|mp4)[^"]*)"', caseSensitive: false);
    final embedUrlRegex = RegExp(r'"embedUrl"\s*:\s*"([^"]+\.(?:m3u8|mp4)[^"]*)"', caseSensitive: false);
    final videoUrlGeneralRegex = RegExp(r'"videoUrl"\s*:\s*"([^"]+\.(?:m3u8|mp4)[^"]*)"', caseSensitive: false);

    for (final regex in [contentUrlRegex, videoUrlRegex, embedUrlRegex, videoUrlGeneralRegex]) {
      final matches = regex.allMatches(html);
      for (final m in matches) {
        final cleaned = m.group(1)!.replaceAll(r'\/', '/');
        if (!results.contains(cleaned)) {
          results.add(cleaned);
        }
      }
    }

    // 2. Generic HLS/MP4 link capture
    final rawUrlRegex = RegExp(r'''https?://[^\s"\'<>]+?\.(?:m3u8|mp4)[^\s"\'<>]*''', caseSensitive: false);
    final allMatches = rawUrlRegex.allMatches(html);
    for (final m in allMatches) {
      final url = m.group(0)!.replaceAll(r'\/', '/');
      final lowerUrl = url.toLowerCase();
      if (!lowerUrl.contains('analytics') &&
          !lowerUrl.contains('doubleclick') &&
          !lowerUrl.contains('facebook.com') &&
          !lowerUrl.contains('ads') &&
          !lowerUrl.contains('segment') &&
          !lowerUrl.contains('.ts') &&
          !lowerUrl.contains('.jpg') &&
          !lowerUrl.contains('.jpeg') &&
          !lowerUrl.contains('.png') &&
          !lowerUrl.contains('.webp')) {
        if (!results.contains(url)) {
          results.add(url);
        }
      }
    }

    return results;
  }

  /// Extract direct media URL (.mp4 or .m3u8) from a web page using a hidden background Headless WebView.
  Future<String?> extractMediaUrl(String url) async {
    print("WebViewExtractorService: Start extracting for URL: $url");
    final Completer<String?> completer = Completer<String?>();
    HeadlessInAppWebView? headlessWebView;
    Timer? pollTimer;
    
    // Check if it's a Telegram URL and rewrite to use embed mode for direct video playback
    final lowerUrl = url.toLowerCase();
    final isTelegram = lowerUrl.contains('t.me') || lowerUrl.contains('telegram.me');
    var targetUrl = url;
    if (isTelegram) {
      try {
        final uri = Uri.parse(url);
        final segments = uri.pathSegments;
        if (segments.length >= 2 && RegExp(r'^\d+$').hasMatch(segments.last)) {
          final channel = segments[segments.length - 2];
          final postId = segments.last;
          targetUrl = "https://t.me/$channel/$postId?embed=1";
          print("WebViewExtractorService: Rewrote Telegram URL to embed: $targetUrl");
        }
      } catch (_) {}
    }

    // Extract episode ID from the URL path segments (digits of length >= 6 in the last segment)
    String? epId;
    try {
      final pathSegments = Uri.parse(url).pathSegments;
      if (pathSegments.isNotEmpty) {
        final lastSegment = pathSegments.last;
        final epIdMatch = RegExp(r'(\d{6,})').firstMatch(lastSegment);
        if (epIdMatch != null) {
          epId = epIdMatch.group(1);
          print("WebViewExtractorService: Detected episode ID: $epId");
        }
      }
    } catch (_) {}

    final List<String> fallbackUrls = [];

    // Local function to handle candidate media URLs
    void handleCandidate(String candidateUrl) {
      if (completer.isCompleted) return;
      
      final lowerCandidate = candidateUrl.toLowerCase();
      if (!isTelegram) {
        // Filter out images ending with .mp4.jpg etc. for non-Telegram platforms
        if (lowerCandidate.contains('.jpg') || 
            lowerCandidate.contains('.jpeg') || 
            lowerCandidate.contains('.png') || 
            lowerCandidate.contains('.webp')) {
          return;
        }
      }
      
      if (isTelegram || (epId != null && candidateUrl.contains(epId))) {
        print("WebViewExtractorService: PERFECT MATCH FOUND (Telegram or contains epId $epId)! -> $candidateUrl");
        completer.complete(candidateUrl);
      } else {
        if (!fallbackUrls.contains(candidateUrl)) {
          print("WebViewExtractorService: Adding fallback candidate -> $candidateUrl");
          fallbackUrls.add(candidateUrl);
        }
      }
    }

    try {
      const userAgent = "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36";

      headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(targetUrl)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
          userAgent: userAgent,
        ),
        onLoadStart: (controller, url) {
          print("WebViewExtractorService: Page loading started: $url");
          
          // Start a periodic poll timer to extract from HTML source as soon as it arrives
          pollTimer?.cancel();
          pollTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) async {
            if (completer.isCompleted) {
              timer.cancel();
              return;
            }
            try {
              if (!isTelegram) {
                final html = await controller.getHtml();
                if (html != null) {
                  final candidates = _extractAllFromHtml(html);
                  for (final c in candidates) {
                    handleCandidate(c);
                  }
                }
              }

              if (isTelegram) {
                try {
                  final mediaUrl = await controller.evaluateJavascript(source: """
                    (function() {
                      // 1. Check for video inside bubble (and support source elements)
                      var video = document.querySelector('.tgme_widget_message_bubble video, .tgme_widget_message_video video, .tgme_widget_message_video_player video, video');
                      if (video) {
                        if (video.src) return video.src;
                        var source = video.querySelector('source');
                        if (source && source.src) return source.src;
                      }
                      
                      // 2. Check for photo wrap inside bubble
                      var photoEl = document.querySelector('.tgme_widget_message_bubble .tgme_widget_message_photo_wrap');
                      if (photoEl) {
                        var bg = window.getComputedStyle(photoEl).backgroundImage;
                        if (bg && bg !== 'none') {
                          var match = bg.match(/url\\(['"]?([^'"]+)['"]?\\)/);
                          if (match && match[1]) return match[1];
                        }
                      }
                      
                      // 3. Check for any img inside bubble
                      var bubbleImgs = document.querySelectorAll('.tgme_widget_message_bubble img');
                      for (var i = 0; i < bubbleImgs.length; i++) {
                        var src = bubbleImgs[i].src;
                        if (src && (src.indexOf('telesco.pe') !== -1 || src.indexOf('telegram.org/file') !== -1)) {
                          if (src.indexOf('emoji') === -1 && src.indexOf('logo') === -1) {
                            return src;
                          }
                        }
                      }
                      return null;
                    })()
                  """);
                  if (mediaUrl != null && mediaUrl.toString().isNotEmpty) {
                    handleCandidate(mediaUrl.toString());
                  }
                } catch (_) {}
              }

              // Periodically trigger play script to ensure the video plays and triggers network capture
              await controller.evaluateJavascript(source: """
                (function() {
                  var videos = document.getElementsByTagName('video');
                  for (var i = 0; i < videos.length; i++) {
                    videos[i].muted = true;
                    videos[i].play().catch(function(e) {});
                  }

                  var playSelectors = [
                    'div[class*="play"]', 
                    'button[class*="play"]', 
                    'i[class*="play"]', 
                    'span[class*="play"]',
                    '.vjs-big-play-button',
                    '.play-btn'
                  ];
                  playSelectors.forEach(function(selector) {
                    var el = document.querySelector(selector);
                    if (el) {
                      el.click();
                    }
                  });
                })();
              """);
            } catch (_) {}
          });
        },
        onLoadStop: (controller, url) async {
          print("WebViewExtractorService: Page loading completed: $url");
          
          // Final check on HTML source
          try {
            if (!isTelegram) {
              final html = await controller.getHtml();
              if (html != null) {
                final candidates = _extractAllFromHtml(html);
                for (final c in candidates) {
                  handleCandidate(c);
                }
              }
            }
          } catch (_) {}

          if (isTelegram) {
            try {
              final mediaUrl = await controller.evaluateJavascript(source: """
                (function() {
                  // 1. Check for video inside bubble (and support source elements)
                  var video = document.querySelector('.tgme_widget_message_bubble video, .tgme_widget_message_video video, .tgme_widget_message_video_player video, video');
                  if (video) {
                    if (video.src) return video.src;
                    var source = video.querySelector('source');
                    if (source && source.src) return source.src;
                  }
                  
                  // 2. Check for photo wrap inside bubble
                  var photoEl = document.querySelector('.tgme_widget_message_bubble .tgme_widget_message_photo_wrap');
                  if (photoEl) {
                    var bg = window.getComputedStyle(photoEl).backgroundImage;
                    if (bg && bg !== 'none') {
                      var match = bg.match(/url\\(['"]?([^'"]+)['"]?\\)/);
                      if (match && match[1]) return match[1];
                    }
                  }
                  
                  // 3. Check for any img inside bubble
                  var bubbleImgs = document.querySelectorAll('.tgme_widget_message_bubble img');
                  for (var i = 0; i < bubbleImgs.length; i++) {
                    var src = bubbleImgs[i].src;
                    if (src && (src.indexOf('telesco.pe') !== -1 || src.indexOf('telegram.org/file') !== -1)) {
                      if (src.indexOf('emoji') === -1 && src.indexOf('logo') === -1) {
                        return src;
                      }
                    }
                  }
                  return null;
                })()
              """);
              if (mediaUrl != null && mediaUrl.toString().isNotEmpty) {
                handleCandidate(mediaUrl.toString());
              }
            } catch (_) {}
          }

          if (completer.isCompleted) return;

          // Inject play script to trigger network player
          await controller.evaluateJavascript(source: """
            (function() {
              console.log("WebViewExtractorService script: running play attempt");
              var videos = document.getElementsByTagName('video');
              for (var i = 0; i < videos.length; i++) {
                videos[i].muted = true;
                videos[i].play().catch(function(e) {});
              }

              var playSelectors = [
                'div[class*="play"]', 
                'button[class*="play"]', 
                'i[class*="play"]', 
                'span[class*="play"]',
                '.vjs-big-play-button',
                '.play-btn'
              ];
              playSelectors.forEach(function(selector) {
                var el = document.querySelector(selector);
                if (el) {
                  el.click();
                }
              });
            })();
          """);

          // Give a brief delay to collect the video URL triggered by player
          await Future.delayed(const Duration(milliseconds: 2000));
          if (!completer.isCompleted && fallbackUrls.isNotEmpty) {
            print("WebViewExtractorService: No perfect match found, returning first fallback: ${fallbackUrls.first}");
            completer.complete(fallbackUrls.first);
          }
        },
        onLoadResource: (controller, resource) {
          final resUrl = resource.url?.toString();
          if (resUrl != null) {
            final lowerUrl = resUrl.toLowerCase();
            if ((lowerUrl.contains('.mp4') || lowerUrl.contains('.m3u8')) &&
                !lowerUrl.contains('analytics') &&
                !lowerUrl.contains('doubleclick') &&
                !lowerUrl.contains('facebook.com') &&
                !lowerUrl.contains('ads') &&
                !lowerUrl.contains('segment') &&
                !lowerUrl.contains('.ts')) {
              
              print("WebViewExtractorService: MATCH FOUND IN NETWORK CAPTURE! -> $resUrl");
              handleCandidate(resUrl);
            }
          }
        },
        onConsoleMessage: (controller, consoleMessage) {
          print("WebViewExtractorService Console: ${consoleMessage.message}");
        },
      );

      print("WebViewExtractorService: Running Headless WebView...");
      await headlessWebView.run();

      // Wait up to 25 seconds for the URL
      final result = await completer.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          print("WebViewExtractorService: Timeout reached, returning null.");
          if (fallbackUrls.isNotEmpty) {
            print("WebViewExtractorService: Timeout fallback: ${fallbackUrls.first}");
            return fallbackUrls.first;
          }
          return null;
        },
      );

      return result;
    } catch (e) {
      print("WebViewExtractorService: Error occurred: $e");
      return null;
    } finally {
      pollTimer?.cancel();
      try {
        print("WebViewExtractorService: Disposing Headless WebView.");
        await headlessWebView?.dispose();
      } catch (_) {}
    }
  }

  /// Extract title, cover, and list of episode URLs/numbers from a DramaBox/NetShort series page using a Headless WebView
  Future<Map<String, dynamic>?> extractSeries(String url) async {
    print("WebViewExtractorService: Start extracting series for: $url");
    final Completer<Map<String, dynamic>?> completer = Completer<Map<String, dynamic>?>();
    HeadlessInAppWebView? headlessWebView;
    
    final lowerUrl = url.toLowerCase();
    final isNetShort = lowerUrl.contains('netshort');
    final isDramaBox = lowerUrl.contains('dramabox') || lowerUrl.contains('dramabite');
    final isTelegram = lowerUrl.contains('t.me') || lowerUrl.contains('telegram.me');
    
    var targetUrl = url;
    if (isTelegram) {
      try {
        final uri = Uri.parse(url);
        final segments = uri.pathSegments;
        if (segments.isNotEmpty) {
          if (segments.first != 's' && segments.first != 'c') {
            targetUrl = "https://t.me/s/${segments.first}";
          }
        }
      } catch (_) {}
      print("WebViewExtractorService Series: Rewrote Telegram channel URL to: $targetUrl");
    }

    try {
      final userAgent = isDramaBox
          ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
          : "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36";

      headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(targetUrl)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
          userAgent: userAgent,
        ),
        onLoadStop: (controller, currentUrl) async {
          print("WebViewExtractorService Series: Page loaded, waiting 2.5s for dynamic content...");
          await Future.delayed(const Duration(milliseconds: 2500));
          
          if (completer.isCompleted) return;
          
          try {
            // 1. Get Title, Cover, and DOM Links using JS
            final jsResult = await controller.evaluateJavascript(source: """
              (function() {
                var title = document.title || '';
                var cover = '';
                var links = [];

                if (window.location.href.indexOf('t.me/s/') !== -1) {
                  var titleEl = document.querySelector('.tgme_channel_info_header_title');
                  if (titleEl) title = titleEl.innerText.trim();
                  
                  var avatarEl = document.querySelector('.tgme_channel_info_header_img img');
                  if (avatarEl) cover = avatarEl.src;
                  
                  var messages = document.querySelectorAll('.tgme_widget_message');
                  for (var i = 0; i < messages.length; i++) {
                    var msg = messages[i];
                    var video = msg.querySelector('video');
                    if (video) {
                      var dateLink = msg.querySelector('a.tgme_widget_message_date');
                      if (dateLink && dateLink.href) {
                        var textEl = msg.querySelector('.tgme_widget_message_text');
                        var text = textEl ? textEl.innerText.trim() : "";
                        links.push({
                          'url': dateLink.href,
                          'title': text
                        });
                      }
                    }
                  }
                } else {
                  var els = document.querySelectorAll('a');
                  for (var i = 0; i < els.length; i++) {
                    var href = els[i].href;
                    if (href) {
                      links.push(href);
                    }
                  }
                  var ogImage = document.querySelector('meta[property="og:image"]');
                  if (ogImage) cover = ogImage.content;
                }
                
                return {
                  title: title,
                  cover: cover,
                  links: links
                };
              })()
            """);

            String? title;
            String? cover;
            List rawLinks = [];

            if (jsResult is Map) {
              title = jsResult['title']?.toString();
              cover = jsResult['cover']?.toString();
              rawLinks = jsResult['links'] as List? ?? [];
            }

            if (title != null && title.isNotEmpty) {
              title = title.replaceAll(RegExp(r'\s*[-|]\s*(DramaBox|DramaBite|NetShort|Watch).*$', caseSensitive: false), '').trim();
            } else {
              title = isDramaBox ? "DramaBox Series" : (isTelegram ? "Telegram Channel" : "Series");
            }

            final List<Map<String, dynamic>> episodes = [];

            if (isTelegram) {
              // Parse Telegram message links
              for (int i = 0; i < rawLinks.length; i++) {
                final item = rawLinks[i];
                if (item is Map) {
                  final epUrl = item['url']?.toString() ?? '';
                  final epTitle = item['title']?.toString() ?? '';
                  if (epUrl.isNotEmpty) {
                    int epNum = i + 1;
                    // Try to find numbers in the post title text
                    final numMatch = RegExp(r'(?:episode|ភាគ|ep|Ep)\s*[-_]?\s*(\d+)', caseSensitive: false).firstMatch(epTitle)
                                  ?? RegExp(r'(\d+)', caseSensitive: false).firstMatch(epTitle);
                    if (numMatch != null) {
                      epNum = int.parse(numMatch.group(1)!);
                    }
                    episodes.add({
                      'url': epUrl,
                      'num': epNum,
                      'title': epTitle.isNotEmpty ? (epTitle.length > 50 ? "${epTitle.substring(0, 50)}..." : epTitle) : "Episode $epNum",
                    });
                  }
                }
              }
            } else {
              // 2. Parse IDs from Page HTML Source
              final html = await controller.getHtml() ?? "";
              final ids = <String>[];
              final idPatterns = [
                RegExp(r'"episodeId"\s*:\s*"(\d+)"'),
                RegExp(r'"episode_id"\s*:\s*(\d+)'),
                RegExp(r'"chapterId"\s*:\s*"(\d+)"'),
                RegExp(r'"id"\s*:\s*"(\d+)".*?"episode"'),
              ];
              
              for (final pattern in idPatterns) {
                final matches = pattern.allMatches(html);
                for (final m in matches) {
                  final id = m.group(1)!;
                  if (!ids.contains(id)) {
                    ids.add(id);
                  }
                }
              }

              print("WebViewExtractorService Series: Found ${ids.length} IDs and ${rawLinks.length} total DOM links");

              final Set<String> seenUrls = {};
              
              // Extract movie ID for DramaBox URL construction
              final movieMatch = RegExp(r'/(?:movie|ep)/(\d+)').firstMatch(url);
              final movieId = movieMatch?.group(1);

              // Build base URL slug for IDs
              var seriesBase = url.split('?')[0];
              if (seriesBase.contains('/episode/')) {
                seriesBase = seriesBase.substring(0, seriesBase.indexOf('/episode/'));
              } else if (seriesBase.contains('/drama/')) {
                seriesBase = seriesBase.substring(0, seriesBase.indexOf('/drama/'));
              } else if (seriesBase.contains('/watch/')) {
                seriesBase = seriesBase.substring(0, seriesBase.indexOf('/watch/'));
              } else if (seriesBase.contains('/movie/')) {
                seriesBase = seriesBase.substring(0, seriesBase.indexOf('/movie/'));
              } else if (seriesBase.contains('/ep/')) {
                seriesBase = seriesBase.substring(0, seriesBase.indexOf('/ep/'));
              }
   
              // Construct URLs from IDs
              if (ids.isNotEmpty) {
                for (int i = 0; i < ids.length; i++) {
                  final id = ids[i];
                  final epNum = i + 1;
                  String epUrl = "$seriesBase/episode/$id";
                  if (isDramaBox && movieId != null) {
                    epUrl = "$seriesBase/ep/$movieId/$id";
                  }
                  if (!seenUrls.contains(epUrl)) {
                    seenUrls.add(epUrl);
                    episodes.add({
                      'url': epUrl,
                      'num': epNum,
                    });
                  }
                }
              }

              // Fallback to DOM Links if IDs are not found or list is short
              for (final rawLink in rawLinks) {
                final String linkStr = rawLink.toString();
                if (linkStr.contains('/episode/') || linkStr.contains('/watch/') || linkStr.contains('/ep/')) {
                  // Ensure it belongs to the same base series domain
                  if (linkStr.contains(seriesBase.replaceFirst('https://www.', '').replaceFirst('https://', ''))) {
                    if (!seenUrls.contains(linkStr)) {
                      seenUrls.add(linkStr);
                      int epNum = episodes.length + 1;
                      final numMatch = RegExp(r'[/-]ep(?:isode)?[-_]?(\d+)', caseSensitive: false).firstMatch(linkStr)
                                    ?? RegExp(r'[_-]ep(?:isode)?[-_]?(\d+)', caseSensitive: false).firstMatch(linkStr)
                                    ?? RegExp(r'episode[-_]?(\d+)', caseSensitive: false).firstMatch(linkStr)
                                    ?? RegExp(r'ep[-_]?(\d+)', caseSensitive: false).firstMatch(linkStr);
                      if (numMatch != null) {
                        epNum = int.parse(numMatch.group(1)!);
                      }
                      episodes.add({
                        'url': linkStr,
                        'num': epNum,
                      });
                    }
                  }
                }
              }
            }

            // Sort by episode number
            episodes.sort((a, b) => (a['num'] as int).compareTo(b['num'] as int));

            completer.complete({
              'title': title,
              'cover': cover ?? '',
              'episodes': episodes,
            });

          } catch (e) {
            print("WebViewExtractorService Series Parsing Error: $e");
            if (!completer.isCompleted) {
              completer.complete(null);
            }
          }
        },
      );

      print("WebViewExtractorService Series: Starting WebView runner...");
      await headlessWebView.run();

      final result = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print("WebViewExtractorService Series: Timeout reached.");
          return null;
        },
      );
      return result;

    } catch (e) {
      print("WebViewExtractorService Series: Failed to run WebView: $e");
      return null;
    } finally {
      try {
        await headlessWebView?.dispose();
      } catch (_) {}
    }
  }
}
