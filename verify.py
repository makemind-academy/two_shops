#!/usr/bin/env python3
"""two-shops: one bundle, two shops; the shop's name never appears in the app, only in its config."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "tools"))
from appplayer import AppPlayer  # noqa: E402
from mcpclient import Server  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
SERVER = os.path.join(HERE, "shop_server")
CAP = os.path.join(HERE, "captures")

import hashlib
text = open(os.path.join(HERE, "shop.mbd", "ui", "pages", "counter.json")).read()
assert "Riverside" not in text and "Hilltop" not in text, "the app must not know a shop's name"
digest = hashlib.sha256(text.encode()).hexdigest()
with Server(["dart", "run", "bin/server.dart", "--config=../configs/riverside.json"], cwd=SERVER) as s:
    assert s.call("counter.add", {"sku": "AM"})["basketCount"] == 1
    refused = s.call("counter.add", {"sku": "XX"})
    assert refused["basketCount"] == 1, "an item outside the menu must be refused"

ap = AppPlayer()
for shop in ("riverside", "hilltop"):
    ap.register_server(f"com.makemind.sample.shop.{shop}", f"Counter ({shop})", cwd=SERVER,
                       args=["run", "bin/server.dart", f"--config=../configs/{shop}.json"])
ap.restart()
ap.open_server("com.makemind.sample.shop.riverside")
ap.wait_text("BASKET")
ap.expect_text("RIVERSIDE")
ap.expect_aligned("$", min_rows=3)
ap.tap("Add")                      # Americano
ap.tap("Add", idx=1)               # Latte
ap.wait_text("Charge $8.10")       # 3.80 + 4.30, tax inside the prices
ap.expect_text("$0.74")            # 8.10 × 10 / 110, not 8.10 × 0.1
ap.shot(f"{CAP}/01_riverside.png")
ap.restart()
ap.open_server("com.makemind.sample.shop.hilltop")
ap.wait_text("BASKET")
ap.expect_text("HILLTOP")
ap.tap("Add")                      # Americano
ap.tap("Add", idx=1)               # Latte
ap.wait_text("Charge $10.45")      # 4.50 + 5.00, plus 10% at the counter
ap.expect_text("$0.95")
ap.shot(f"{CAP}/02_hilltop.png")
print(f"two-shops: one screen (sha256 {digest[:12]}) served to two shops from two configs")
