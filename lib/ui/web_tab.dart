// One tab's website: the WebView and everything that reacts to it.
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../app.dart';
import '../models/tabs.dart';
import '../services/engines.dart';
import '../services/link_search.dart';
import '../services/native.dart';
import '../theme.dart';

const _searchHost = 'link.search';

// Hosts that failed over HTTPS, so they're loaded over HTTP from then on.
final _httpOnly = <String>{};

bool isLinkSearch(String? url) => Uri.tryParse(url ?? '')?.host == _searchHost;

/// The query on a Link Search page, shown in the address bar instead of the page address.
String? searchQuery(String? url) => isLinkSearch(url) ? Uri.parse(url!).queryParameters['q'] : null;

String? _upgrade(String address) {
  final uri = Uri.tryParse(address);
  if (!settings.httpsOnly || uri == null || uri.scheme != 'http') return null;
  final host = uri.host;
  if (_httpOnly.contains(host) || host == 'localhost' || RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(host)) return null;
  return uri.replace(scheme: 'https').toString();
}

/// Opens an address in a tab: a website, or a Link Search page.
Future<void> navigate(BrowserContext context, BrowserTab tab, String address) async {
  address = _upgrade(address) ?? address;
  tab.home = false;
  if (!tab.created || tab.controller == null) {
    tab.start = address;
    tab.changed();
    tabs.save();
    return; // the WebView loads it when it's created
  }
  tab.changed();
  if (isLinkSearch(address)) return showLinkSearch(context, tab, address);
  await tab.controller!.loadUrl(urlRequest: URLRequest(url: WebUri(address)));
}

/// Fetches Link Search results and shows them as a page in the tab.
Future<void> showLinkSearch(BrowserContext context, BrowserTab tab, String address) async {
  final uri = Uri.parse(address);
  final query = uri.queryParameters['q'] ?? '';
  final page = int.tryParse(uri.queryParameters['p'] ?? '') ?? 1;
  tab
    ..url = address
    ..title = query
    ..progress = 30
    ..changed();
  String html;
  final dark = context.dark;
  try {
    final results = await linkSearch(query, page);
    html = resultsPage(query: query, page: page, results: results, dark: dark, accent: colorHex(settings.accent));
  } on SearchBlocked {
    // The full DuckDuckGo site passes the bot check in a real browser, and is just as private.
    await tab.controller?.loadUrl(urlRequest: URLRequest(url: WebUri(engineById('duckduckgo').searchUrl(query))));
    return;
  } catch (e) {
    debugPrint('Link Search failed: $e');
    html = resultsPage(query: query, page: page, results: const [], dark: dark, accent: colorHex(settings.accent), error: '$e');
  }
  await tab.controller?.loadData(data: html, baseUrl: WebUri(address), historyUrl: WebUri(address), mimeType: 'text/html', encoding: 'utf-8');
  if (!tab.private) library.visit(address, '$query – Link Search');
}

/// What the WebView needs from the screen around it.
abstract class BrowserContext {
  bool get dark;
  void showMessage(String text, {String? action, VoidCallback? onAction});
  Future<bool> confirm(String title, String message, String action);
}

class WebTab extends StatefulWidget {
  const WebTab({super.key, required this.tab, required this.browser});
  final BrowserTab tab;
  final BrowserContext browser;

  @override
  State<WebTab> createState() => _WebTabState();
}

class _WebTabState extends State<WebTab> {
  BrowserTab get tab => widget.tab;

  InAppWebViewSettings get _settings => InAppWebViewSettings(
        incognito: tab.private,
        contentBlockers: settings.blockAds ? blocker.rules : const [],
        useShouldOverrideUrlLoading: true,
        useOnDownloadStart: true,
        supportMultipleWindows: true,
        javaScriptCanOpenWindowsAutomatically: true,
        mediaPlaybackRequiresUserGesture: true,
        allowsInlineMediaPlayback: true,
        builtInZoomControls: true,
        displayZoomControls: false,
        supportZoom: true,
        thirdPartyCookiesEnabled: true,
        preferredContentMode: tab.desktop ? UserPreferredContentMode.DESKTOP : UserPreferredContentMode.RECOMMENDED,
        isFraudulentWebsiteWarningEnabled: true,
        safeBrowsingEnabled: true,
      );

  void _update(WebUri? url) {
    if (url != null) tab.url = url.toString();
    tab.changed();
  }

  @override
  Widget build(BuildContext context) {
    final start = tab.start;
    return InAppWebView(
      windowId: tab.windowId,
      initialUrlRequest: start != null && !isLinkSearch(start) ? URLRequest(url: WebUri(start)) : null,
      initialSettings: _settings,
      findInteractionController: tab.find,
      onWebViewCreated: (controller) {
        tab.controller = controller;
        if (start != null && isLinkSearch(start)) showLinkSearch(widget.browser, tab, start);
      },
      onLoadStart: (controller, url) {
        tab.progress = 5;
        _update(url);
      },
      onProgressChanged: (controller, progress) {
        tab.progress = progress;
        tab.changed();
      },
      onLoadStop: (controller, url) async {
        tab.progress = 100;
        _update(url);
        final title = await controller.getTitle() ?? '';
        if (title.isNotEmpty) tab.title = title;
        if (!tab.private && url != null && !isLinkSearch(url.toString())) library.visit(url.toString(), tab.title);
        await tab.refreshNavigation();
      },
      onUpdateVisitedHistory: (controller, url, isReload) async {
        _update(url);
        await tab.refreshNavigation();
        if (!tab.private) tabs.save();
      },
      onTitleChanged: (controller, title) {
        if (title == null || title.isEmpty) return;
        tab.title = title;
        tab.changed();
        if (!tab.private && tab.url != null) library.retitle(tab.url!, title);
      },
      shouldOverrideUrlLoading: (controller, action) async {
        final url = action.request.url?.toString() ?? '';
        if (!action.isForMainFrame) return NavigationActionPolicy.ALLOW;
        if (isLinkSearch(url)) {
          showLinkSearch(widget.browser, tab, url);
          return NavigationActionPolicy.CANCEL;
        }
        final https = _upgrade(url);
        if (https != null) {
          controller.loadUrl(urlRequest: URLRequest(url: WebUri(https)));
          return NavigationActionPolicy.CANCEL;
        }
        // Links to other apps (mail, phone, maps, app stores…) aren't web pages.
        final scheme = action.request.url?.scheme ?? 'https';
        if (!const ['http', 'https', 'about', 'data', 'blob', 'javascript', 'file'].contains(scheme)) {
          widget.browser.showMessage('This link opens another app, which Link doesn’t do yet.');
          return NavigationActionPolicy.CANCEL;
        }
        return NavigationActionPolicy.ALLOW;
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame != true) return;
        // HTTPS didn't work for this site: load it over HTTP instead, once.
        final url = request.url;
        if (settings.httpsOnly && url.scheme == 'https' && !_httpOnly.contains(url.host) &&
            [WebResourceErrorType.FAILED_SSL_HANDSHAKE, WebResourceErrorType.CANNOT_CONNECT_TO_HOST, WebResourceErrorType.SECURE_CONNECTION_FAILED]
                .contains(error.type)) {
          _httpOnly.add(url.host);
          controller.loadUrl(urlRequest: URLRequest(url: WebUri(url.toString().replaceFirst('https://', 'http://'))));
        }
      },
      onCreateWindow: (controller, action) async {
        tabs.open(windowId: action.windowId, private: tab.private, opener: tab);
        return true;
      },
      onCloseWindow: (controller) => tabs.close(tab),
      onDownloadStartRequest: (controller, request) async {
        final name = request.suggestedFilename ?? request.url.pathSegments.lastOrNull ?? 'download';
        if (!request.url.scheme.startsWith('http')) {
          widget.browser.showMessage('This file can’t be downloaded yet.');
          return;
        }
        // Android's download manager can't use the VPN, so ask first.
        if (vpn.active &&
            !await widget.browser.confirm('Download without the VPN?',
                'Downloads go through Android, which can’t use Tor. The site will see your real address for this file.', 'Download')) {
          return;
        }
        final started = await Native.download(
          url: request.url.toString(),
          fileName: request.suggestedFilename,
          mimeType: request.mimeType,
          contentDisposition: request.contentDisposition,
          userAgent: request.userAgent,
          private: tab.private,
        );
        widget.browser.showMessage(started ? 'Downloading $name' : 'Couldn’t download $name',
            action: started ? 'Open' : null, onAction: Native.openDownloads);
      },
    );
  }
}
