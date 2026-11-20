#!/bin/bash
# Installs Omarchy_Hotkeys into a throwaway HOME against stand-ins for the Omarchy
# and Hyprland commands it uses, then checks adding / replacing / turning off /
# removing hotkeys, the generated Lua, and the manual in three languages.
#   OMARCHY_SRC=/path/to/omarchy bash tests/cli_test.sh   (manual chapters come from there)
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${OMARCHY_SRC:-/root/work/ref/omarchy}"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" XDG_STATE_HOME="$T/home/.local/state" XDG_DATA_HOME="$T/home/.local/share" OMARCHY_PATH="$T/omarchy"
mkdir -p "$HOME" "$T/bin" "$OMARCHY_PATH/manual"
for l in zh-CN ja; do [[ -d $SRC/manual/$l ]] && mkdir -p "$OMARCHY_PATH/manual/$l" && cp "$SRC/manual/$l"/*hotkeys*.md "$OMARCHY_PATH/manual/$l/"; done
cp "$SRC/manual"/*hotkeys*.md "$OMARCHY_PATH/manual/"
fails=0
S="$T/st"
mkdir -p "$S"
echo zh-CN >"$S/lang"

stub() { printf '#!/bin/bash\n%s\n' "$2" >"$T/bin/$1"; chmod +x "$T/bin/$1"; }
stub omarchy-language "case \${1:-} in locale) echo C ;; *) cat $S/lang ;; esac"
stub omarchy-menu-keybindings 'printf "%s\n" "SUPER + SPACE        → Omarchy 菜单" "SUPER + SHIFT + B    → 浏览器" "SUPER + CTRL + A     → 音频" "SUPER + CTRL + ALT + T → 显示时间" "SUPER + W            → 关闭窗口"'
stub hyprctl 'case $1 in binds) echo "[{\"modmask\":65,\"key\":\"B\",\"description\":\"浏览器\",\"dispatcher\":\"exec\",\"arg\":\"\"},{\"modmask\":64,\"key\":\"W\",\"description\":\"关闭窗口\",\"dispatcher\":\"killactive\",\"arg\":\"\"}]" ;; esac'
stub omarchy-restart-hyprctl "echo reload >>$S/reloads"
stub omarchy-notification-send "true"
stub omarchy-launch-browser "echo \"\$1\" >$S/opened"
export PATH="$T/bin:$PATH"

ok() { echo "  ok   $1"; }
bad() { echo "  FAIL $1"; fails=$((fails + 1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }
H="$HOME/.local/bin/omarchy-hotkeys"
LUA="$XDG_STATE_HOME/omarchy/toggles/hypr/zz-omarchy-hotkeys.lua"
CONF="$HOME/.config/omarchy-hotkeys/hotkeys.conf"
lua_ok() { ! command -v luac5.4 >/dev/null || luac5.4 -p "$LUA"; }

echo "install"
bash "$ROOT/install.sh" >"$T/install.log" 2>&1 || { bad "install failed"; cat "$T/install.log"; }
check "command linked" "[[ -x $H ]]"
check "two launcher apps, pointing at the program" "grep -q '^Exec=$HOME/.local/share/omarchy-hotkeys-app/bin/omarchy-hotkeys manual' $XDG_DATA_HOME/applications/omarchy-hotkeys-manual.desktop && grep -q 'Name\[zh_CN\]=自定义快捷键' $XDG_DATA_HOME/applications/omarchy-hotkeys-custom.desktop"
check "Hyprland file written and reloaded" "[[ -f $LUA ]] && grep -q reload $S/reloads"
check "install message in Chinese" "grep -q '快捷键工具已安装' $T/install.log"

echo "add / replace"
$H add "super+alt + t" "打开终端" "ghostty" >"$T/o" 2>&1
check "chord normalised, line saved" "grep -q '^SUPER + ALT + T | 打开终端 | ghostty$' $CONF"
check "Lua rebind written" "grep -q 'o.rebind(\"SUPER + ALT + T\", \"打开终端\", \"ghostty\")' $LUA && lua_ok"
check "message in Chinese" "grep -q '已设定快捷键 SUPER + ALT + T' $T/o"
$H add "SUPER + SHIFT + B" "火狐" "firefox" >"$T/o" 2>&1; rc=$?; export rc # read inside the check string
check "conflict refused without --force" "(( rc != 0 )) && grep -q '已经用于「浏览器」' $T/o && ! grep -q firefox $CONF"
$H add "SUPER + SHIFT + B" "火狐" "firefox" --force >"$T/o" 2>&1
check "--force replaces, says what it replaced" "grep -q 'SUPER + SHIFT + B | 火狐 | firefox' $CONF && grep -q '替换了「浏览器」' $T/o"
$H add "SUPER + ALT + T" "终端二" "foot" >/dev/null 2>&1
check "re-adding the same chord updates it, no duplicate" "(( \$(grep -c '^SUPER + ALT + T' $CONF) == 1 )) && grep -q '终端二 | foot' $CONF"
$H add "SUPER + ALT + Q" 'say "hi" \ back' 'notify-send "a\\b"' >/dev/null 2>&1
check "quotes and backslashes stay valid Lua" "lua_ok && grep -q 'SUPER + ALT + Q' $LUA"

echo "bad input"
$H add "SUPER + ALT" "x" "y" >/dev/null 2>&1; check "chord without a key refused" "! grep -q '^SUPER + ALT |' $CONF"
$H add 'SUPER + $(rm)' "x" "y" >/dev/null 2>&1; check "shell characters in chord refused" "! grep -qF '\$(rm' $CONF"
$H add "SUPER + ALT + Y" "a|b" "y" >/dev/null 2>&1; check "| in description refused" "! grep -q 'ALT + Y' $CONF"
$H add "SUPER + ALT + Y" "x" "" >/dev/null 2>&1; check "empty command refused" "! grep -q 'ALT + Y' $CONF"

echo "disable / remove"
$H disable "SUPER + W" >"$T/o" 2>&1
check "turn off a default" "grep -q '^SUPER + W | disable$' $CONF && grep -q 'hl.unbind(\"SUPER + W\")' $LUA && lua_ok"
$H remove "SUPER + W" >"$T/o" 2>&1
check "removing a turn-off restores the default" "! grep -q 'SUPER + W' $CONF && ! grep -q 'SUPER + W' $LUA && grep -q '已恢复为 Omarchy 默认' $T/o"
$H remove "SUPER + ALT + Q" >/dev/null
check "remove a custom hotkey" "! grep -q 'ALT + Q' $CONF $LUA"
$H remove "SUPER + ALT + Z" >"$T/o" 2>&1; check "removing an unknown chord says so" "grep -q '没有 SUPER + ALT + Z' $T/o"
check "list" "$H list | grep -q 'SUPER + ALT + T .*终端二  →  foot'"

echo "manual"
$H disable "SUPER + W" >/dev/null 2>&1
$H manual >/dev/null
sleep 0.5
M="$XDG_DATA_HOME/omarchy-hotkeys/manual-zh-CN.html"
check "zh-CN manual written and opened" "[[ -f $M ]] && grep -q 'manual-zh-CN.html' $S/opened"
check "Chinese title and placeholders all filled" "grep -q '<title>Omarchy 快捷键说明书</title>' $M && ! grep -qE '@[A-Z_]+@' $M"
data() { sed -n 's#.*<script type=\"application/json\" id=\"data\">\(.*\)</script>.*#\1#p' "$1" | sed 's#<\\/#</#g'; }
check "data block is valid JSON with 5 live hotkeys" "[[ \$(data $M | jq '.all | length') == 5 ]]"
check "custom hotkeys in the manual, turned-off one marked" "data $M | jq -e '[.custom[] | select(.keys == \"SUPER + W\" and .off)] | length == 1' >/dev/null"
check "Chinese descriptions kept whole" "data $M | jq -e '[.all[] | select(.keys == \"SUPER + SPACE\" and .action == \"Omarchy 菜单\")] | length == 1' >/dev/null"
check "official chapter in Chinese" "data $M | jq -r .official | grep -q '快捷键的布局方式'"
if command -v node >/dev/null || [[ -x /opt/node22/bin/node ]]; then
  N="$(command -v node || echo /opt/node22/bin/node)"
  sed -n '/^<script>$/,/^<\/script>$/p' "$M" | sed '1d;$d' >"$T/page.js"
  check "page script parses" "$N --check $T/page.js"
fi
echo en >"$S/lang"; $H manual --no-open >/dev/null
check "English manual" "grep -q '<title>Omarchy Hotkeys</title>' $XDG_DATA_HOME/omarchy-hotkeys/manual-en.html"
echo ja >"$S/lang"; $H manual --no-open >/dev/null
J="$XDG_DATA_HOME/omarchy-hotkeys/manual-ja.html"
check "Japanese: our words fall back to English, Omarchy's chapter is Japanese" "grep -q '<title>Omarchy Hotkeys</title>' $J && data $J | jq -r .official | grep -q 'ショートカット\|キー'"
echo zh-TW >"$S/lang"; $H list >/dev/null; $H remove "SUPER + ALT + Z" >"$T/o" 2>&1
check "Traditional Chinese messages" "grep -q '你的自訂快捷鍵裡沒有' $T/o"

echo "uninstall"
echo zh-CN >"$S/lang"
$H uninstall >/dev/null
check "program, link, apps, Hyprland file removed" "[[ ! -e $HOME/.local/share/omarchy-hotkeys-app && ! -e $H && ! -e $LUA && ! -e $XDG_DATA_HOME/applications/omarchy-hotkeys-manual.desktop ]]"
check "your hotkeys file kept for a reinstall" "grep -q 'SUPER + ALT + T' $CONF"
bash "$ROOT/install.sh" >/dev/null 2>&1
check "reinstall brings your hotkeys back" "grep -q 'SUPER + ALT + T' $LUA"

echo
if ((fails)); then echo "$fails 项失败 failed"; exit 1; fi
echo "全部通过 all passed"
