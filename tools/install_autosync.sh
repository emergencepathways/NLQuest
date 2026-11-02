#!/usr/bin/env bash
# Speurtocht.NL - run the Anki sync automatically in the background (Linux).
#
#   bash install_autosync.sh            install / update and start
#   bash install_autosync.sh --remove   stop and remove
#
# Copies the sync script to ~/.local/share/speurtocht-nl/ and registers a
# systemd user service, so it starts with your desktop session. Run it again
# after updating the addon to pick up a newer sync script.
set -euo pipefail

DEST="$HOME/.local/share/speurtocht-nl"
UNIT_DIR="$HOME/.config/systemd/user"
UNIT="$UNIT_DIR/speurtocht-anki.service"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "--remove" ]]; then
    systemctl --user disable --now speurtocht-anki.service 2>/dev/null || true
    rm -f "$UNIT"
    systemctl --user daemon-reload
    echo "Speurtocht.NL Anki sync removed. (Your synced-word list in $DEST is kept.)"
    exit 0
fi

command -v python3 >/dev/null || { echo "python3 is needed but not installed."; exit 1; }

mkdir -p "$DEST" "$UNIT_DIR"
cp "$HERE/anki_sync.py" "$HERE/savedvars.py" "$DEST/"

cat > "$UNIT" <<EOF
[Unit]
Description=Speurtocht.NL: send World of Warcraft vocabulary to Anki

[Service]
ExecStart=$(command -v python3) -u "$DEST/anki_sync.py" --watch
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now speurtocht-anki.service
echo
echo "Speurtocht.NL Anki sync is running and will start automatically from now on."
echo "  Status / log:  systemctl --user status speurtocht-anki"
echo "                 journalctl --user -u speurtocht-anki -f"
echo "  Remove:        bash \"$HERE/install_autosync.sh\" --remove"
echo
echo "Remember: Anki must be open with the AnkiConnect add-on (code 2055492159)."
