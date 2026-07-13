#!/bin/bash
# OPTIONAL reinstaller/updater. Winlink Express is already installed in the
# image at build time — you normally do NOT need this. Use it to reinstall or
# to pull a newer release. Run it inside the VNC desktop.
set -e

export WINEPREFIX="$HOME/.wine"
export WINEDEBUG=-all

BASE="https://downloads.winlink.org/User%20Programs/"

echo "Looking up the current Winlink Express installer on winlink.org ..."
FILE=$(curl -fsSL "$BASE" | grep -oE 'Winlink_Express_install_[0-9-]+\.zip' | sort -uV | tail -1)
if [ -z "$FILE" ]; then
    echo "Could not find an installer at $BASE"
    echo "Download it manually (https://winlink.org) into ~/installers and unzip/run it with wine."
    exit 1
fi

mkdir -p "$HOME/installers"
cd "$HOME/installers"
if [ ! -f "$FILE" ]; then
    echo "Downloading $FILE ..."
    curl -fLO "$BASE$FILE"
fi

rm -rf /tmp/winlink-setup
mkdir -p /tmp/winlink-setup
unzip -o "$FILE" -d /tmp/winlink-setup

SETUP=$(find /tmp/winlink-setup \( -iname '*.msi' -o -iname 'setup*.exe' -o -iname '*install*.exe' \) | head -1)
if [ -z "$SETUP" ]; then
    echo "Unzipped, but no installer found in /tmp/winlink-setup — run it manually with wine."
    exit 1
fi

echo "Running $SETUP under Wine (silent install) ..."
case "$SETUP" in
    *.msi) wine msiexec /i "$SETUP" /qn ;;
    *)     timeout 300 wine "$SETUP" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- || true ;;
esac
wineserver -w

echo
echo "Done. Launch with:  winlink   (or from the XFCE menu / desktop icon)."
