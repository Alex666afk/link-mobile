// Runs Link Search once from the command line: dart run tool/try_search.dart "query"
import 'package:link_mobile/services/link_search.dart';

Future<void> main(List<String> args) async {
  final results = await linkSearch(args.isEmpty ? 'minecraft mods' : args.join(' '), 1);
  for (final r in results.take(3)) {
    print('${r.title}\n  ${r.url}\n  ${r.snippet}');
  }
  print('${results.length} results');
}
