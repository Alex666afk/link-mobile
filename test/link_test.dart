import 'package:flutter_test/flutter_test.dart';
import 'package:link_mobile/services/blocker.dart';
import 'package:link_mobile/services/engines.dart';

void main() {
  final google = engineById('google');

  test('the address bar tells addresses from searches', () {
    expect(addressFor('example.com', google), 'https://example.com');
    expect(addressFor('http://example.com/a', google), 'http://example.com/a');
    expect(addressFor('localhost:8080', google), 'https://localhost:8080');
    expect(addressFor('192.168.1.1', google), 'https://192.168.1.1');
    expect(addressFor('how tall is everest', google), 'https://www.google.com/search?q=how+tall+is+everest');
    expect(addressFor('flutter', google), 'https://www.google.com/search?q=flutter');
    expect(addressFor('  news.bbc.co.uk/sport  ', google), 'https://news.bbc.co.uk/sport');
  });

  test('only whole-domain block rules are used', () {
    const list = '||ads.example.com^\n||track.example.net^\$third-party\n||x.com^\$script\n/banner/*\n@@||ok.com^\n##.ad';
    expect(domainRules(list).toList(), ['ads.example.com', 'track.example.net']);
  });

  test('the blocking pattern matches listed domains and their subdomains only', () {
    final pattern = RegExp(domainPattern(['doubleclick.net', 'doubleverify.com', 'ads.example.com', 'ads.example.com.br']));
    for (final blocked in [
      'https://doubleclick.net/x',
      'https://stats.g.doubleclick.net/collect?v=1',
      'http://doubleverify.com',
      'https://ads.example.com:443/a.js',
      'https://ads.example.com.br/',
      'https://a.ads.example.com?x',
    ]) {
      expect(pattern.hasMatch(blocked), isTrue, reason: blocked);
    }
    for (final allowed in [
      'https://example.com/',
      'https://notdoubleclick.net/',
      'https://doubleclick.network/',
      'https://news.com/doubleclick.net',
      'https://example.com/?ref=ads.example.com',
      'https://ads.example.co/',
    ]) {
      expect(pattern.hasMatch(allowed), isFalse, reason: allowed);
    }
  });
}
