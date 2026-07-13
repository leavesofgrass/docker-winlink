#!/bin/bash
# Starts the desktop: Xvnc (display :0, VNC on 5900) -> XFCE -> noVNC (6080).
# VNC_PASSWORD and VNC_GEOMETRY come from the environment (compose .env).
# If any of the three long-running pieces dies, the container exits and the
# compose restart policy brings it back.
set -e

# ── Wine prefix auto-heal ────────────────────────────────────────────────────
# /home/<user> is a persistent named volume, so the Wine prefix baked at build
# time (with Winlink Express + VARA installed) does NOT live in it — it is
# stashed at /opt/wine-template. Seed ~/.wine from the template on first start,
# and re-seed whenever the template's version changes (i.e. after a rebuild
# that updated the baked apps). Matching versions on a plain restart => skip,
# so the user's callsign, settings and messages persist.
TEMPLATE=/opt/wine-template
PREFIX="$HOME/.wine"
if [ -d "$TEMPLATE" ]; then
    tmpl_ver=$(cat "$TEMPLATE/.ham-template-version" 2>/dev/null || echo 0)
    cur_ver=$(cat "$PREFIX/.ham-template-version" 2>/dev/null || echo none)
    if [ "$tmpl_ver" != "$cur_ver" ]; then
        echo "ham-shack: seeding Wine prefix from template (v${cur_ver} -> v${tmpl_ver})..."
        rm -rf "$PREFIX"
        cp -a "$TEMPLATE" "$PREFIX"
    fi
fi

# Offline references: link the baked folder into the home dir so it's easy to
# find (also reachable from the Ham Radio menu and /usr/share/ham-references).
if [ -d /usr/share/ham-references ] && [ ! -e "$HOME/References" ]; then
    ln -s /usr/share/ham-references "$HOME/References"
fi

# Desktop shortcuts for the Windows apps + references (menu entries always
# exist; these add clickable icons on the desktop). Copied once; user changes
# are left alone.
mkdir -p "$HOME/Desktop"
for d in winlink varafm varahf ham-references; do
    if [ ! -e "$HOME/Desktop/$d.desktop" ] && [ -f "/usr/share/applications/$d.desktop" ]; then
        cp "/usr/share/applications/$d.desktop" "$HOME/Desktop/$d.desktop"
        chmod +x "$HOME/Desktop/$d.desktop"
    fi
done

# Optional SSH public key — written at runtime so it works with the persistent
# home volume (a build-time copy would be shadowed by the volume mount).
if [ -n "${SSH_PUBKEY:-}" ]; then
    mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
    printf '%s\n' "$SSH_PUBKEY" > "$HOME/.ssh/authorized_keys"
    chmod 600 "$HOME/.ssh/authorized_keys"
fi

# Map any already-attached USB radios to Wine COM ports (harmless if none).
# Re-run `radio-connect` in a terminal after attaching a radio at runtime.
if command -v radio-connect >/dev/null 2>&1; then
    radio-connect >/dev/null 2>&1 || true
fi

# Fallback SSH server (port 2424) — started as root via the sudoers rule, so a
# wedged desktop never locks you out. Backgrounded and supervised like the rest.
if command -v ham-sshd >/dev/null 2>&1; then
    sudo -n /usr/local/bin/ham-sshd &
fi

rm -f /tmp/.X0-lock /tmp/.X11-unix/X0

mkdir -p "$HOME/.vnc"
if [ ! -f "$HOME/.vnc/passwd" ]; then
    printf '%s' "${VNC_PASSWORD:-changeme}" | vncpasswd -f > "$HOME/.vnc/passwd"
    chmod 600 "$HOME/.vnc/passwd"
fi

Xvnc :0 \
    -geometry "${VNC_GEOMETRY:-1280x800}" \
    -depth 24 \
    -rfbport 5900 \
    -rfbauth "$HOME/.vnc/passwd" \
    -AlwaysShared \
    -desktop "ham-shack" &

export DISPLAY=:0
for _ in $(seq 1 60); do
    if xdpyinfo >/dev/null 2>&1; then break; fi
    sleep 0.5
done

dbus-run-session startxfce4 &

novnc --vnc localhost:5900 --listen 6080 &

wait -n
exit 1
