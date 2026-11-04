// The app-wide state, created once in main().
import 'models/library.dart';
import 'models/settings.dart';
import 'models/tabs.dart';
import 'services/blocker.dart';
import 'services/vpn.dart';

late final Settings settings;
late final Library library;
late final Blocker blocker;
late final Tabs tabs;
late final Vpn vpn;
