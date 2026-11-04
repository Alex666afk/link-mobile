// Link Protect: ad and tracker blocking from the same lists as desktop Link (EasyList and EasyPrivacy).
// The lists are downloaded on first start and refreshed once a week. Only rules that block a whole
// domain are used; they become a few WebView content-blocker rules.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

const _lists = [
  'https://easylist.to/easylist/easylist.txt',
  'https://easylist.to/easylist/easyprivacy.txt',
];
const _maxAge = Duration(days: 7);

// Common ad slots that are hidden even when the ad itself came from the site.
const _adSelectors = '.adsbygoogle, ins.adsbygoogle, [id^="google_ads_iframe"], [id^="div-gpt-ad"], '
    '.ad-banner, #ad-banner, .ad-container, .ad-slot, [data-ad-slot], [aria-label="Advertisement"]';

class Blocker extends ChangeNotifier {
  List<ContentBlocker> rules = const [];
  int domains = 0;

  Future<File> get _file async => File('${(await getApplicationSupportDirectory()).path}/blocklist.txt');

  /// Loads the saved list right away, and downloads a fresh one in the background if it's old or missing.
  Future<void> load() async {
    final file = await _file;
    if (await file.exists()) _use((await file.readAsString()).split('\n'));
    final stale = !await file.exists() || DateTime.now().difference(await file.lastModified()) > _maxAge;
    if (stale) unawaited(_refresh(file));
  }

  Future<void> _refresh(File file) async {
    try {
      final found = <String>{};
      for (final url in _lists) {
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
        if (res.statusCode == 200) found.addAll(domainRules(res.body));
      }
      if (found.length < 1000) return; // a broken download; keep what we had
      final list = found.toList()..sort();
      await file.writeAsString(list.join('\n'));
      _use(list);
    } catch (_) {
      // Offline: try again next start.
    }
  }

  void _use(List<String> list) {
    final clean = list.where((d) => d.isNotEmpty).toList();
    domains = clean.length;
    rules = _buildRules(clean);
    notifyListeners();
  }
}

/// "||ads.example.com^" and "||ads.example.com^$third-party" block a whole domain; other rules are skipped.
@visibleForTesting
Iterable<String> domainRules(String list) sync* {
  final rule = RegExp(r'^\|\|([a-z0-9][a-z0-9.-]*\.[a-z]{2,})\^(\$third-party)?$');
  for (final line in list.split('\n')) {
    final m = rule.firstMatch(line.trim());
    if (m != null) yield m[1]!;
  }
}

List<ContentBlocker> _buildRules(List<String> domains) {
  final cosmetic = ContentBlocker(
    trigger: ContentBlockerTrigger(urlFilter: '.*'),
    action: ContentBlockerAction(type: ContentBlockerActionType.CSS_DISPLAY_NONE, selector: _adSelectors),
  );
  if (domains.isEmpty) return [cosmetic];

  // WebKit (iOS) compiles one rule per domain efficiently but doesn't support "|" in patterns.
  if (Platform.isIOS) {
    return [
      for (final d in domains)
        ContentBlocker(
          trigger: ContentBlockerTrigger(urlFilter: '^https?://([^/]*\\.)?${d.replaceAll('.', '\\.')}[:/]'),
          action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
        ),
      cosmetic,
    ];
  }

  // Android checks every rule against every request, so domains are grouped by first letter into a
  // few patterns. Each is a tree (doubleclick|doubleverify -> double(?:click|verify)), which keeps matching fast.
  final groups = <String, List<String>>{};
  for (final d in domains) {
    groups.putIfAbsent(d[0], () => []).add(d);
  }
  return [
    for (final group in groups.values)
      ContentBlocker(
        trigger: ContentBlockerTrigger(urlFilter: domainPattern(group)),
        action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
      ),
    cosmetic,
  ];
}

/// One pattern matching a whole web address on any of [domains] or their subdomains.
@visibleForTesting
String domainPattern(List<String> domains) => '^https?://([^/:?#]*\\.)?${_trie(domains)}([:/?#].*)?\$';

class _Node {
  final children = <String, _Node>{};
  bool end = false;
}

String _trie(List<String> words) {
  final root = _Node();
  for (final word in words) {
    var node = root;
    for (final ch in word.split('')) {
      node = node.children.putIfAbsent(ch, _Node.new);
    }
    node.end = true;
  }
  return _emit(root);
}

String _emit(_Node node) {
  final keys = node.children.keys.toList()..sort();
  final parts = [for (final k in keys) (k == '.' ? '\\.' : k) + _emit(node.children[k]!)];
  if (parts.isEmpty) return '';
  final body = parts.length == 1 ? parts.first : '(?:${parts.join('|')})';
  return node.end ? '(?:$body)?' : body;
}
