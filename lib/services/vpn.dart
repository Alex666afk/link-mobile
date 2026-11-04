// Link's VPN: Tor, running inside the app (android/.../TorVpn.kt does the work).
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'native.dart';

enum VpnState { off, starting, on }

class Vpn extends ChangeNotifier {
  Vpn() {
    Native.on('vpnStatus', (status) => _update(status as Map));
    Native.on('vpnError', (error) {
      this.error = (error as Map)['message'] as String?;
      notifyListeners();
    });
  }

  VpnState state = VpnState.off;
  int progress = 0;
  String? error;

  /// Called once Tor is connected, to reload pages that failed while it was connecting.
  VoidCallback? onConnected;

  bool get on => state == VpnState.on;
  bool get active => state != VpnState.off;

  Future<void> start() async {
    error = null;
    final status = await Native.vpn('Start');
    if (status != null) _update(status);
  }

  Future<void> stop() async {
    final status = await Native.vpn('Stop');
    if (status != null) _update(status);
  }

  Future<bool> newIdentity() => Native.vpnNewIdentity();

  void _update(Map status) {
    final was = state;
    state = VpnState.values.byName(status['state'] as String);
    progress = status['progress'] as int? ?? 0;
    final port = status['httpPort'] as int? ?? 0;
    // Link's own requests (Link Search, suggestions, block lists) go through Tor's HTTP proxy too.
    // While Tor connects they go to a port that never answers, so nothing leaves without Tor.
    HttpOverrides.global = switch (state) {
      VpnState.on => _TorProxy(port > 0 ? port : 1),
      VpnState.starting => _TorProxy(1),
      VpnState.off => null,
    };
    notifyListeners();
    if (was != VpnState.on && state == VpnState.on) onConnected?.call();
  }
}

class _TorProxy extends HttpOverrides {
  _TorProxy(this.port);
  final int port;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)..findProxy = (_) => 'PROXY 127.0.0.1:$port';
}
