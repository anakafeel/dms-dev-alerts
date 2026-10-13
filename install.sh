#!/usr/bin/env bash
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
PLUGIN_DIR="$HOME/.config/DankMaterialShell/plugins/devAlerts"
ORGS_DST="$HOME/.config/gfi-watch/orgs.txt"
UNIT_DIR="$HOME/.config/systemd/user"

check_deps() {
    local missing=0 cmd
    for cmd in gh python3 notify-send; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "missing dependency: $cmd" >&2
            missing=1
        fi
    done
    [ "$missing" -eq 0 ] || exit 1
}

install_bins() {
    mkdir -p "$BIN_DIR"
    install -m 755 "$SRC"/bin/* "$BIN_DIR"/
}

install_plugin() {
    if [ ! -d "$SRC/plugin" ]; then
        echo "plugin/ not found, skipping plugin install" >&2
        return 0
    fi
    mkdir -p "$PLUGIN_DIR"
    cp -r "$SRC"/plugin/. "$PLUGIN_DIR"/
}

install_config() {
    mkdir -p "$(dirname "$ORGS_DST")"
    if [ ! -e "$ORGS_DST" ]; then
        cp "$SRC/config/orgs.txt" "$ORGS_DST"
    fi
}

install_units() {
    mkdir -p "$UNIT_DIR"
    cp "$SRC"/systemd/* "$UNIT_DIR"/
    systemctl --user daemon-reload
    systemctl --user enable --now gfi-watch.timer devalert.timer
}

main() {
    bash -n "$0"
    if command -v shellcheck >/dev/null 2>&1; then
        shellcheck "$0"
    fi
    check_deps
    install_bins
    install_plugin
    install_config
    install_units
    cat <<MSG

Installed. Next steps:
  1. Open DMS Settings -> Plugins and enable "Dev Alerts".
  2. Add "devAlerts" to the bar in DMS Settings.
MSG
}

main "$@"
