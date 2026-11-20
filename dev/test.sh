#!/bin/bash

# Everything the plugin checks about itself, offscreen, nothing installed or reloaded.
#
#   ./dev/test.sh              lint, radius.js, the panel's zone and keys, the UI gate and its walk
#   ./dev/test.sh --quick      lint and the node tests only
#
# Each part prints its own pass/FAIL lines; this prints one summary. The scanner
# (bin/scan.mjs in the suite repo) is run by hand: it is not part of this repo.

set -uo pipefail

GREEN=$'\e[32m'; RED=$'\e[31m'; BOLD=$'\e[1m'; RESET=$'\e[0m'
REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
quick=0; [[ ${1:-} == --quick ]] && quick=1
cd "$REPO" || exit 1

failures=0
run() { # run <name> <command...>
  local name=$1; shift
  echo; echo "${BOLD}== $name${RESET}"
  if "$@"; then :; else failures=$((failures + 1)); echo "  ${RED}FAIL${RESET}  $name exited non-zero"; fi
}

run "QML lint and script syntax" ./dev/lint.sh
run "node: radius.js" node dev/tests/radius.mjs
run "node: the test stub still matches what the panel and the kit read" node dev/tests/stub-surface.mjs
if ((!quick)); then
  run "the panel and the notch's back zone (qmltestrunner)" ./dev/panel-zone.sh
  run "the panel's keys, and what each one writes (qmltestrunner)" ./dev/panel-keys.sh
  run "the UI gate: ui/ is the kit, no literals, no private controls, one Esc; the walk on the panel" ./dev/check-ui.sh --score --walk CornersPanel.qml
  run "the walk again, on three screens and a broken panel.json" ./dev/check-ui.sh --walk dev/walk-root.qml
fi

echo
if ((failures)); then echo "${RED}$failures part(s) failed${RESET}"; exit 1; fi
echo "${GREEN}everything passes${RESET}"
