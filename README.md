# Link for Android and iOS

The Link browser on phones. Android first; the same Flutter code builds for iOS later.

- **1.0.0**: the browser.
- **1.1.0**: adds the Tor VPN.

Both come from the same code (`lib/version.dart`):

```
flutter build apk --release --split-per-abi --build-name 1.0.0 --build-number 1 --dart-define=LINK_VERSION=1.0.0 --dart-define=LINK_VPN=false
flutter build apk --release --split-per-abi --build-name 1.1.0 --build-number 2 --dart-define=LINK_VERSION=1.1.0 --dart-define=LINK_VPN=true
```

## Features

- Tabs and private tabs. Private tabs have their own cookies and storage, deleted when the last one closes.
- Link Search (the same as desktop Link) or 12 other search engines, with search suggestions.
- Ad and tracker blocking from EasyList and EasyPrivacy, refreshed weekly.
- Always HTTPS, with a fallback to HTTP for sites that don't support it.
- Bookmarks, history, downloads, find in page, desktop site, share.
- Tor VPN: Tor runs inside the app (tor-android from the Guardian Project). Pages, website lookups and Link's own
  requests all go through it; nothing loads while it connects. Downloads go through Android and ask first.
- Light, dark and system themes, and the desktop accent colors.
- Can be set as the phone's browser, and opens links and searches from other apps.

## Building

The tools are in `C:\dev` (Flutter and the Android SDK don't support paths with spaces):

```
C:\dev\flutter\bin\flutter.bat build apk --release
C:\dev\flutter\bin\flutter.bat test
```

Flutter uses JDK 21 (`flutter config --jdk-dir`); Android's build tools don't support Java 25 yet.

Release builds are signed with a private key kept outside this repo. `android/key.properties` points to it and is not in git;
without that file, release builds use the debug key.
`flutter build apk --release --split-per-abi` makes one APK per processor; `dist/` has them named for the website.

The app compiles against API 37 because tor-android needs it (`android.suppressUnsupportedCompileSdk=37`), and
`android/app/proguard-rules.pro` keeps the Tor classes, which Tor's native code finds by name.

## Code

- `lib/main.dart`, `lib/app.dart`: startup and app-wide state.
- `lib/models/`: settings, tabs, bookmarks and history.
- `lib/services/`: Link Search, search engines, ad blocking, the bridge to Android.
- `lib/ui/`: the screens.
- `android/app/src/main/kotlin/.../MainActivity.kt`: downloads, private-tab storage, links from other apps.
- `android/app/src/main/kotlin/.../TorVpn.kt`: the Tor VPN.
- `third_party/flutter_inappwebview_android`: a patched copy of the WebView plugin's Android code (Apache 2.0).
  Private tabs use a separate WebView profile instead of the original behavior, which deleted every cookie.
  Search for "Link:" to see the changes.

## Licenses and bug reports

Link Mobile is MIT licensed (`LICENSE`). Tor and the libraries bundled with it keep their own licenses: their texts are in
`assets/licenses` and show under Settings > Open source licenses.

Settings > Report a bug opens `link.northwire.app/report/link/android/<version>`.

Releases are on this repo's GitHub Releases page, tagged `v1.0.0` and `v1.1.0`, and linked from link.northwire.app.

## Not done yet

- Choosing the VPN's country, and routing downloads through the VPN.
- iOS: needs a Mac or a cloud build service, and an Apple developer account.
- Cookie-banner blocking, opening links in other apps (mail, maps, app stores), camera and location permissions for sites.
