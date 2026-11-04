import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/native.dart';
import 'settings.dart';

int _nextId = 0;

class BrowserTab extends ChangeNotifier {
  BrowserTab({required this.private, String? address, this.windowId, this.opener})
      : id = _nextId++,
        start = address,
        home = address == null && windowId == null {
    find = FindInteractionController(onFindResultReceived: (controller, active, count, done) {
      findActive = active;
      findCount = count;
      notifyListeners();
    });
  }

  final int id;
  final bool private;

  /// Set when a page opened this tab (a link with target=_blank). Closing it goes back to the opener.
  final int? windowId;
  BrowserTab? opener;

  /// The address the tab's WebView starts with. The WebView is only created once it's needed.
  String? start;
  bool get created => start != null || windowId != null;

  /// Showing the new tab page instead of the website.
  bool home;

  InAppWebViewController? controller;
  late final FindInteractionController find;
  String? url;
  String title = '';
  int progress = 100;
  bool canGoBack = false, canGoForward = false;
  bool desktop = false;
  Uint8List? thumbnail;
  int findActive = 0, findCount = 0;

  bool get loading => progress < 100;

  void changed() => notifyListeners();

  Future<void> refreshNavigation() async {
    final c = controller;
    if (c == null) return;
    canGoBack = await c.canGoBack();
    canGoForward = await c.canGoForward();
    notifyListeners();
  }

  /// A small picture of the page for the tab switcher.
  Future<void> capture() async {
    if (home || controller == null) return;
    try {
      thumbnail = await controller!.takeScreenshot(
        screenshotConfiguration: ScreenshotConfiguration(compressFormat: CompressFormat.JPEG, quality: 55),
      );
    } catch (_) {}
  }
}

class Tabs extends ChangeNotifier {
  Tabs(this.settings);
  final Settings settings;

  final List<BrowserTab> all = [];
  BrowserTab? _current;
  BrowserTab get current => _current!;

  List<BrowserTab> get normal => all.where((t) => !t.private).toList();
  List<BrowserTab> get private => all.where((t) => t.private).toList();

  void restore() {
    final saved = settings.restoreTabs ? settings.savedTabs : const <String>[];
    for (final url in saved) {
      all.add(BrowserTab(private: false, address: url.isEmpty ? null : url));
    }
    if (all.isEmpty) all.add(BrowserTab(private: false));
    _current = all.last;
  }

  BrowserTab open({String? address, bool private = false, int? windowId, BrowserTab? opener}) {
    final tab = BrowserTab(private: private, address: address, windowId: windowId, opener: opener);
    final at = opener != null ? all.indexOf(opener) + 1 : all.length;
    all.insert(at, tab);
    _current = tab;
    save();
    notifyListeners();
    return tab;
  }

  void select(BrowserTab tab) {
    _current = tab;
    notifyListeners();
  }

  void close(BrowserTab tab) {
    final index = all.indexOf(tab);
    if (index < 0) return;
    all.removeAt(index);
    if (_current == tab) {
      final sameKind = all.where((t) => t.private == tab.private).toList();
      _current = tab.opener != null && all.contains(tab.opener)
          ? tab.opener
          : sameKind.isNotEmpty ? sameKind.last : all.isNotEmpty ? all.last : null;
    }
    if (all.isEmpty) _current = open();
    if (tab.private && private.isEmpty) _clearPrivateSoon();
    save();
    notifyListeners();
  }

  void closeAll({required bool private}) {
    final closing = all.where((t) => t.private == private).toList();
    for (final tab in closing) {
      all.remove(tab);
    }
    if (private) _clearPrivateSoon();
    if (!all.contains(_current)) _current = all.isNotEmpty ? all.last : null;
    if (all.isEmpty) _current = open();
    save();
    notifyListeners();
  }

  // The private WebViews have to be gone before their storage can be deleted.
  void _clearPrivateSoon() {
    Timer(const Duration(seconds: 2), () {
      if (private.isEmpty) Native.clearPrivate();
    });
  }

  Timer? _saveTimer;

  /// Remembers the normal tabs so they come back next time. Private tabs are never saved.
  void save() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      settings.savedTabs = [for (final t in normal) t.home ? '' : (t.url ?? t.start ?? '')];
    });
  }
}
