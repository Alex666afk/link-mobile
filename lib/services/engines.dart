// The same built-in search engines as desktop Link (src/main/store.js).
class SearchEngine {
  const SearchEngine(this.id, this.name, this.url, {this.suggest = ''});
  final String id, name, url, suggest;

  String get icon => id == 'link' ? 'assets/icon.png' : 'assets/brands/$id.png';
  String searchUrl(String query) => url.replaceAll('%s', Uri.encodeQueryComponent(query));
}

const engines = [
  SearchEngine('link', 'Link Search', 'https://link.search/?q=%s', suggest: 'https://duckduckgo.com/ac/?q=%s&type=list'),
  SearchEngine('duckduckgo', 'DuckDuckGo', 'https://duckduckgo.com/?q=%s', suggest: 'https://duckduckgo.com/ac/?q=%s&type=list'),
  SearchEngine('google', 'Google', 'https://www.google.com/search?q=%s', suggest: 'https://suggestqueries.google.com/complete/search?client=firefox&q=%s'),
  SearchEngine('brave', 'Brave Search', 'https://search.brave.com/search?q=%s', suggest: 'https://search.brave.com/api/suggest?q=%s'),
  SearchEngine('bing', 'Bing', 'https://www.bing.com/search?q=%s', suggest: 'https://api.bing.com/osjson.aspx?query=%s'),
  SearchEngine('startpage', 'Startpage', 'https://www.startpage.com/do/search?q=%s'),
  SearchEngine('ecosia', 'Ecosia', 'https://www.ecosia.org/search?q=%s', suggest: 'https://ac.ecosia.org/autocomplete?q=%s&type=list'),
  SearchEngine('qwant', 'Qwant', 'https://www.qwant.com/?q=%s'),
  SearchEngine('mojeek', 'Mojeek', 'https://www.mojeek.com/search?q=%s'),
  SearchEngine('yahoo', 'Yahoo', 'https://search.yahoo.com/search?p=%s'),
  SearchEngine('youtube', 'YouTube', 'https://www.youtube.com/results?search_query=%s'),
  SearchEngine('wikipedia', 'Wikipedia', 'https://en.wikipedia.org/wiki/Special:Search?search=%s'),
  SearchEngine('github', 'GitHub', 'https://github.com/search?q=%s'),
];

SearchEngine engineById(String id) => engines.firstWhere((e) => e.id == id, orElse: () => engines.first);

/// Turns what was typed in the address bar into a web address: a URL as it is, anything else as a search.
String addressFor(String input, SearchEngine engine) {
  final text = input.trim();
  if (RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false).hasMatch(text) || text.startsWith('about:')) return text;
  final looksLikeHost = !text.contains(' ') &&
      (RegExp(r'^[^\s/]+\.[a-z]{2,}(:\d+)?(/.*)?$', caseSensitive: false).hasMatch(text) ||
          RegExp(r'^(localhost|\d{1,3}(\.\d{1,3}){3})(:\d+)?(/.*)?$').hasMatch(text));
  return looksLikeHost ? 'https://$text' : engine.searchUrl(text);
}
