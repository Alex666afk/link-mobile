import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'models/library.dart';
import 'models/settings.dart';
import 'models/tabs.dart';
import 'services/blocker.dart';
import 'services/vpn.dart';
import 'theme.dart';
import 'ui/browser_page.dart';
import 'version.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerLicenses();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  settings = Settings(await SharedPreferences.getInstance());
  library = Library();
  blocker = Blocker();
  tabs = Tabs(settings)..restore();
  vpn = Vpn();
  if (vpnAvailable && settings.vpn) vpn.start(); // before any page loads, so nothing goes out without Tor
  await library.load();
  await blocker.load();
  runApp(const LinkApp());
}

// Tor and the libraries bundled with it. Their licenses require these notices to ship with the app.
// Flutter adds the licenses of everything in pubspec.yaml by itself.
void _registerLicenses() {
  const bundled = {
    'Tor': 'tor',
    'tor-android': 'tor-android',
    'jtorctl': 'jtorctl',
    'libevent': 'libevent',
    'OpenSSL': 'openssl',
    'zstd': 'zstd',
    'zlib': 'zlib',
  };
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: name, value: file) in bundled.entries) {
      yield LicenseEntryWithLineBreaks([name], await rootBundle.loadString('assets/licenses/$file.txt'));
    }
  });
}

class LinkApp extends StatelessWidget {
  const LinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'Link',
        debugShowCheckedModeBanner: false,
        themeMode: settings.themeMode,
        theme: buildTheme(Brightness.light, settings.accent),
        darkTheme: buildTheme(Brightness.dark, settings.accent),
        home: const BrowserPage(),
      ),
    );
  }
}
