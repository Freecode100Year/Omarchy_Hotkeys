#!/bin/bash
# Omarchy_Hotkeys installer · 安装
#
#   curl -fsSL https://raw.githubusercontent.com/Freecode100Year/Omarchy_Hotkeys/main/install.sh | bash
#   curl -fsSL https://gitlab.com/sj9292008133/Omarchy_Hotkeys/-/raw/main/install.sh | bash
#
# Installs to ~/.local/share/omarchy-hotkeys-app, links ~/.local/bin/omarchy-hotkeys and adds
# two apps to the launcher: "Hotkey manual" and "Custom hotkeys". No sudo; no Omarchy or
# ~/.config/hypr file is edited. Remove with: omarchy-hotkeys uninstall
set -euo pipefail

REPO="https://github.com/Freecode100Year/Omarchy_Hotkeys.git"
REPO_GITLAB="https://gitlab.com/sj9292008133/Omarchy_Hotkeys.git"
APP_DIR="$HOME/.local/share/omarchy-hotkeys-app"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
command -v omarchy-menu-keybindings >/dev/null || fail "this is not Omarchy (omarchy-menu-keybindings missing) · 这台电脑不是 Omarchy"
for c in git jq; do command -v "$c" >/dev/null || fail "$c is required"; done

src="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [[ -n $src && -f $src/bin/omarchy-hotkeys && $src != "$APP_DIR" ]]; then
  mkdir -p "$APP_DIR"
  cp -a "$src/." "$APP_DIR/"
elif [[ -d $APP_DIR/.git ]]; then
  git -C "$APP_DIR" pull -q --ff-only
else
  rm -rf "$APP_DIR"
  git clone -q --depth 1 "$REPO" "$APP_DIR" 2>/dev/null || git clone -q --depth 1 "$REPO_GITLAB" "$APP_DIR"
fi
chmod +x "$APP_DIR/bin/omarchy-hotkeys"
mkdir -p "$HOME/.local/bin" "$APPS"
ln -sfn "$APP_DIR/bin/omarchy-hotkeys" "$HOME/.local/bin/omarchy-hotkeys"
for f in "$APP_DIR"/applications/*.desktop; do
  sed "s#@BIN@#$APP_DIR/bin/omarchy-hotkeys#g" "$f" >"$APPS/$(basename "$f")"
done
command -v update-desktop-database >/dev/null && update-desktop-database -q "$APPS" 2>/dev/null || true

# Re-apply hotkeys you set before (kept across reinstalls), then build the manual once.
"$APP_DIR/bin/omarchy-hotkeys" apply
"$APP_DIR/bin/omarchy-hotkeys" manual --no-open >/dev/null

T() { jq -r --arg k "$1" '.[$k]' "$APP_DIR/i18n/$( (omarchy-language 2>/dev/null || echo en) | sed 's/^zh$/zh-CN/')".json 2>/dev/null || jq -r --arg k "$1" '.[$k]' "$APP_DIR/i18n/en.json"; }
command -v omarchy-notification-send >/dev/null &&
  omarchy-notification-send -g 󰌌 "$(T installed)" "$(T installedBody)" >/dev/null 2>&1 || true
printf '\n  %s\n  %s\n\n  omarchy-hotkeys manual   ·   omarchy-hotkeys menu   ·   omarchy-hotkeys help\n' "$(T installed)" "$(T installedBody)"
