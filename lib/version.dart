// Which Link Mobile release this build is. Set when building, for example:
//   flutter build apk --build-name 1.0.0 --dart-define=LINK_VERSION=1.0.0 --dart-define=LINK_VPN=false
// 1.0.0 is the browser without the VPN; 1.1.0 added the Tor VPN.
const appVersion = String.fromEnvironment('LINK_VERSION', defaultValue: '1.1.0');
const vpnAvailable = bool.fromEnvironment('LINK_VPN', defaultValue: true);
