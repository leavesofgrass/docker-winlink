# syntax=docker/dockerfile:1
#
# Docker WinLink — an Arch Linux desktop (XFCE over VNC) for amateur radio,
# focused on Winlink Express + VARA under Wine. direwolf (software TNC for
# Packet Winlink), CHIRP, and hamlib are included; heavier native apps are not,
# to keep the build fast.
#   - TigerVNC on display :0  -> port 5900 (any VNC client)
#   - noVNC browser client    -> port 6080 (http://localhost:6080/vnc.html)
#   - Wine prefix with .NET 4.8 + VB6 + VC++2015 runtimes, with Winlink
#     Express, VARA FM and VARA HF already installed at build time (from
#     downloads.winlink.org — see the WINLINK_URL / VARA_*_URL args below).
#     Click their launchers in the XFCE "Ham Radio" menu, or run
#     winlink / varafm / varahf.
#   - direwolf (software TNC for Packet Winlink / APRS), CHIRP (chirp-next, radio
#     programming), and hamlib (CAT control) — all in the Ham Radio menu.
#   - USB radios: the desktop user can reach serial devices and a helper,
#     "radio-connect", maps them to Wine COM ports for Winlink/VARA. See the
#     "Connecting radios" section of README.md (Docker Desktop needs usbipd-win).
#   - Offline references (no Internet needed after build): the full FCC Part 97
#     rules PDF, a US band-privileges quick chart, and the Multnomah County ARES
#     frequency lists + CHIRP/RT-Systems programming templates — under
#     /usr/share/ham-references and in the Ham Radio menu. Plus a PDF viewer and
#     text editor.
#
# Build-time overrides (via --build-arg or compose .env):
#   USERNAME      -> desktop user                          (default: ham)
#   USER_PASSWORD -> user's password (sudo)                (default: changeme)
#   PULSE_SERVER  -> pulseaudio host:port                  (default: tcp:host.docker.internal:4713)
#   WINLINK_URL   -> Winlink Express installer zip URL     (see ARG below)
#   VARA_FM_URL   -> VARA FM installer zip URL             (see ARG below)
#   VARA_HF_URL   -> VARA HF installer zip URL             (see ARG below)
#
# Runtime env (compose .env): VNC_PASSWORD, VNC_GEOMETRY.
#
# Wine note: Arch's wine package is the new WoW64 build — 32-bit Windows apps
# run without multilib/lib32 libraries, so [multilib] stays disabled and the
# userland stays pure 64-bit. WoW64 wine cannot create win32 prefixes
# (WINEARCH=win32 aborts), so the prefix is the default win64; 32-bit apps
# like Winlink Express (.NET) and VARA (VB6) run in it via WoW64.
#
# .NET note: current Winlink Express requires .NET Framework 4.8 (its
# RMS Express.exe.config pins sku=".NETFramework,Version=v4.8"). Installing an
# older framework makes it pop a "please install .NET" dialog and open a
# browser — which is why 4.8, not 4.6.2, is provisioned below.
#
# NOTE: no shell comments inside RUN blocks. A backslash line-continuation MUST
# be the last character on the line; a trailing "# comment" breaks the build.

ARG USERNAME=ham
ARG USER_PASSWORD=changeme

# Windows-app installer URLs. Pinned for reproducibility (Wine is version-
# sensitive and these are emergency-comms tools — a known-good set beats
# "whatever is latest today"). To update: browse the two winlink.org
# directories, copy the new URL-encoded links here, rebuild. Note VARA HF's
# link has a double space before "setup" — keep it exactly as published.
#   https://downloads.winlink.org/User%20Programs/
#   https://downloads.winlink.org/VARA%20Products/
ARG WINLINK_URL=https://downloads.winlink.org/User%20Programs/Winlink_Express_install_1-8-2-0.zip
ARG VARA_FM_URL=https://downloads.winlink.org/VARA%20Products/VARA%20FM%20v4.4.0%20setup.zip
ARG VARA_HF_URL=https://downloads.winlink.org/VARA%20Products/VARA%20HF%20v4.9.0%20%20setup.zip

# FCC Part 97 rules PDF — the official public-domain CFR edition from the U.S.
# Government Publishing Office. Bump the year to refresh (govinfo publishes a
# new title-47 volume ~each autumn).
ARG PART97_URL=https://www.govinfo.gov/content/pkg/CFR-2025-title47-vol5/pdf/CFR-2025-title47-vol5-part97.pdf

FROM archlinux:latest AS base

LABEL maintainer="kd7swh@gmail.com"
LABEL description="Docker WinLink: amateur-radio desktop (XFCE over VNC) with Winlink Express + VARA FM/HF under Wine, plus direwolf/CHIRP/hamlib and offline FCC references"

ARG PULSE_SERVER=tcp:host.docker.internal:4713

# ── Environment ──────────────────────────────────────────────────────────────
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PULSE_SERVER=${PULSE_SERVER}

# ── 1. Base system: XFCE (minimal set), VNC, Wine, audio client, fonts ───────
# pacman-key --init creates the local master key the docker image ships without
# (needed to verify the keyring). alsa-plugins provides the ALSA->Pulse bridge
# (asound.conf in step 3). xorg-server-xvfb + xorg-xdpyinfo are used by the Wine
# provisioning steps and the entrypoint's X-ready wait. base-devel + git are
# needed to bootstrap the AUR helper in step 2.
# (zenity + curl are added in step 3b, kept out of this layer so a change there
# doesn't invalidate this base layer.)
RUN pacman-key --init \
    && pacman -Sy --noconfirm archlinux-keyring \
    && pacman -Syu --noconfirm --needed \
      7zip adwaita-icon-theme alsa-plugins alsa-utils base-devel cabextract \
      dbus git gnutls libpulse mesa nano pavucontrol sudo thunar \
      tigervnc ttf-dejavu ttf-liberation unzip wget which wine winetricks \
      xfce4-panel xfce4-session xfce4-settings xfce4-terminal xfwm4 \
      xorg-server-xvfb xorg-xdpyinfo \
    && sed -i 's/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen \
    && locale-gen \
    && dbus-uuidgen --ensure \
    && rm -rf /var/cache/pacman/pkg/*

# ── 2. AUR: noVNC + hamradio-menus + direwolf ───────────────────────────────
# novnc (+ its websockify dep) serves the browser VNC on 6080; hamradio-menus
# provides the XFCE "Ham Radio" menu category the launchers file under. Both
# are prebuilt (no compile). direwolf is a small C build (~2 min) — it's the
# software TNC used for Packet Winlink / APRS (VARA has its own modem, but
# packet stations still need a TNC), pulling hamlib + gpsd as deps.
# yay bootstraps an AUR helper (yay-bin, a prebuilt binary) and stays installed
# so you can add more AUR packages inside the container later.
RUN set -eux; \
    useradd -m aurbuild; \
    echo 'aurbuild ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/aurbuild; \
    sudo -u aurbuild -H sh -c 'cd "$HOME" && git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si --noconfirm'; \
    sudo -u aurbuild -H yay -S --noconfirm --needed --removemake --cleanafter \
      novnc hamradio-menus direwolf; \
    userdel -r aurbuild; \
    rm -f /etc/sudoers.d/aurbuild; \
    rm -rf /var/cache/pacman/pkg/*

# ── 3. Audio config (ALSA → PulseAudio → server on the Windows host) ────────
# Wine (VARA / Winlink) plays through Pulse; direwolf (ALSA) uses the
# asound.conf bridge below -> both end up at the host PulseAudio.
RUN set -eux; \
    printf 'pcm.!default { type pulse }\nctl.!default { type pulse }\n' > /etc/asound.conf; \
    mkdir -p /etc/pulse; \
    printf 'default-server = %s\nautospawn = no\n' "${PULSE_SERVER}" > /etc/pulse/client.conf

# ── 3b. Desktop extras (separate layer to preserve the step-2 AUR cache) ────
# zenity: how Wine and winetricks draw GUI dialogs — without it, Wine apps that
# pop a message box (Winlink's first-run prompts) fail silently. curl: fetches
# the Windows installers (step 6) and Part 97 (step 3c). zathura + mupdf plugin:
# a light PDF viewer for the offline references. mousepad: a GUI text editor so
# the band-privileges chart is readable/printable without the terminal.
RUN pacman -Sy --noconfirm --needed \
      curl zenity zathura zathura-pdf-mupdf mousepad \
    && rm -rf /var/cache/pacman/pkg/*

# ── 3c. Offline references: FCC Part 97 rules + US band-privileges chart ─────
# Baked in so they work with no Internet. The band-privileges chart and README
# come from ./references (public-domain FCC data — see the README for the ARRL
# note). Part 97 is the official public-domain CFR PDF from govinfo.gov.
ARG PART97_URL
COPY references/ /usr/share/ham-references/
RUN set -eux; \
    curl -fL "${PART97_URL}" -o /usr/share/ham-references/FCC-Part-97.pdf; \
    chmod -R a+rX /usr/share/ham-references

# ── 4. User account (wheel sudo), installers + wine-template dirs ────────────
# /opt/wine-template is created here, owned by the user, so the next steps can
# build the Wine prefix DIRECTLY there (see step 5) — no second copy, which is
# what previously doubled the prefix on disk (~1.5 GB of dead weight).
ARG USERNAME
ARG USER_PASSWORD
RUN set -eux; \
    useradd -m -s /bin/bash "${USERNAME}"; \
    echo "${USERNAME}:${USER_PASSWORD}" | chpasswd; \
    usermod -aG wheel "${USERNAME}"; \
    printf '%%wheel ALL=(ALL:ALL) ALL\n' > /etc/sudoers.d/10-wheel; \
    chmod 440 /etc/sudoers.d/10-wheel; \
    mkdir -p /home/${USERNAME}/installers /opt/wine-template; \
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME} /opt/wine-template

# ── 5. Wine prefix: .NET 4.8 + VB6 + VC++2015 (as the user) ─────────────────
# Provisioned at build time under Xvfb so the slow winetricks work is baked
# into the image. dotnet48 is the long pole (Winlink Express needs it, see the
# .NET note in the header) and gets its own layer. mscoree/mshtml are disabled
# during wineboot so the missing wine-mono/gecko don't block the unattended
# init (real .NET is installed right after; these apps don't need gecko).
# vb6run gives VARA its Visual Basic 6 runtime; vcrun2015 covers common C++.
# WINEPREFIX points at /opt/wine-template so the prefix is built ONCE, at its
# final template location (the entrypoint seeds ~/.wine from it). This is reset
# to the per-user path for runtime in the Runtime section at the bottom.
USER ${USERNAME}
WORKDIR /home/${USERNAME}
ENV WINEPREFIX=/opt/wine-template
RUN set -eux; \
    xvfb-run -a env WINEDLLOVERRIDES="mscoree,mshtml=" wineboot --init; \
    wineserver -w
RUN set -eux; \
    xvfb-run -a winetricks -q --force dotnet48; \
    wineserver -w
RUN set -eux; \
    xvfb-run -a winetricks -q --force vb6run vcrun2015; \
    wineserver -w; \
    xvfb-run -a winetricks -q sound=pulse; \
    wineserver -w; \
    rm -rf "$HOME/.cache/winetricks"

# ── 6. Install Winlink Express + VARA FM/HF into the prefix (as the user) ────
# All three are Inno Setup installers, run unattended with /VERYSILENT. Even
# silent, they need a display for Wine's GUI init, hence xvfb-run; and Inno
# under Wine often doesn't exit cleanly, so each run is capped with `timeout`
# and success is judged by the target .exe existing (the build fails loudly
# otherwise). 120s is plenty — the installs finish in well under a minute; the
# cap only bounds the ones that don't self-terminate (it used to be 300, which
# just idled ~3 extra minutes per VARA installer). Since the prefix now lives at
# /opt/wine-template, the last thing this step does is stamp the template
# version marker the entrypoint checks (no separate copy step anymore).
ARG WINLINK_URL
ARG VARA_FM_URL
ARG VARA_HF_URL
ARG WINE_TEMPLATE_VERSION=1
RUN set -eux; \
    dl=/tmp/win-installers; mkdir -p "$dl"; cd "$dl"; \
    echo ">> Winlink Express"; \
    curl -fL "${WINLINK_URL}" -o winlink.zip; \
    rm -rf wl && mkdir wl && (cd wl && unzip -oq ../winlink.zip); \
    exe=$(find wl -iname '*.exe' | head -1); \
    timeout 120 xvfb-run -a wine "$exe" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- || true; \
    wineserver -w; \
    test -f "$WINEPREFIX/drive_c/RMS Express/RMS Express.exe"; \
    echo ">> VARA FM"; \
    curl -fL "${VARA_FM_URL}" -o varafm.zip; \
    rm -rf fm && mkdir fm && (cd fm && unzip -oq ../varafm.zip); \
    exe=$(find fm -iname '*.exe' | head -1); \
    timeout 120 xvfb-run -a wine "$exe" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- || true; \
    wineserver -w; \
    test -f "$WINEPREFIX/drive_c/VARA FM/VARAFM.exe"; \
    echo ">> VARA HF"; \
    curl -fL "${VARA_HF_URL}" -o varahf.zip; \
    rm -rf hf && mkdir hf && (cd hf && unzip -oq ../varahf.zip); \
    exe=$(find hf -iname '*.exe' | head -1); \
    timeout 120 xvfb-run -a wine "$exe" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- || true; \
    wineserver -w; \
    test -f "$WINEPREFIX/drive_c/VARA/VARA.exe"; \
    printf '%s\n' "${WINE_TEMPLATE_VERSION}" > "$WINEPREFIX/.ham-template-version"; \
    rm -rf "$dl" "$HOME/.cache/winetricks"

# ── 7. Template = the prefix itself (no copy needed) ────────────────────────
# The prefix was built directly at /opt/wine-template above, so there is nothing
# to stash — that's the ~1.5 GB the old copy step wasted. The compose file mounts
# a named volume over /home/${USERNAME}; because the template lives outside that
# mount, the entrypoint seeds/refreshes ~/.wine from it on start, so new
# spin-ups and rebuilds "just work" without `docker compose down -v`. Bump
# WINE_TEMPLATE_VERSION (build arg / step 6) when the baked apps change to
# trigger a re-seed. Back to root for the remaining system-level steps.
USER root

# ── 8. Launchers: Windows apps + references, all under the Ham Radio menu ────
# So operating the mode is a click (XFCE menu / desktop icon) or one word in a
# terminal. Each Windows-app wrapper cd's to the app's own directory first (its
# LINUX path under drive_c — VARA loads .dat files relative to the working dir)
# and runs the exe by name against the shared prefix. Everything is tagged
# Categories=...;HamRadio; so it shows in the "Ham Radio" menu (provided by the
# hamradio-menus package).
RUN set -eux; \
    mk_wine() { \
      name="$1"; cmd="$2"; subdir="$3"; exe="$4"; \
      printf '#!/bin/bash\nexport WINEPREFIX="$HOME/.wine"\nexport WINEDEBUG=-all\ncd "$WINEPREFIX/drive_c/%s" || exit 1\nexec wine "%s" "$@"\n' "$subdir" "$exe" > /usr/local/bin/"$cmd"; \
      chmod 755 /usr/local/bin/"$cmd"; \
      printf '[Desktop Entry]\nType=Application\nName=%s\nExec=%s\nIcon=applications-internet\nCategories=Network;HamRadio;\nTerminal=false\n' "$name" "$cmd" > /usr/share/applications/"$cmd".desktop; \
    }; \
    mk_wine "Winlink Express" winlink "RMS Express" "RMS Express.exe"; \
    mk_wine "VARA FM" varafm "VARA FM" "VARAFM.exe"; \
    mk_wine "VARA HF" varahf "VARA" "VARA.exe"; \
    printf '[Desktop Entry]\nType=Application\nName=Ham Radio References\nComment=FCC Part 97 + US band privileges (offline)\nExec=thunar /usr/share/ham-references\nIcon=accessories-dictionary\nCategories=Documentation;HamRadio;\nTerminal=false\n' > /usr/share/applications/ham-references.desktop; \
    printf '[Desktop Entry]\nType=Application\nName=FCC Part 97 Rules\nExec=zathura /usr/share/ham-references/FCC-Part-97.pdf\nIcon=accessories-dictionary\nCategories=Documentation;HamRadio;\nTerminal=false\n' > /usr/share/applications/fcc-part97.desktop; \
    printf '[Desktop Entry]\nType=Application\nName=US Band Privileges\nExec=mousepad /usr/share/ham-references/US-Amateur-Band-Privileges.txt\nIcon=accessories-dictionary\nCategories=Documentation;HamRadio;\nTerminal=false\n' > /usr/share/applications/us-band-privileges.desktop

# ── 8b. MCARES frequency lists + radio programming templates ────────────────
# Multnomah County ARES (Portland, OR) publishes these for operators to use:
# reference PDFs plus CHIRP and RT Systems (RTS) programming CSVs for the
# standard, MHT, 6 m and 220 patch plans, and the Oregon Regional template.
#   Source: https://multnomahares.org/resources/frequency-lists-and-radio-programming-templates/
# Placed in its own late layer (after the Wine work) so refreshing these
# community files — which get version-bumped periodically — doesn't invalidate
# the expensive .NET/app-install cache. Downloads are best-effort: a rotted
# link warns but doesn't fail the build (update the URL below and rebuild).
RUN set -eux; \
    dir=/usr/share/ham-references/MCARES-Frequency-Templates; \
    mkdir -p "$dir"; cd "$dir"; \
    for u in \
      https://multnomahares.org/wp-content/uploads/2026/01/MCARES-2025-STD-Template-V108-1219.pdf \
      https://multnomahares.org/wp-content/uploads/2025/09/MCARES-2025-STD-V1.08-0816-RTS.csv \
      https://multnomahares.org/wp-content/uploads/2025/09/MCARES-2025-STD-Template-V1.08-0816-Chirp.csv \
      https://multnomahares.org/wp-content/uploads/2025/09/MCARES-2025-MHT-Template-V1.05-0815.pdf \
      https://multnomahares.org/wp-content/uploads/2025/09/MCARES-2025-MHT-V1.05-0815-RTS.csv \
      https://multnomahares.org/wp-content/uploads/2025/09/MCARES-2025-MHT-Template-V1.05-0816-Chirp.csv \
      https://multnomahares.org/wp-content/uploads/2025/09/MCARES-2025-6M-Patch-V1.01-RTS-722.csv \
      https://multnomahares.org/wp-content/uploads/2025/09/MCARES-2025-6M-Patch-V1.01-Chirp.csv \
      https://multnomahares.org/wp-content/uploads/2025/09/MCARES-2025-220-Patch-V1.00-RTS-722.csv \
      https://multnomahares.org/wp-content/uploads/2025/09/MCARES-2025-220-Patch-V1.00-Chirp.csv \
      https://multnomahares.org/wp-content/uploads/2025/09/2025-Oregon-Regional-Ham-Template.pdf \
    ; do \
      curl -fLsS -O "$u" || echo "WARN: could not fetch $u"; \
    done; \
    printf '%s\n' \
      'MCARES FREQUENCY LISTS & RADIO PROGRAMMING TEMPLATES' \
      '' \
      'Source: Multnomah County ARES (Portland, Oregon)' \
      '  https://multnomahares.org/resources/frequency-lists-and-radio-programming-templates/' \
      '' \
      'Contents:' \
      '  *.pdf   -> printable reference sheets (open in the PDF viewer, zathura).' \
      '  *-Chirp.csv -> CHIRP programming templates. Open them in CHIRP (installed:' \
      '                 run "chirp" or use the Ham Radio menu) to program a radio.' \
      '  *-RTS.csv   -> RT Systems programming files (for RT Systems software).' \
      '' \
      'These are a regional (Portland, OR) ARES resource, published for operator' \
      'use. Verify you have the current versions from the source page above;' \
      'MCARES bumps versions and may remove older files over time.' \
      > "$dir/ABOUT.txt"; \
    chmod -R a+rX /usr/share/ham-references

# ── 8c. Radio connectivity: CHIRP + hamlib + USB serial access ──────────────
# chirp-next programs the radios (and opens the bundled CHIRP templates);
# hamlib gives rigctl/rigctld CAT control + PTT (used by direwolf and for
# testing — Winlink Express and VARA do their own CAT). The desktop user joins
# uucp/audio/lock for serial + sound-card access, and a narrow sudoers rule
# lets it fix serial-device permissions at runtime via the radio-perms helper
# (copied in step 9). radio-connect (step 9) maps USB serial ports to Wine COM
# ports so Winlink/VARA can select the radio. Kept late so it doesn't rebuild
# the Wine layers.
RUN set -eux; \
    pacman -Sy --noconfirm --needed hamlib; \
    useradd -m aurbuild; \
    echo 'aurbuild ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/aurbuild; \
    ok=0; \
    for attempt in 1 2 3 4 5 6; do \
      if sudo -u aurbuild -H yay -S --noconfirm --needed --removemake --cleanafter chirp-next; then ok=1; break; fi; \
      echo "chirp-next install failed (attempt ${attempt}, AUR may be briefly down); retrying in 20s..."; \
      sleep 20; \
    done; \
    [ "$ok" = 1 ]; \
    userdel -r aurbuild; \
    rm -f /etc/sudoers.d/aurbuild; \
    usermod -aG uucp,audio,lock "${USERNAME}"; \
    printf '%%wheel ALL=(root) NOPASSWD: /usr/local/bin/radio-perms\n' > /etc/sudoers.d/20-radio; \
    chmod 440 /etc/sudoers.d/20-radio; \
    printf '[Desktop Entry]\nType=Application\nName=Connect USB Radio\nComment=Detect USB radios and map them to Wine COM ports\nExec=radio-connect\nIcon=network-wired\nCategories=HamRadio;\nTerminal=true\n' > /usr/share/applications/radio-connect.desktop; \
    rm -rf /var/cache/pacman/pkg/*

# ── 8d. Fallback SSH server (port 2424) ─────────────────────────────────────
# A plain sshd so you can get a shell, scp files, or install packages WITHOUT
# the VNC desktop — a safety net if the GUI is wedged. Port 2424 keeps it clear
# of the Debian (2222) and Arch (2223) dev containers. Root login is disabled;
# log in as the desktop user with USER_PASSWORD (or an SSH_PUBKEY, which the
# entrypoint installs at runtime so it works with the persistent home volume).
# Host keys are generated now; the entrypoint launches sshd via a narrow
# sudoers rule (sshd needs root; the desktop runs as the user). `sshd -t`
# validates the config so a bad edit fails the build here. Late layer.
RUN set -eux; \
    pacman -Sy --noconfirm --needed openssh; \
    sed -i \
      -e 's/^#\?Port .*/Port 2424/' \
      -e 's/^#\?PermitRootLogin .*/PermitRootLogin no/' \
      -e 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' \
      /etc/ssh/sshd_config; \
    ssh-keygen -A; \
    mkdir -p /run/sshd; \
    /usr/bin/sshd -t; \
    printf '%%wheel ALL=(root) NOPASSWD: /usr/local/bin/ham-sshd\n' > /etc/sudoers.d/21-sshd; \
    chmod 440 /etc/sudoers.d/21-sshd; \
    rm -rf /var/cache/pacman/pkg/*

# ── 9. Entrypoint + helper scripts (radio, sshd, optional reinstallers) ─────
# Last so script tweaks never invalidate the slow Wine layers above. radio-perms
# and ham-sshd are root-only (invoked via the sudoers rules above); the
# install-* scripts are optional reinstall/update helpers (apps are baked in).
COPY --chmod=755 entrypoint.sh radio-connect radio-perms ham-sshd install-winlink.sh install-vara.sh /usr/local/bin/

# ── Runtime ──────────────────────────────────────────────────────────────────
# Back to the desktop user (steps 7-9 ran as root); the desktop + Wine apps
# all run unprivileged (sshd is started with sudo by the entrypoint).
# Reset WINEPREFIX from the build-time template path to the per-user prefix the
# entrypoint seeds and the launchers use; a bare `wine ...` now targets ~/.wine.
ENV WINEPREFIX=/home/${USERNAME}/.wine
USER ${USERNAME}
WORKDIR /home/${USERNAME}
EXPOSE 5900 6080 2424
CMD ["/usr/local/bin/entrypoint.sh"]
