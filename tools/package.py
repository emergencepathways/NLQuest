#!/usr/bin/env python3
"""Build the zip players download: dist/SpeurtochtNL.zip.

The zip holds one folder, SpeurtochtNL/, so it unzips straight into
Interface/AddOns/ with the name the game needs (the green "Code > Download ZIP"
button on GitHub gives a folder called NLQuest-main, which WoW won't load).

Only the addon goes in: the Lua files, the TOC, Data/, the two read-me files,
and the three Anki tools the read-me tells players to run. The translation
pipeline (batches/, source/, the other tools) stays out.

Every file the TOC lists is checked; a missing one stops the build.

Usage:  python3 tools/package.py [--out dist]
"""
import argparse
import os
import sys
import zipfile

ADDON = "SpeurtochtNL"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TOP_FILES = ["README.md", "LEESMIJ.md", "LICENSE", "LICENSE.md"]
ANKI_TOOLS = ["tools/anki_sync.py", "tools/savedvars.py", "tools/install_autosync.sh"]


def toc_files():
    """Files the TOC loads, as repo-relative paths with forward slashes."""
    out = []
    with open(os.path.join(ROOT, ADDON + ".toc"), encoding="utf-8-sig") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                out.append(line.replace("\\", "/"))
    return out


def toc_version():
    with open(os.path.join(ROOT, ADDON + ".toc"), encoding="utf-8-sig") as f:
        for line in f:
            if line.startswith("## Version:"):
                return line.split(":", 1)[1].strip()
    return "unknown"


def collect():
    files = {ADDON + ".toc"}
    files.update(n for n in os.listdir(ROOT) if n.endswith(".lua"))
    for dirpath, _dirs, names in os.walk(os.path.join(ROOT, "Data")):
        for n in names:
            files.add(os.path.relpath(os.path.join(dirpath, n), ROOT).replace(os.sep, "/"))
    files.update(p for p in TOP_FILES + ANKI_TOOLS if os.path.isfile(os.path.join(ROOT, p)))

    missing = [p for p in toc_files() if p not in files]
    if missing:
        sys.exit("The TOC lists files that don't exist:\n  " + "\n  ".join(missing))
    return sorted(files)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", default=os.path.join(ROOT, "dist"))
    args = ap.parse_args()

    files = collect()
    os.makedirs(args.out, exist_ok=True)
    zpath = os.path.join(args.out, ADDON + ".zip")
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for rel in files:
            info = zipfile.ZipInfo(ADDON + "/" + rel, date_time=(2020, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            mode = 0o755 if rel.endswith(".sh") else 0o644
            info.external_attr = (0o100000 | mode) << 16
            with open(os.path.join(ROOT, rel), "rb") as f:
                z.writestr(info, f.read())

    print(f"{zpath}: {len(files)} files, version {toc_version()}, "
          f"{os.path.getsize(zpath) / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
