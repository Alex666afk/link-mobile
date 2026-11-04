import 'package:flutter/material.dart';

import '../app.dart';
import '../models/tabs.dart';
import '../theme.dart';
import 'web_tab.dart';

class TabsScreen extends StatefulWidget {
  const TabsScreen({super.key, required this.browser});
  final BrowserContext browser;

  @override
  State<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends State<TabsScreen> {
  late bool _private = tabs.current.private;

  void _open(BrowserTab tab) {
    tabs.select(tab);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = _private ? LinkColors.privateBackground : c.primary;
    final fg = _private ? Colors.white : c.text;
    return ListenableBuilder(
      listenable: tabs,
      builder: (context, _) {
        final list = _private ? tabs.private : tabs.normal;
        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            foregroundColor: fg,
            title: SegmentedButton<bool>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                foregroundColor: _private ? Colors.white70 : c.muted,
                selectedForegroundColor: _private ? Colors.white : c.text,
                selectedBackgroundColor: _private ? const Color(0xFF3A2D5C) : c.secondary,
                side: BorderSide(color: _private ? const Color(0xFF3A2D5C) : c.border),
              ),
              segments: [
                ButtonSegment(value: false, label: Text('Tabs (${tabs.normal.length})')),
                ButtonSegment(value: true, label: Text('Private (${tabs.private.length})')),
              ],
              selected: {_private},
              onSelectionChanged: (s) => setState(() => _private = s.first),
            ),
            actions: [
              if (list.isNotEmpty)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: fg),
                  onSelected: (_) => tabs.closeAll(private: _private),
                  itemBuilder: (_) => [PopupMenuItem(value: 'close', child: Text(_private ? 'Close all private tabs' : 'Close all tabs'))],
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: settings.accent,
            foregroundColor: Colors.white,
            tooltip: _private ? 'New private tab' : 'New tab',
            onPressed: () {
              tabs.open(private: _private);
              Navigator.pop(context);
            },
            child: const Icon(Icons.add),
          ),
          body: list.isEmpty
              ? Center(
                  child: Text(_private ? 'No private tabs' : 'No tabs',
                      style: TextStyle(color: _private ? Colors.white60 : c.faint, fontSize: 16)))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72),
                  itemCount: list.length,
                  itemBuilder: (context, i) => _TabCard(tab: list[i], current: list[i] == tabs.current, onOpen: () => _open(list[i])),
                ),
        );
      },
    );
  }
}

class _TabCard extends StatelessWidget {
  const _TabCard({required this.tab, required this.current, required this.onOpen});
  final BrowserTab tab;
  final bool current;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final private = tab.private;
    final card = private ? const Color(0xFF241C35) : c.secondary;
    final title = tab.home ? 'New tab' : (searchQuery(tab.url) ?? (tab.title.isNotEmpty ? tab.title : tab.url ?? 'Loading…'));
    return Dismissible(
      key: ValueKey(tab.id),
      onDismissed: (_) => tabs.close(tab),
      child: GestureDetector(
        onTap: onOpen,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: current ? settings.accent : (private ? const Color(0xFF3A2D5C) : c.border), width: current ? 2 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 0, 4),
              child: Row(children: [
                Expanded(
                  child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: private ? Colors.white : c.text, fontSize: 13, fontWeight: FontWeight.w500)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close, size: 18, color: private ? Colors.white60 : c.faint),
                  onPressed: () => tabs.close(tab),
                ),
              ]),
            ),
            Expanded(
              child: tab.thumbnail != null && !tab.home
                  ? Image.memory(tab.thumbnail!, fit: BoxFit.cover, alignment: Alignment.topCenter)
                  : ColoredBox(
                      color: private ? LinkColors.privateBackground : c.primary,
                      child: Center(
                        child: tab.home
                            ? Icon(private ? Icons.visibility_off_outlined : Icons.add, color: private ? Colors.white38 : c.faint, size: 32)
                            : Icon(Icons.public, color: c.faint, size: 32),
                      ),
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
