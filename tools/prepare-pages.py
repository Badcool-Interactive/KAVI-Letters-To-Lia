#!/usr/bin/env python3
"""Give the hosted Godot export a versioned pack and a deployment marker."""

import json
from pathlib import Path
import re
import shutil
import sys

export = Path(sys.argv[1])
project = Path(sys.argv[2])
version = re.search(r'^config/version="([0-9]+\.[0-9]+\.[0-9]+)"$', project.read_text(), re.M)
if version is None:
    raise SystemExit("Could not find the KAVI version in project.godot")

html = export / "index.html"
page = html.read_text()
match = re.search(r"const GODOT_CONFIG = (\{[^\n]+\});", page)
if match is None:
    raise SystemExit("Could not find GODOT_CONFIG in the Web export")

config = json.loads(match.group(1))
pack = "index.pck"
versioned_pack = f"index-v{version[1]}.pck"
config["mainPack"] = versioned_pack
config["fileSizes"][versioned_pack] = (export / pack).stat().st_size
shutil.copyfile(export / pack, export / versioned_pack)
html.write_text(page[:match.start(1)] + json.dumps(config, separators=(",", ":")) + page[match.end(1):])
(export / "version.json").write_text(json.dumps({"version": version[1]}) + "\n")
