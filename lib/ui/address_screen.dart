import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app.dart';
import '../models/library.dart';
import '../theme.dart';

/// Typing an address or a search, with suggestions from bookmarks, history and the search engine.
/// Returns what was entered.
class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key, this.initial, required this.private});
  final String? initial;
  final bool private;

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  late final _text = TextEditingController(text: widget.initial ?? '')
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.initial?.length ?? 0);
  List<Entry> _local = [];
  List<String> _remote = [];
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _changed(String value) {
    setState(() => _local = library.suggest(value));
    _debounce?.cancel();
    // Private tabs never send what's typed to the search engine.
    if (widget.private || !settings.suggestions || settings.engine.suggest.isEmpty || value.trim().isEmpty) {
      setState(() => _remote = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 180), () => _fetch(value));
  }

  Future<void> _fetch(String value) async {
    try {
      final res = await http
          .get(Uri.parse(settings.engine.suggest.replaceAll('%s', Uri.encodeQueryComponent(value))))
          .timeout(const Duration(seconds: 3));
      final data = jsonDecode(res.body);
      final list = data is List && data.length > 1 && data[1] is List ? (data[1] as List).cast<String>() : <String>[];
      if (mounted && _text.text == value) setState(() => _remote = list.take(5).toList());
    } catch (_) {}
  }

  void _submit(String value) => Navigator.pop(context, value);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final private = widget.private;
    final bg = private ? LinkColors.privateBackground : c.primary;
    final fg = private ? Colors.white : c.text;
    final query = _text.text.trim();
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
            child: Row(children: [
              IconButton(icon: Icon(Icons.arrow_back, color: fg), onPressed: () => Navigator.pop(context)),
              Expanded(
                child: TextField(
                  controller: _text,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  autocorrect: false,
                  style: TextStyle(color: fg, fontSize: 16),
                  cursorColor: settings.accent,
                  decoration: InputDecoration(
                    hintText: private ? 'Search privately' : 'Search or type address',
                    hintStyle: TextStyle(color: private ? Colors.white54 : c.faint),
                    filled: true,
                    fillColor: private ? const Color(0xFF2A2140) : c.field,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(Icons.close, color: private ? Colors.white60 : c.faint),
                            onPressed: () {
                              _text.clear();
                              _changed('');
                            }),
                  ),
                  onChanged: _changed,
                  onSubmitted: _submit,
                ),
              ),
            ]),
          ),
          Expanded(
            child: ListView(children: [
              if (query.isNotEmpty)
                _row(Image.asset(settings.engine.icon, width: 20, height: 20), query, 'Search with ${settings.engine.name}', () => _submit(query), fg, c),
              for (final s in _remote) _row(Icon(Icons.search, size: 20, color: c.faint), s, null, () => _submit(s), fg, c),
              for (final e in _local)
                _row(Icon(library.isBookmarked(e.url) ? Icons.star_border : Icons.history, size: 20, color: c.faint), e.title, e.host,
                    () => _submit(e.url), fg, c),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _row(Widget icon, String title, String? subtitle, VoidCallback onTap, Color fg, LinkColors c) => ListTile(
        leading: SizedBox(width: 24, child: Center(child: icon)),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg)),
        subtitle: subtitle == null ? null : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.faint)),
        onTap: onTap,
      );
}
