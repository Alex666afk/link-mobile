// Things only Android itself can do: downloads, private-tab profiles, and links opened from other apps.
// The other side is android/app/src/main/kotlin/.../MainActivity.kt.
import 'package:flutter/services.dart';

class Native {
  static const _channel = MethodChannel('link/native');
  static final _handlers = <String, void Function(dynamic arguments)>{};

  /// Messages Android sends on its own: "openUrl", "vpnStatus" and "vpnError".
  static void on(String method, void Function(dynamic arguments) handler) {
    _handlers[method] = handler;
    _channel.setMethodCallHandler((call) async => _handlers[call.method]?.call(call.arguments));
  }

  /// Called when another app opens a link in Link while it's running.
  static void onOpenUrl(void Function(String url) handler) => on('openUrl', (url) => handler(url as String));

  /// The link Link was started with, if another app opened it.
  static Future<String?> initialUrl() async => _call<String>('initialUrl');

  /// Whether private tabs can have their own cookies and storage (needs a recent Android System WebView).
  static Future<bool> privateSupported() async => await _call<bool>('privateSupported') ?? false;

  /// Deletes everything private tabs stored. Only works once no private tab is open.
  static Future<bool> clearPrivate() async => await _call<bool>('clearPrivate') ?? false;

  static Future<bool> download({
    required String url,
    String? fileName,
    String? mimeType,
    String? contentDisposition,
    String? userAgent,
    bool private = false,
  }) async =>
      await _call<bool>('download', {
        'url': url,
        'fileName': fileName,
        'mimeType': mimeType,
        'contentDisposition': contentDisposition,
        'userAgent': userAgent,
        'private': private,
      }) ??
      false;

  static Future<void> openDownloads() async => _call('openDownloads');

  static Future<Map?> vpn(String action) async => _call<Map>('vpn$action');
  static Future<bool> vpnNewIdentity() async => await _call<bool>('vpnNewIdentity') ?? false;

  static Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null; // not available on this platform yet
    } on PlatformException {
      return null;
    }
  }
}
