# two-shops

One bundle, two shops; the shop's name never appears in the app, only in its config.

Article: [one-app-two-shops](https://makemind.dev/en/field/one-app-two-shops)

## What is here

- `shop_server/` — Dart MCP server (`mcp_server` from pub.dev). It holds the data and the tools and serves the app's pages as `ui://` resources.
- `shop.mbd/` — the app as a folder of JSON: `manifest.json` and the pages under `ui/`. No build step.
- `configs/` — one file per shop; the bundle never names one.
- `captures/` — screenshots taken from AppPlayer by `verify.py`.
- `verify.py`, `verify.sh` — the check.

## Open it in AppPlayer

Add a server app with command `dart`, arguments `run bin/server.dart`, working directory `shop_server/`. The server serves its pages; the player draws them.

## Verify

```bash
bash verify.sh
```

Needs AppPlayer with the debug MCP on (see `tools/README.md`). The script builds what needs building, drives the player through the screens above, asserts the claim at the top of this file, and writes `captures/`.
