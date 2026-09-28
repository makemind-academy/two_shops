import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mcp_server/mcp_server.dart';

import 'serve_bundle.dart';

/// shop_server — the counter of a shop. Which shop, it is told at startup.
///
/// Two cafes under one owner. Different prices, different hours, one of them
/// quotes tax-inclusive and the other does not, and the menus overlap but are
/// not the same.
///
/// The tempting shape is a `shopName` switch somewhere. Then the second shop
/// is a code change, the third shop is a code change, and eventually the file
/// has a branch for a shop that closed two years ago.
///
/// So nothing here knows any shop's name. The config file is an argument.
void main(List<String> args) async {
  final path = args
      .firstWhere((a) => a.startsWith('--config='),
          orElse: () => throw ArgumentError('pass --config=<file>'))
      .substring('--config='.length);

  final config =
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  final server = McpServer.createServer(McpServerConfig(
    name: 'Counter (${config['shopName']})',
    version: '1.0.0',
    capabilities:
        const ServerCapabilities(
      tools: ToolsCapability(listChanged: true),
      resources: ResourcesCapability(listChanged: true),
    ),
  ));
  ShopServer(server, config).register();
  // The screen next door: AppPlayer reads it from here and sends the pages'
  // tool calls back to the tools above.
  registerBundleUi(server, '../shop.mbd');
  final transport = McpServer.createStdioTransport().get();
  server.connect(transport);
  await Completer<void>().future;
}

/// "1 slot", "2 slots". A screen that says "1 slot(s)" is a screen nobody
/// proofread.
String _plural(int n, String one) => "$n $one" + (n == 1 ? "" : "s");

class ShopServer {
  ShopServer(this.server, this.config);

  /// Prices are cents; the config's `currency` is the symbol printed before them.
  String _money(int cents) =>
      '${config['currency']}${(cents / 100).toStringAsFixed(2)}';

  final Server server;
  final Map<String, dynamic> config;

  final _basket = <Map<String, dynamic>>[];

  List<Map<String, dynamic>> get _menu =>
      (config['menu'] as List).cast<Map<String, dynamic>>();

  void register() {
    server.addTool(
      name: 'counter.state',
      description: 'The menu and the basket for this shop',
      inputSchema: const {'type': 'object', 'properties': {}},
      handler: (args) async => _state(),
    );

    server.addTool(
      name: 'counter.add',
      description: 'Put one item in the basket',
      inputSchema: const {
        'type': 'object',
        'properties': {
          'sku': {'type': 'string'},
        },
        'required': ['sku'],
      },
      handler: (args) async {
        final sku = args['sku'] as String;
        final item = _menu.where((m) => m['sku'] == sku).toList();
        // A sku that is on one shop's menu and not the other's must be
        // refused here, not hidden by the screen. The screen is the same file
        // in both shops and cannot know.
        if (item.isEmpty) {
          return _state(notice: '$sku is not on this menu');
        }
        _basket.add(item.first);
        return _state(notice: 'added ${item.first['name']}');
      },
    );

    // A counter that can show what is due has to be able to take it. The
    // takings are the shop's, like the menu and the tax rule: the screen is
    // the same file in both shops and holds none of them.
    server.addTool(
      name: 'counter.charge',
      description: 'Settle the basket and start the next one',
      inputSchema: const {'type': 'object', 'properties': {}},
      handler: (args) async {
        if (_basket.isEmpty) return _state(notice: 'nothing to charge');
        final gross = _basket.fold<int>(0, (a, r) => a + (r['price'] as int));
        _takings += gross;
        _tickets += 1;
        final n = _basket.length;
        _basket.clear();
        return _state(notice: 'charged ${_plural(n, "item")}');
      },
    );
  }

  int _takings = 0;
  int _tickets = 0;

  CallToolResult _state({String notice = ''}) {
    final gross = _basket.fold<int>(0, (a, r) => a + (r['price'] as int));
    final pct = config['taxPercent'] as int;
    final included = config['taxIncluded'] as bool;

    // Two shops, two ways of quoting. The arithmetic is one expression that
    // reads the flag — not two code paths that drift apart.
    final tax = included
        ? (gross * pct / (100 + pct)).round()
        : (gross * pct / 100).round();
    final due = included ? gross : gross + tax;

    return CallToolResult(content: [
      TextContent(
        text: jsonEncode({
          'shopName': (config['shopName'] as String).toUpperCase(),
          'accent': config['accent'],
          'openHours': config['openHours'],
          'menuRows': [
            for (final m in _menu)
              {
                'sku': m['sku'],
                'name': m['name'],
                'price': _money(m['price'] as int),
              },
          ],
          'basketCount': _basket.length,
          'basketRows': [
            for (final r in _basket)
              {'name': r['name'], 'price': _money(r['price'] as int)},
          ],
          'takings': _money(_takings),
          'tickets': _tickets,
          'basketLine': _basket.isEmpty
              ? 'empty'
              : _basket.map((r) => r['name']).join(', '),
          'taxNote': included
              ? '$pct% tax included in the prices above'
              : '$pct% tax added at the counter',
          'tax': _money(tax),
          'due': _money(due),
          'notice': notice,
        }),
      )
    ]);
  }
}
