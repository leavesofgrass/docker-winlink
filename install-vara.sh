#!/bin/bash
# OPTIONAL reinstaller/updater. VARA FM and VARA HF are already installed in
# the image at build time — you normally do NOT need this. Use it to reinstall
# or to install a different version. Run it inside the VNC desktop.
#
# It installs, in order of preference:
#   1) any *vara*.zip you dropped into ~/installers  (from the Windows host)
#   2) otherwise, the current VARA FM + VARA HF from downloads.winlink.org
set -e
shopt -s nullglob nocaseglob

export WINEPREFIX="$HOME/.wine"
export WINEDEBUG=-all

install_zip() {
    z="$1"
    d="/tmp/$(basename "$z" .zip)"
    rm -rf "$d"; mkdir -p "$d"
    unzip -o "$z" -d "$d" >/dev/null
    exe=$(find "$d" -iname '*.exe' | head -1)
    if [ -z "$exe" ]; then echo "No .exe inside $z"; return 1; fi
    echo ">> installing $(basename "$z") ..."
    timeout 300 wine "$exe" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- || true
    wineserver -w
}

zips=("$HOME"/installers/*vara*.zip)
if [ ${#zips[@]} -gt 0 ]; then
    for z in "${zips[@]}"; do install_zip "$z"; done
else
    echo "No local VARA zip in ~/installers — downloading current versions from winlink.org"
    tmp=$(mktemp -d)
    curl -fL 'https://downloads.winlink.org/VARA%20Products/VARA%20FM%20v4.4.0%20setup.zip' -o "$tmp/varafm.zip"
    curl -fL 'https://downloads.winlink.org/VARA%20Products/VARA%20HF%20v4.9.0%20%20setup.zip' -o "$tmp/varahf.zip"
    install_zip "$tmp/varafm.zip"
    install_zip "$tmp/varahf.zip"
    rm -rf "$tmp"
fi

echo
echo "Done. Launch with:  varafm   (VARA FM)   or   varahf   (VARA HF)"
echo "or from the XFCE menu / desktop icons."
