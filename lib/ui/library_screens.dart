import 'package:flutter/material.dart';

import '../app.dart';
import '../models/library.dart';
import '../theme.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key, required this.onOpen});
  final void Function(String url) onOpen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: ListenableBuilder(
        listenable: library,
        builder: (context, _) => library.bookmarks.isEmpty
            ? const _Empty('No bookmarks yet. Tap the star in the menu to save a page.')
            : ListView(children: [
                for (final e in library.bookmarks)
                  _EntryTile(entry: e, onOpen: onOpen, onRemove: () => library.removeBookmark(e), icon: Icons.star_border),
              ]),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.onOpen});
  final void Function(String url) onOpen;

  String _day(BuildContext context, DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return MaterialLocalizations.of(context).formatMediumDate(t);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          TextButton(
            onPressed: library.history.isEmpty
                ? null
                : () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Clear history?'),
                        content: const Text('This removes every page from your history on this phone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
                        ],
                      ),
                    );
                    if (ok == true) library.clearHistory();
                  },
            child: const Text('Clear all'),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: library,
        builder: (context, _) {
          if (library.history.isEmpty) return const _Empty('Pages you visit show up here. Private tabs are never saved.');
          final children = <Widget>[];
          String? lastDay;
          for (final e in library.history.take(500)) {
            final day = _day(context, e.time);
            if (day != lastDay) {
              children.add(Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(day, style: TextStyle(color: c.faint, fontSize: 13, fontWeight: FontWeight.w600)),
              ));
              lastDay = day;
            }
            children.add(_EntryTile(entry: e, onOpen: onOpen, onRemove: () => library.removeHistory(e), icon: Icons.history));
          }
          return ListView(children: children);
        },
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.onOpen, required this.onRemove, required this.icon});
  final Entry entry;
  final void Function(String url) onOpen;
  final VoidCallback onRemove;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTile(
      leading: Icon(icon),
      title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(entry.host, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.faint)),
      trailing: IconButton(icon: Icon(Icons.close, size: 20, color: c.faint), tooltip: 'Remove', onPressed: onRemove),
      onTap: () {
        Navigator.pop(context);
        onOpen(entry.url);
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: context.colors.faint, fontSize: 15)),
        ),
      );
}
