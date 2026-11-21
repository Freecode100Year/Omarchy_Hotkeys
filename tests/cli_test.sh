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
stub hyprctl 'case $1 in eval) echo "$2" >"'"$S"'/eval.lua"; [[ -f "'"$S"'/rec-ok" ]] || { echo "no lua"; exit 1; } ;; dispatch) echo "$2" >>"'"$S"'/dispatch.log" ;; binds) echo "[{\"modmask\":65,\"key\":\"B\",\"description\":\"浏览器\",\"dispatcher\":\"exec\",\"arg\":\"\"},{\"modmask\":64,\"key\":\"W\",\"description\":\"关闭窗口\",\"dispatcher\":\"killactive\",\"arg\":\"\"}]" ;; esac'
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
check "launcher apps use the project icon" "grep -q '^Icon=$HOME/.local/share/omarchy-hotkeys-app/assets/icon.svg' $XDG_DATA_HOME/applications/omarchy-hotkeys-manual.desktop && [[ -f $HOME/.local/share/omarchy-hotkeys-app/assets/icon.svg ]]"
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
check "list" "$H list >$T/list; grep -q 'SUPER + ALT + T .*终端二  →  foot' $T/list"

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
check "official chapter in Chinese" "[[ \$(data $M | jq -r .official) == *快捷键的布局方式* ]]"
if command -v node >/dev/null || [[ -x /opt/node22/bin/node ]]; then
  N="$(command -v node || echo /opt/node22/bin/node)"
  sed -n '/^<script>$/,/^<\/script>$/p' "$M" | sed '1d;$d' >"$T/page.js"
  check "page script parses" "$N --check $T/page.js"
fi
echo en >"$S/lang"; $H manual --no-open >/dev/null
check "English manual" "grep -q '<title>Omarchy Hotkeys</title>' $XDG_DATA_HOME/omarchy-hotkeys/manual-en.html"
echo ja >"$S/lang"; $H manual --no-open >/dev/null
J="$XDG_DATA_HOME/omarchy-hotkeys/manual-ja.html"
check "Japanese: our words fall back to English, Omarchy's chapter is Japanese" "grep -q '<title>Omarchy Hotkeys</title>' $J && data $J | jq -r .official >$T/ja; grep -q 'ショートカット\|キー' $T/ja"
echo zh-TW >"$S/lang"; $H list >/dev/null; $H remove "SUPER + ALT + Z" >"$T/o" 2>&1
check "Traditional Chinese messages" "grep -q '你的自訂快捷鍵裡沒有' $T/o"

echo "doctor / test"
echo zh-CN >"$S/lang"
$H add "SUPER + ALT + M" "不存在" "no-such-program-xyz --flag" >"$T/o" 2>&1
check "add warns when the command is missing" "grep -q '找不到命令「no-such-program-xyz」' $T/o"
mkdir -p "$OMARCHY_PATH/default/hypr"; touch "$OMARCHY_PATH/default/hypr/toggles.lua"
$H doctor >"$T/doc" 2>&1
check "doctor: Lua config and file found" "grep -q '✓ Omarchy 会读取自定义快捷键文件' $T/doc && grep -q '✓ 自定义快捷键文件' $T/doc"
check "doctor: flags a hotkey Hyprland does not have" "grep -q '✗ SUPER + ALT + M 没有在 Hyprland 中生效' $T/doc"
check "doctor: flags the missing command" "grep -q '✗ 找不到命令：no-such-program-xyz' $T/doc"
check "doctor: replaced browser hotkey seen as active" "grep -q 'SUPER + SHIFT + B 已在 Hyprland 中生效' $T/doc"
rm -f "$OMARCHY_PATH/default/hypr/toggles.lua"; $H doctor >"$T/doc" 2>&1
check "doctor: old Omarchy without Lua config is reported" "grep -q '✗ 这个 Omarchy 版本不读取' $T/doc"
$H add "SUPER + ALT + E" "回显" "echo hotkey-test-ok" --force >/dev/null 2>&1
$H test "SUPER + ALT + E" >"$T/o" 2>&1
check "test runs the command and shows its output" "grep -q 'hotkey-test-ok' $T/o"
$H remove "SUPER + ALT + M" >/dev/null; $H remove "SUPER + ALT + E" >/dev/null

echo "wizard"
# gum stand-in: each call takes the next scripted answer; confirm answers y/n.
stub gum "if [[ \$1 == style ]]; then echo \"\${@: -1}\"; exit 0; fi; a=\$(head -1 $S/gum); sed -i 1d $S/gum; echo \"\$1 \$a\" >>$S/gum.log; if [[ \$1 == confirm ]]; then [[ \$a == y ]]; else [[ \$a == CANCEL ]] && exit 1; printf '%s\\n' \"\$a\"; fi"
mkdir -p "$XDG_DATA_HOME/applications"
printf '[Desktop Entry]\nType=Application\nName=Text Editor\nName[zh_CN]=文本编辑器\nExec=edit\n' >"$XDG_DATA_HOME/applications/org.example.Editor.desktop"
printf '[Desktop Entry]\nType=Application\nName=Hidden thing\nNoDisplay=true\n' >"$XDG_DATA_HOME/applications/hidden.desktop"
printf '%s\n' "打开一个应用" "文本编辑器" "Super + Shift：打开应用 · 推荐" "E" "保存" >"$S/gum"
$H wizard >"$T/o" 2>&1
check "wizard: app picked by its Chinese name, free key, saved" "grep -q \"^SUPER + SHIFT + E | 文本编辑器 | uwsm-app -- 'org.example.Editor.desktop'\$\" $CONF && grep -q '设好了！按 SUPER + SHIFT + E 试试' $T/o"
check "wizard: hidden apps not offered" "$H apps >$T/apps 2>/dev/null; ! grep -q 'Hidden thing' $T/apps && grep -q '文本编辑器' $T/apps"
check "wizard: B is taken by the browser, so not offered" "$H free 'SUPER + SHIFT' 65 >$T/free; ! grep -qx B $T/free && grep -qx C $T/free"
printf '%s\n' "打开一个网页" "youtube.com/feed" "Super + Ctrl + Alt：快捷操作" "Y" "保存" >"$S/gum"
$H wizard >"$T/o" 2>&1
check "wizard: web page, https added, host as label" "grep -q \"^SUPER + CTRL + ALT + Y | youtube.com | omarchy-launch-webapp 'https://youtube.com/feed'\$\" $CONF"
printf '%s\n' "打开一个网页" "not a url" >"$S/gum"
$H wizard >"$T/o" 2>&1
check "wizard: bad web address refused" "grep -q '不像网址' $T/o && ! grep -q 'not a url' $CONF"
printf '%s\n' "打开一个应用" "文本编辑器" "Super + Shift：打开应用 · 推荐" "F" "取消" >"$S/gum"
$H wizard >/dev/null 2>&1
check "wizard: saying no at the end saves nothing" "! grep -q '^SUPER + SHIFT + F |' $CONF"
check "wizard file still valid Lua" "lua_ok"
$H remove "SUPER + SHIFT + E" >/dev/null; $H remove "SUPER + CTRL + ALT + Y" >/dev/null

echo "record keys"
touch "$S/rec-ok"
(sleep 1; $H captured "super + f1") &
printf '%s\n' "打开一个网页" "example.com" "保存" >"$S/gum"
$H wizard >"$T/o" 2>&1; wait
check "pressing SUPER + F1 records it and Save stores it" "grep -q \"^SUPER + F1 | example.com | omarchy-launch-webapp 'https://example.com'\$\" $CONF && grep -q '你按的是：SUPER + F1' $T/o"
check "recording mode is left and Hyprland reloaded" "grep -q 'hl.dsp.submap(\"reset\")' $S/dispatch.log"
check "recording Lua is valid and enters the submap" "! command -v luac5.4 >/dev/null || luac5.4 -p $S/eval.lua && grep -q 'hl.dispatch(hl.dsp.submap(\"omarchy-hotkeys-record\"))' $S/eval.lua"
(sleep 1; $H captured "SUPER + SHIFT + B") &
printf '%s\n' "打开一个网页" "example.org" "取消" >"$S/gum"
$H wizard >"$T/o" 2>&1; wait
check "a taken combination says what it does now; Cancel saves nothing" "grep -q '它现在用于「浏览器」，保存后会替换' $T/o && ! grep -q example.org $CONF"
(sleep 1; $H captured cancel) &
printf '%s\n' "打开一个网页" "example.net" "取消" >"$S/gum"
$H wizard >"$T/o" 2>&1; wait
check "Esc while recording cancels" "grep -q '已取消' $T/o && ! grep -q example.net $CONF"
check "settings window: floating and solid" "grep -q 'o.window(\"org.omarchy.hotkeys\", { opacity = \"1 1\" })' $LUA && lua_ok"
rm -f "$S/rec-ok"; $H remove "SUPER + F1" >/dev/null

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
