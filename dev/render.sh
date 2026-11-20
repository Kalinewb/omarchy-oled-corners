#!/bin/bash

# Render the settings panel to a PNG, offscreen, on a stand-in surfaceHost.
#
#   ./dev/render.sh --out <png> [--mode hosted|standalone] [--host black|white] [--selected <row>]
#                   [--broken] [--zone] [--panel <dir>] [--theme current|<name>]
#   ./dev/render.sh --all <dir>      every picture the docs use: hosted black and white, standalone
#
# `--panel <dir>` renders the CornersPanel.qml of another checkout (the "before" pictures come from
# a checkout of the commit before the kit). Offscreen with the OpenGL RHI, as the kit's gallery.sh
# and omarchy-notch dev/glow.sh; nothing opens a real window and nothing touches the running shell.

set -uo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SHELL_PATH=${OMARCHY_PATH:-/usr/share/omarchy}

panel=$REPO; mode=hosted; host=black; out=""; selected=0; broken=0; zone=0; theme=current; all=""
while (($#)); do
  case $1 in
    --out) out=$2; shift 2 ;;
    --mode) mode=$2; shift 2 ;;
    --host) host=$2; shift 2 ;;
    --selected) selected=$2; shift 2 ;;
    --broken) broken=1; shift ;;
    --zone) zone=1; shift ;;
    --panel) panel=$(cd "$2" && pwd) || exit 2; shift 2 ;;
    --theme) theme=$2; shift 2 ;;
    --all) all=$2; shift 2 ;;
    *) echo "render: unknown argument $1" >&2; exit 2 ;;
  esac
done

root=$(mktemp -d "${TMPDIR:-/tmp}/oled-corners-render.XXXXXX")
trap 'rm -rf "$root"' EXIT
ln -s "$SHELL_PATH/shell/Commons" "$root/Commons"
ln -s "$SHELL_PATH/shell/Ui" "$root/Ui"
ln -s "$panel" "$root/repo"
cp "$REPO/dev/harness/render.qml" "$root/shell.qml"

render() { # render <mode> <host> <selected> <broken> <zone> <png>
  local log="$root/log.$$"
  UI_RENDER_MODE=$1 UI_RENDER_HOST=$2 UI_RENDER_SELECTED=$3 UI_RENDER_BROKEN=$4 UI_RENDER_ZONE=$5 UI_RENDER_OUT=$6 UI_RENDER_THEME=$theme \
    QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl QT_QPA_PLATFORM=offscreen \
    timeout 60 quickshell -p "$root" -n >"$log" 2>&1
  sed 's/\x1b\[[0-9;]*m//g' "$log" | sed -n 's/^.*RENDER //p'
  sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -E 'WARN scene|WARN qml|ERROR|ui: ' | head -10 | sed 's/^/  ! /'
  [[ -s $6 ]]
}

if [[ -n $all ]]; then
  mkdir -p "$all"
  status=0
  for spec in "hosted black" "hosted white" "standalone black"; do
    read -r m h <<<"$spec"
    name=$m; [[ $m == hosted ]] && name=$m-$h
    render "$m" "$h" 0 0 0 "$all/$name.png" || status=1
    render "$m" "$h" 1 0 0 "$all/$name-row2.png" || status=1
  done
  render hosted black 0 1 0 "$all/hosted-black-broken.png" || status=1
  render hosted black 0 0 1 "$all/hosted-black-zone.png" || status=1
  exit $status
fi

[[ -n $out ]] || { echo "render: --out <png> or --all <dir> is required" >&2; exit 2; }
render "$mode" "$host" "$selected" "$broken" "$zone" "$out"
