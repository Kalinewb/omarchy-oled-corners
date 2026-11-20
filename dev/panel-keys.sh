#!/bin/bash

# The settings panel's keys, and what each one writes.
#
#   ./dev/panel-keys.sh
#
# Up/Down pick a row, Left/Right step its radius, F or Backspace hand it back to the level above, Esc
# closes, anything else does nothing. A stand-in for Surface.qml records every nudge and follow the panel
# asks for, so the check is on what would be written, not on how the rows look.
# qmltestrunner, offscreen: CornersPanel.qml on a stand-in host, no shell, no window.

set -uo pipefail
GREEN=$'\e[32m'; RED=$'\e[31m'; DIM=$'\e[2m'; RESET=$'\e[0m'
REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
RUNNER=/usr/lib/qt6/bin/qmltestrunner
[[ -x $RUNNER ]] || { echo "panel-keys: $RUNNER is not installed (qt6-declarative)" >&2; exit 1; }

work=$(mktemp -d /tmp/oled-corners-keys.XXXXXX)
trap 'rm -rf "$work"' EXIT
# The panel on the vendored kit, with the kit's theme swapped for a stub that needs no Quickshell and no
# qs.Commons (qmltestrunner has neither). A scratch copy: the plugin's own ui/ is untouched.
stage="$work/panel"; mkdir -p "$stage"
cp "$REPO/CornersPanel.qml" "$stage/"; cp -r "$REPO/ui" "$stage/ui"; cp "$REPO/dev/tests/StubTheme.qml" "$stage/ui/UTheme.qml"
sed -e "s#@REPO@#$stage#g" "$REPO/dev/tst_panel_keys.qml.in" >"$work/tst_panel_keys.qml"
out=$(cd "$work" && QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-$work}" timeout 60 "$RUNNER" -input "$work" 2>&1)
failures=0; checks=0
while IFS= read -r line; do
  name=${line#*::}; name=${name#*::}; name=${name%%(*}
  checks=$((checks + 1))
  case $line in
    PASS*) echo "  ${GREEN}pass${RESET}  ${name#test_}" ;;
    FAIL*) echo "  ${RED}FAIL${RESET}  ${name#test_}"; grep -A3 -F "$line" <<<"$out" | grep -E 'Actual|Expected' | sed 's/^/        /'; failures=$((failures + 1)) ;;
  esac
done < <(grep -E '^(PASS|FAIL).*::test_' <<<"$out")
(( checks > 0 )) || { echo "  ${RED}FAIL${RESET}  the test ran no cases"; echo "$out" | tail -5; exit 1; }
echo
if (( failures )); then echo "${RED}$failures of $checks checks failed.${RESET}"; exit 1; fi
echo "${GREEN}All $checks checks pass.${RESET}"
