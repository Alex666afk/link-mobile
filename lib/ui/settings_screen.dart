import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../app.dart';
import '../services/engines.dart';
import '../services/vpn.dart';
import '../theme.dart';
import '../version.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.onOpen});

  /// Opens a web address in a new tab.
  final void Function(String url) onOpen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: Listenable.merge([settings, blocker, vpn]),
        builder: (context, _) {
          final c = context.colors;
          return ListView(
            children: [
              const _Heading('Search'),
              ListTile(
                leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.asset(settings.engine.icon, width: 24, height: 24)),
                title: const Text('Search engine'),
                subtitle: Text(settings.engine.name, style: TextStyle(color: c.faint)),
                onTap: () => _pickEngine(context),
              ),
              SwitchListTile(
                title: const Text('Search suggestions'),
                subtitle: Text(
                  'Suggestions from your search engine while you type. Never in private tabs.',
                  style: TextStyle(color: c.faint),
                ),
                value: settings.suggestions,
                onChanged: (v) => settings.suggestions = v,
              ),
              if (vpnAvailable) ...[
                const _Heading('VPN'),
                SwitchListTile(
                  secondary: Icon(Icons.vpn_lock_outlined, color: vpn.on ? settings.accent : null),
                  title: const Text('Tor VPN'),
                  subtitle: Text(
                    vpn.error ??
                        switch (vpn.state) {
                          VpnState.off => 'Hides your address by sending pages through the Tor network. Free, with nothing to set up. Slower than a normal connection.',
                          VpnState.starting => 'Connecting to Tor… ${vpn.progress}%. Pages wait until it’s ready.',
                          VpnState.on => 'On. Websites see a Tor address instead of yours.',
                        },
                    style: TextStyle(color: vpn.error != null ? Colors.redAccent : c.faint),
                  ),
                  value: settings.vpn,
                  onChanged: (v) {
                    settings.vpn = v;
                    v ? vpn.start() : vpn.stop();
                  },
                ),
                if (vpn.on)
                  ListTile(
                    leading: const Icon(Icons.autorenew),
                    title: const Text('New address'),
                    subtitle: Text('Switch to new Tor connections, for a different address.', style: TextStyle(color: c.faint)),
                    onTap: () async {
                      final ok = await vpn.newIdentity();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(ok ? 'New address ready for new pages' : 'Couldn’t switch right now')));
                      }
                    },
                  ),
              ],
              const _Heading('Privacy'),
              SwitchListTile(
                title: const Text('Block ads and trackers'),
                subtitle: Text(
                  blocker.domains > 0
                      ? 'Blocks ${blocker.domains.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',')} ad and tracker domains from EasyList and EasyPrivacy.'
                      : 'Downloading the block lists…',
                  style: TextStyle(color: c.faint),
                ),
                value: settings.blockAds,
                onChanged: (v) => settings.blockAds = v,
              ),
              SwitchListTile(
                title: const Text('Always use HTTPS'),
                subtitle: Text('Opens the secure version of sites when there is one.', style: TextStyle(color: c.faint)),
                value: settings.httpsOnly,
                onChanged: (v) => settings.httpsOnly = v,
              ),
              ListTile(
                title: const Text('Clear browsing data'),
                subtitle: Text('History, cookies, site data and cache', style: TextStyle(color: c.faint)),
                onTap: () => _clearData(context),
              ),
              const _Heading('Appearance'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('System')),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (s) => settings.themeMode = s.first,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final color in accents)
                      GestureDetector(
                        onTap: () => settings.accent = color,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: settings.accent == color ? c.text : Colors.transparent, width: 2.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const _Heading('Tabs'),
              SwitchListTile(
                title: const Text('Reopen tabs'),
                subtitle: Text('Bring back your tabs when you start Link. Private tabs never come back.', style: TextStyle(color: c.faint)),
                value: settings.restoreTabs,
                onChanged: (v) => settings.restoreTabs = v,
              ),
              const _Heading('About'),
              ListTile(
                leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/icon.png', width: 36, height: 36)),
                title: const Text('Link $appVersion'),
                subtitle: Text('Free and open source. A Northwire project.', style: TextStyle(color: c.faint)),
              ),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('Report a bug'),
                subtitle: Text('Tell us what went wrong in this version.', style: TextStyle(color: c.faint)),
                onTap: () => _open(context, 'https://link.northwire.app/report/link/android/$appVersion'),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Source code'),
                onTap: () => _open(context, 'https://github.com/Alex666afk/link-mobile'),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Open source licenses'),
                subtitle: Text('Including Tor and the libraries it uses.', style: TextStyle(color: c.faint)),
                onTap: () => showLicensePage(context: context, applicationName: 'Link', applicationVersion: appVersion),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  void _open(BuildContext context, String url) {
    Navigator.pop(context);
    onOpen(url);
  }

  Future<void> _pickEngine(BuildContext context) async {
    final picked = await showModalBottomSheet<SearchEngine>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in engines)
                ListTile(
                  leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.asset(e.icon, width: 24, height: 24)),
                  title: Text(e.name),
                  trailing: e.id == settings.engine.id ? Icon(Icons.check, color: settings.accent) : null,
                  onTap: () => Navigator.pop(context, e),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) settings.engine = picked;
  }

  Future<void> _clearData(BuildContext context) async {
    var history = true, cookies = true, cache = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Clear browsing data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('History'),
                value: history,
                onChanged: (v) => setState(() => history = v!),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Cookies and site data'),
                subtitle: const Text('Signs you out of most sites'),
                value: cookies,
                onChanged: (v) => setState(() => cookies = v!),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Cached images and files'),
                value: cache,
                onChanged: (v) => setState(() => cache = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (history) library.clearHistory();
    if (cookies) {
      await CookieManager.instance().deleteAllCookies();
      await WebStorageManager.instance().deleteAllData();
    }
    if (cache) await InAppWebViewController.clearAllCache();
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cleared')));
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 6),
    child: Text(
      text,
      style: TextStyle(color: settings.accent, fontWeight: FontWeight.w600, fontSize: 13),
    ),
  );
}
