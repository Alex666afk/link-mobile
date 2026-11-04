import 'package:flutter/material.dart';

import '../app.dart';
import '../models/library.dart';
import '../services/native.dart';
import '../theme.dart';

class NewTabPage extends StatelessWidget {
  const NewTabPage({super.key, required this.private, required this.onSearch, required this.onOpen});
  final bool private;
  final VoidCallback onSearch;
  final void Function(String url) onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (private) return _PrivateHome(onSearch: onSearch);
    return ColoredBox(
      color: c.primary,
      child: ListenableBuilder(
        listenable: library,
        builder: (context, _) {
          final seen = <String>{};
          final shortcuts = [...library.bookmarks, ...library.topSites()].where((e) => seen.add(e.host)).take(8).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
            children: [
              Center(child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.asset('assets/icon.png', width: 72, height: 72))),
              const SizedBox(height: 28),
              _SearchPill(onTap: onSearch, hint: 'Search with ${settings.engine.name}', engineIcon: settings.engine.icon),
              const SizedBox(height: 32),
              if (shortcuts.isNotEmpty)
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                  children: [for (final e in shortcuts) _Shortcut(entry: e, onTap: () => onOpen(e.url))],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.onTap, required this.hint, required this.engineIcon});
  final VoidCallback onTap;
  final String hint, engineIcon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.field,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(26)),
          child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.asset(engineIcon, width: 20, height: 20)),
            const SizedBox(width: 12),
            Text(hint, style: TextStyle(color: c.faint, fontSize: 16)),
          ]),
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.entry, required this.onTap});
  final Entry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final letter = entry.host.isEmpty ? '?' : entry.host[0].toUpperCase();
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.secondary, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
          child: Text(letter, style: TextStyle(color: settings.accent, fontSize: 22, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 6),
        Text(entry.host.split('.').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted)),
      ]),
    );
  }
}

class _PrivateHome extends StatelessWidget {
  const _PrivateHome({required this.onSearch});
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: LinkColors.privateBackground,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 80, 28, 24),
        children: [
          const Icon(Icons.visibility_off_outlined, size: 56, color: Colors.white70),
          const SizedBox(height: 20),
          const Text('Private tab', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          FutureBuilder<bool>(
            future: Native.privateSupported(),
            builder: (context, snapshot) => Text(
              snapshot.data == false
                  ? 'Link won’t save your history here. This phone’s Android System WebView is too old to keep private cookies '
                      'separate, so sites can still see you’re signed in. Update “Android System WebView” in the Play Store to fix this.'
                  : 'Link won’t save your history, cookies or site data from private tabs. They’re all deleted when you close your last private tab.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.45),
            ),
          ),
          const SizedBox(height: 32),
          Material(
            color: const Color(0xFF2A2140),
            borderRadius: BorderRadius.circular(26),
            child: InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: onSearch,
              child: const SizedBox(
                height: 52,
                child: Row(children: [
                  SizedBox(width: 16),
                  Icon(Icons.search, color: Colors.white60),
                  SizedBox(width: 12),
                  Text('Search privately', style: TextStyle(color: Colors.white60, fontSize: 16)),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
