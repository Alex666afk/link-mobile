// Link Search: Link's own search engine, the same as desktop Link (src/main/linkSearch.js).
// Results come from DuckDuckGo's plain HTML page, without its ads, and are shown on a Link page.
import 'package:http/http.dart' as http;

/// DuckDuckGo asked for a bot check instead of giving results (it does this after a burst of searches).
class SearchBlocked implements Exception {}

class SearchResult {
  const SearchResult(this.title, this.url, this.snippet);
  final String title, url, snippet;
}

const _web = 'https://html.duckduckgo.com/html/';
const _userAgent = 'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Mobile Safari/537.36';

// Results and "next page" forms, so going back and forward doesn't search again.
final _cache = <String, List<SearchResult>>{};
final _nextForms = <String, Map<String, String>>{};

String _decode(String s) => s
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll(RegExp(r'&#x27;|&#39;'), "'")
    .replaceAll('&nbsp;', ' ')
    .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)))
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String? _realUrl(String href) {
  final h = href.replaceAll('&amp;', '&');
  final m = RegExp(r'[?&]uddg=([^&]+)').firstMatch(h);
  final url = m != null ? Uri.decodeComponent(m[1]!) : h.startsWith('//') ? 'https:$h' : h;
  return RegExp(r'^https?://', caseSensitive: false).hasMatch(url) ? url : null;
}

List<SearchResult> _parse(String html) {
  final results = <SearchResult>[];
  for (final block in html.split('<div class="result results_links').skip(1)) {
    if (block.substring(0, block.length.clamp(0, 200)).contains('result--ad')) continue; // sponsored
    final a = RegExp(r'class="result__a" href="([^"]+)"[^>]*>([\s\S]*?)</a>').firstMatch(block);
    if (a == null) continue;
    final url = _realUrl(a[1]!);
    if (url == null || url.contains('duckduckgo.com/y.js')) continue;
    final snippet = RegExp(r'class="result__snippet"[^>]*>([\s\S]*?)</a>').firstMatch(block);
    results.add(SearchResult(_decode(a[2]!), url, snippet == null ? '' : _decode(snippet[1]!)));
  }
  return results;
}

Map<String, String>? _parseNextForm(String html) {
  final forms = RegExp(r'<form[^>]*action="/html/"[^>]*>[\s\S]*?</form>').allMatches(html).toList().reversed;
  for (final form in forms) {
    final fields = <String, String>{};
    for (final m in RegExp(r'<input[^>]*name="([^"]+)"[^>]*value="([^"]*)"').allMatches(form[0]!)) {
      fields[m[1]!] = _decode(m[2]!);
    }
    if (fields.containsKey('s') && fields.containsKey('vqd')) return fields;
  }
  return null;
}

Future<List<SearchResult>> linkSearch(String query, int page) async {
  final key = '$query|$page';
  if (_cache.containsKey(key)) return _cache[key]!;
  final headers = {'User-Agent': _userAgent};
  http.Response res;
  if (page == 1) {
    res = await http.get(Uri.parse('$_web?q=${Uri.encodeQueryComponent(query)}&kp=-1'), headers: headers).timeout(const Duration(seconds: 10));
  } else {
    if (!_nextForms.containsKey(key)) await linkSearch(query, page - 1);
    final form = _nextForms[key];
    if (form == null) return const [];
    res = await http.post(Uri.parse(_web), headers: headers, body: form).timeout(const Duration(seconds: 10));
  }
  if (res.statusCode == 202 || res.body.contains('anomaly.js')) throw SearchBlocked();
  if (res.statusCode != 200) throw Exception('Search failed (${res.statusCode})');
  final results = _parse(res.body);
  final next = _parseNextForm(res.body);
  if (next != null) _nextForms['$query|${page + 1}'] = next;
  _cache[key] = results;
  return results;
}

String _escape(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

/// The results page, styled like Link. It's loaded into the tab, so back and forward work as usual.
String resultsPage({
  required String query,
  required int page,
  required List<SearchResult> results,
  required bool dark,
  required String accent,
  String? error,
}) {
  final items = results.map((r) {
    final host = Uri.tryParse(r.url)?.host.replaceFirst(RegExp(r'^www\.'), '') ?? '';
    return '<a class="r" href="${_escape(r.url)}"><span class="h">${_escape(host)}</span>'
        '<span class="t">${_escape(r.title)}</span><span class="s">${_escape(r.snippet)}</span></a>';
  }).join();
  final more = results.isEmpty ? '' : '<a class="more" href="https://link.search/?q=${Uri.encodeQueryComponent(query)}&amp;p=${page + 1}">More results</a>';
  final empty = error != null
      ? '<p class="empty">Couldn’t load results. Check your connection and try again.</p>'
      : results.isEmpty ? '<p class="empty">No results for “${_escape(query)}”.</p>' : '';
  final bg = dark ? '#1e1e1e' : '#ffffff', text = dark ? '#dadada' : '#222222', muted = dark ? '#b3b3b3' : '#5c5c5c';
  final faint = dark ? '#6f6f6f' : '#ababab', border = dark ? '#363636' : '#e3e3e3';
  return '''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${_escape(query)} – Link Search</title><style>
:root{color-scheme:${dark ? 'dark' : 'light'}}
body{margin:0;background:$bg;color:$text;font:15px/1.45 Roboto,-apple-system,"Segoe UI",sans-serif;padding:12px 16px 40px}
.q{font-size:13px;color:$faint;margin:4px 0 8px}
.r{display:block;padding:14px 0;border-bottom:1px solid $border;text-decoration:none;color:inherit}
.h{display:block;font-size:12.5px;color:$muted;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.t{display:block;font-size:17px;color:$accent;margin:2px 0 4px;line-height:1.3}
.s{display:block;font-size:14px;color:$muted}
.more{display:block;margin:20px auto 0;text-align:center;padding:12px;border:1px solid $border;border-radius:10px;color:$text;text-decoration:none;font-weight:500}
.empty{color:$muted;padding:24px 0;text-align:center}
</style></head><body><p class="q">Link Search${page > 1 ? ' · page $page' : ''}</p>$empty$items$more</body></html>''';
}
