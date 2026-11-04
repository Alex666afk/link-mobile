// Bookmarks and history, saved as JSON files on the phone.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class Entry {
  Entry({required this.url, required this.title, DateTime? time, this.visits = 1}) : time = time ?? DateTime.now();
  final String url;
  String title;
  DateTime time;
  int visits;

  Map<String, dynamic> toJson() => {'url': url, 'title': title, 'time': time.millisecondsSinceEpoch, 'visits': visits};
  factory Entry.fromJson(Map<String, dynamic> j) =>
      Entry(url: j['url'], title: j['title'] ?? j['url'], time: DateTime.fromMillisecondsSinceEpoch(j['time'] ?? 0), visits: j['visits'] ?? 1);

  String get host => Uri.tryParse(url)?.host.replaceFirst(RegExp(r'^www\.'), '') ?? url;
}

class Library extends ChangeNotifier {
  List<Entry> bookmarks = [];
  List<Entry> history = [];
  late Directory _dir;
  final _timers = <String, Timer>{};
  static const _historyLimit = 5000;

  Future<void> load() async {
    _dir = await getApplicationSupportDirectory();
    bookmarks = await _read('bookmarks');
    history = await _read('history');
    notifyListeners();
  }

  Future<List<Entry>> _read(String name) async {
    try {
      final list = jsonDecode(await File('${_dir.path}/$name.json').readAsString()) as List;
      return list.map((e) => Entry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // Writes are batched, and go through a temp file so a crash never leaves a half-written file.
  void _save(String name, List<Entry> list) {
    _timers[name]?.cancel();
    _timers[name] = Timer(const Duration(milliseconds: 400), () async {
      final file = File('${_dir.path}/$name.json');
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode(list));
      await temp.rename(file.path);
    });
    notifyListeners();
  }

  bool isBookmarked(String? url) => url != null && bookmarks.any((b) => b.url == url);

  void toggleBookmark(String url, String title) {
    if (isBookmarked(url)) {
      bookmarks.removeWhere((b) => b.url == url);
    } else {
      bookmarks.insert(0, Entry(url: url, title: title.isEmpty ? url : title));
    }
    _save('bookmarks', bookmarks);
  }

  void removeBookmark(Entry e) {
    bookmarks.remove(e);
    _save('bookmarks', bookmarks);
  }

  void visit(String url, String title) {
    if (!url.startsWith('http')) return;
    final existing = history.where((h) => h.url == url).firstOrNull;
    if (existing != null) {
      history.remove(existing);
      existing
        ..visits += 1
        ..time = DateTime.now();
      if (title.isNotEmpty) existing.title = title;
      history.insert(0, existing);
    } else {
      history.insert(0, Entry(url: url, title: title.isEmpty ? url : title));
      if (history.length > _historyLimit) history.removeRange(_historyLimit, history.length);
    }
    _save('history', history);
  }

  void retitle(String url, String title) {
    final h = history.where((h) => h.url == url).firstOrNull;
    if (h != null && title.isNotEmpty && h.title != title) {
      h.title = title;
      _save('history', history);
    }
  }

  void removeHistory(Entry e) {
    history.remove(e);
    _save('history', history);
  }

  void clearHistory() {
    history.clear();
    _save('history', history);
  }

  /// Bookmarks and history that match what's being typed, bookmarks first.
  List<Entry> suggest(String query, {int limit = 6}) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return const [];
    bool hit(Entry e) => e.url.toLowerCase().contains(q) || e.title.toLowerCase().contains(q);
    final seen = <String>{};
    return [...bookmarks.where(hit), ...history.where(hit)].where((e) => seen.add(e.url)).take(limit).toList();
  }

  /// Most visited sites, one per website, for the new tab page.
  List<Entry> topSites({int limit = 8}) {
    final seen = <String>{};
    final sorted = [...history]..sort((a, b) => b.visits.compareTo(a.visits));
    return sorted.where((e) => seen.add(e.host)).take(limit).toList();
  }
}
