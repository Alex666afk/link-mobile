import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:share_plus/share_plus.dart';

import '../app.dart';
import '../models/tabs.dart';
import '../services/engines.dart';
import '../services/native.dart';
import '../services/vpn.dart';
import '../theme.dart';
import '../version.dart';
import 'address_screen.dart';
import 'library_screens.dart';
import 'new_tab.dart';
import 'settings_screen.dart';
import 'tabs_screen.dart';
import 'web_tab.dart';

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> implements BrowserContext {
  BrowserTab get tab => tabs.current;
  bool _finding = false;
  final _findText = TextEditingController();
  final _activated = <int>{};

  @override
  bool get dark => Theme.of(context).brightness == Brightness.dark;

  @override
  void showMessage(String text, {String? action, VoidCallback? onAction}) {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        action: action == null ? null : SnackBarAction(label: action, onPressed: onAction ?? () {}),
      ),
    );
  }

  @override
  Future<bool> confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
          ],
        ),
      ) ??
      false;

  @override
  void initState() {
    super.initState();
    tabs.addListener(_rebuild);
    vpn.addListener(_rebuild);
    vpn.onConnected = () => tab.home ? null : _reload();
    blocker.addListener(_applyBlocking);
    settings.addListener(_applyBlocking);
    Native.onOpenUrl(_openFromApp);
    Native.initialUrl().then((url) {
      if (url != null) _openFromApp(url);
    });
  }

  @override
  void dispose() {
    tabs.removeListener(_rebuild);
    vpn.removeListener(_rebuild);
    blocker.removeListener(_applyBlocking);
    settings.removeListener(_applyBlocking);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  // A link shared with Link or opened from another app: always a new tab.
  void _openFromApp(String text) {
    final match = RegExp(r'https?://\S+').firstMatch(text);
    final address = match?[0] ?? addressFor(text, settings.engine);
    final tab = tabs.open();
    navigate(this, tab, address);
  }

  Future<void> _applyBlocking() async {
    for (final t in tabs.all) {
      await t.controller?.setSettings(settings: InAppWebViewSettings(contentBlockers: settings.blockAds ? blocker.rules : const []));
    }
  }

  Future<void> _openAddress() async {
    final current = tab.home ? null : (searchQuery(tab.url) ?? tab.url);
    final input = await Navigator.of(context).push<String>(
      PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 160),
        pageBuilder: (_, _, _) => AddressScreen(initial: current, private: tab.private),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
    if (input != null && input.trim().isNotEmpty) navigate(this, tab, addressFor(input, settings.engine));
  }

  Future<void> _openTabs() async {
    await tab.capture();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TabsScreen(browser: this)));
  }

  Future<void> _back() async {
    if (_finding) return _closeFind();
    if (!tab.home && tab.canGoBack) return tab.controller?.goBack();
    if (!tab.home && tab.windowId == null && tab.opener == null) {
      tab.home = true;
      return tab.changed();
    }
    if (tab.opener != null || tab.windowId != null) return tabs.close(tab);
    SystemNavigator.pop();
  }

  void _closeFind() {
    tab.find.clearMatches();
    setState(() => _finding = false);
    _findText.clear();
  }

  @override
  Widget build(BuildContext context) {
    _activated.add(tab.id);
    final c = context.colors;
    final private = tab.private;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _back(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: (dark || private) ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: private ? LinkColors.privateBackground : c.primary,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            bottom: false,
            child: ListenableBuilder(
              listenable: tab,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _pages()),
                  if (_finding) _findBar(c),
                  if (vpn.state == VpnState.starting) _vpnBanner(c),
                  _bottomBar(c),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Every tab that has been opened keeps its page; only the current one is visible.
  Widget _pages() {
    final index = tabs.all.indexOf(tab);
    return Stack(
      fit: StackFit.expand,
      children: [
        IndexedStack(
          index: index,
          sizing: StackFit.expand,
          children: [
            for (final t in tabs.all)
              t.created && _activated.contains(t.id)
                  ? WebTab(key: ValueKey(t.id), tab: t, browser: this)
                  : const SizedBox.shrink(key: ValueKey('empty')),
          ],
        ),
        if (tab.home)
          Positioned.fill(
            child: NewTabPage(private: tab.private, onSearch: _openAddress, onOpen: (url) => navigate(this, tab, url)),
          ),
      ],
    );
  }

  Widget _findBar(LinkColors c) {
    return Container(
      color: tab.private ? LinkColors.privateBackground : c.primaryAlt,
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _findText,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Find in page', border: InputBorder.none),
              onChanged: (text) => text.isEmpty ? tab.find.clearMatches() : tab.find.findAll(find: text),
              onSubmitted: (_) => tab.find.findNext(forward: true),
            ),
          ),
          if (_findText.text.isNotEmpty)
            Text(tab.findCount == 0 ? '0/0' : '${tab.findActive + 1}/${tab.findCount}', style: TextStyle(color: c.muted)),
          IconButton(icon: const Icon(Icons.keyboard_arrow_up), onPressed: () => tab.find.findNext(forward: false)),
          IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: () => tab.find.findNext(forward: true)),
          IconButton(icon: const Icon(Icons.close), onPressed: _closeFind),
        ],
      ),
    );
  }

  Widget _bottomBar(LinkColors c) {
    final private = tab.private;
    final bar = private ? LinkColors.privateBackground : c.primaryAlt;
    final field = private ? const Color(0xFF2A2140) : c.field;
    final text = private ? Colors.white : c.text;
    final query = searchQuery(tab.url);
    final uri = Uri.tryParse(tab.url ?? '');
    final label = tab.home
        ? (private ? 'Search privately' : 'Search or type address')
        : query ?? (uri?.host.replaceFirst(RegExp(r'^www\.'), '') ?? tab.url ?? '');
    final secure = uri?.scheme == 'https';
    return Material(
      color: bar,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 2,
              child: tab.loading && !tab.home
                  ? LinearProgressIndicator(
                      value: tab.progress / 100,
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                      color: settings.accent,
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    color: private ? Colors.white70 : c.icon,
                    disabledColor: private ? Colors.white24 : c.faint.withValues(alpha: 0.5),
                    icon: const Icon(Icons.arrow_back),
                    onPressed: tab.home ? null : _back,
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _openAddress,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.only(left: 14, right: 4),
                        decoration: BoxDecoration(color: field, borderRadius: BorderRadius.circular(22)),
                        child: Row(
                          children: [
                            Icon(
                              vpn.on
                                  ? Icons.vpn_lock
                                  : tab.home || query != null
                                  ? Icons.search
                                  : secure
                                  ? Icons.lock_outline
                                  : Icons.info_outline,
                              size: 18,
                              color: vpn.on
                                  ? settings.accent
                                  : private
                                  ? Colors.white60
                                  : c.faint,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                label,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: tab.home ? (private ? Colors.white60 : c.faint) : text, fontSize: 15),
                              ),
                            ),
                            if (!tab.home)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(tab.loading ? Icons.close : Icons.refresh, size: 20, color: private ? Colors.white70 : c.icon),
                                onPressed: () => tab.loading ? tab.controller?.stopLoading() : _reload(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _TabCount(
                    count: tabs.all.where((t) => t.private == private).length,
                    color: private ? Colors.white : c.icon,
                    onTap: _openTabs,
                  ),
                  IconButton(
                    tooltip: 'Menu',
                    icon: Icon(Icons.more_vert, color: private ? Colors.white70 : c.icon),
                    onPressed: _menu,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _reload() {
    if (isLinkSearch(tab.url)) {
      showLinkSearch(this, tab, tab.url!);
    } else {
      tab.controller?.reload();
    }
  }

  Future<void> _menu() async {
    final c = context.colors;
    final url = tab.home ? null : tab.url;
    final bookmarked = library.isBookmarked(url);
    Widget action(IconData icon, String label, VoidCallback? onTap, {bool active = false}) => Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap == null
            ? null
            : () {
                Navigator.pop(context);
                onTap();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(
                icon,
                color: onTap == null
                    ? c.faint
                    : active
                    ? settings.accent
                    : c.icon,
              ),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 12, color: onTap == null ? c.faint : c.muted)),
            ],
          ),
        ),
      ),
    );
    Widget item(IconData icon, String label, VoidCallback onTap, {Widget? trailing}) => ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: trailing,
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    action(Icons.arrow_forward, 'Forward', !tab.home && tab.canGoForward ? () => tab.controller?.goForward() : null),
                    action(
                      bookmarked ? Icons.star : Icons.star_border,
                      bookmarked ? 'Saved' : 'Bookmark',
                      url == null ? null : () => library.toggleBookmark(url, tab.title),
                      active: bookmarked,
                    ),
                    action(
                      Icons.share_outlined,
                      'Share',
                      url == null ? null : () => SharePlus.instance.share(ShareParams(uri: Uri.parse(url))),
                    ),
                    action(Icons.refresh, 'Reload', url == null ? null : _reload),
                  ],
                ),
              ),
              const Divider(),
              item(Icons.add, 'New tab', () => tabs.open()),
              item(Icons.visibility_off_outlined, 'New private tab', () => tabs.open(private: true)),
              item(Icons.bookmark_border, 'Bookmarks', () => _push(BookmarksScreen(onOpen: (u) => navigate(this, tab, u)))),
              item(Icons.history, 'History', () => _push(HistoryScreen(onOpen: (u) => navigate(this, tab, u)))),
              item(Icons.download_outlined, 'Downloads', Native.openDownloads),
              if (vpnAvailable)
                item(
                  Icons.vpn_lock_outlined,
                  vpn.state == VpnState.starting ? 'VPN · connecting ${vpn.progress}%' : 'VPN',
                  _toggleVpn,
                  trailing: Switch(
                    value: settings.vpn,
                    onChanged: (_) {
                      Navigator.pop(context);
                      _toggleVpn();
                    },
                  ),
                ),
              if (url != null) item(Icons.search, 'Find in page', () => setState(() => _finding = true)),
              if (url != null)
                item(
                  Icons.desktop_windows_outlined,
                  'Desktop site',
                  _toggleDesktop,
                  trailing: Switch(
                    value: tab.desktop,
                    onChanged: (_) {
                      Navigator.pop(context);
                      _toggleDesktop();
                    },
                  ),
                ),
              item(Icons.settings_outlined, 'Settings', () => _push(SettingsScreen(onOpen: (url) => navigate(this, tabs.open(private: tab.private), url)))),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleVpn() {
    settings.vpn = !settings.vpn;
    settings.vpn ? vpn.start() : vpn.stop();
    showMessage(settings.vpn ? 'Connecting to Tor…' : 'VPN off');
  }

  Widget _vpnBanner(LinkColors c) => Container(
    color: tab.private ? LinkColors.privateBackground : c.primaryAlt,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: settings.accent, value: vpn.progress > 0 ? vpn.progress / 100 : null),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Connecting to Tor… ${vpn.progress}%. Pages wait until it’s ready.',
            style: TextStyle(color: tab.private ? Colors.white70 : c.muted, fontSize: 13),
          ),
        ),
      ],
    ),
  );

  Future<void> _toggleDesktop() async {
    tab.desktop = !tab.desktop;
    await tab.controller?.setSettings(
      settings: InAppWebViewSettings(
        preferredContentMode: tab.desktop ? UserPreferredContentMode.DESKTOP : UserPreferredContentMode.RECOMMENDED,
      ),
    );
    await tab.controller?.reload();
    tab.changed();
  }

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

class _TabCount extends StatelessWidget {
  const _TabCount({required this.count, required this.color, required this.onTap});
  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Tabs',
      onPressed: onTap,
      icon: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.8),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
