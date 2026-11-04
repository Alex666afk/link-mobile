import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/engines.dart';
import '../theme.dart';

/// Link's settings, saved on the phone. Defaults match desktop Link.
class Settings extends ChangeNotifier {
  Settings(this._prefs);
  final SharedPreferences _prefs;

  ThemeMode get themeMode => ThemeMode.values.byName(_prefs.getString('theme') ?? 'dark');
  set themeMode(ThemeMode v) => _set('theme', v.name);

  Color get accent => Color(_prefs.getInt('accent') ?? accents.first.toARGB32());
  set accent(Color v) => _set('accent', v.toARGB32());

  SearchEngine get engine => engineById(_prefs.getString('engine') ?? 'link');
  set engine(SearchEngine v) => _set('engine', v.id);

  bool get suggestions => _prefs.getBool('suggestions') ?? true;
  set suggestions(bool v) => _set('suggestions', v);

  bool get blockAds => _prefs.getBool('blockAds') ?? true;
  set blockAds(bool v) => _set('blockAds', v);

  bool get httpsOnly => _prefs.getBool('httpsOnly') ?? true;
  set httpsOnly(bool v) => _set('httpsOnly', v);

  bool get vpn => _prefs.getBool('vpn') ?? false;
  set vpn(bool v) => _set('vpn', v);

  bool get restoreTabs => _prefs.getBool('restoreTabs') ?? true;
  set restoreTabs(bool v) => _set('restoreTabs', v);

  List<String> get savedTabs => _prefs.getStringList('tabs') ?? const [];
  set savedTabs(List<String> v) => _prefs.setStringList('tabs', v);

  void _set(String key, Object value) {
    switch (value) {
      case final String s: _prefs.setString(key, s);
      case final int i: _prefs.setInt(key, i);
      case final bool b: _prefs.setBool(key, b);
    }
    notifyListeners();
  }
}
