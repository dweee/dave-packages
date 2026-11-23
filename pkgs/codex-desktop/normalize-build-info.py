"""Keep package provenance without retaining the build input's Nix hash."""
import json
from pathlib import Path
import re
import sys

app = Path(sys.argv[1])
installer_name = sys.argv[2]
clean_name = re.sub(r"^[0-9a-z]{32}-", "", installer_name)
if clean_name == installer_name or not clean_name.endswith(".deb"):
    raise ValueError(f"Unexpected Nix installer filename {installer_name!r}")
for relative in (".codex-linux/build-info.json", "resources/codex-linux-build-info.json"):
    path = app / relative
    info = json.loads(path.read_text())
    package = info["upstreamLinuxPackage"]
    if package["fileName"] != installer_name:
        raise ValueError(f"Unexpected upstream package filename in {relative}")
    package["fileName"] = clean_name
    path.write_text(json.dumps(info, indent=2) + "\n")
