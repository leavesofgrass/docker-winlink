# Troubleshooting

**The browser page won't load / "connection refused".**
The container is still building or starting. Check `docker compose ps` and
`docker compose logs -f`. The first build takes 20–30 minutes.

**"Port is already in use".**
Something else uses 5900 / 6080 / 2424. Change `VNC_PORT` / `NOVNC_PORT` /
`SSH_PORT` in `.env` and `docker compose up -d`.

**SSH: "REMOTE HOST IDENTIFICATION HAS CHANGED".**
Normal after a rebuild (new host key). Clear the old one:
`ssh-keygen -R "[localhost]:2424"`.

**Build error mentioning `\r` or "bad interpreter".**
A script got Windows (CRLF) line endings. The repo's `.gitattributes` prevents
this on clone; if you copied files by hand, re-clone instead.

**Winlink Express shows a ".NET" prompt / opens a browser.**
Shouldn't happen — the image installs .NET 4.8. If you see it after tampering
with the Wine prefix, rebuild: `docker compose build --no-cache`.

**No sound.**
Expected on Docker Desktop unless you set up a host PulseAudio server — see
[audio.md](audio.md). Telnet Winlink and packet don't need audio.

**A radio isn't detected.**
On Windows the USB device must be attached to WSL2 with usbipd first, then
mapped with `radio-connect` — see [radios.md](radios.md).

**Start over from scratch.**
`docker compose down -v` wipes the saved data (Wine prefix, Winlink/VARA
settings) and reseeds a clean install on the next `up`.

**Rolling-release note.**
This is built on Arch Linux. Don't run `pacman -Sy <pkg>` alone inside the
container (partial upgrades break Arch) — rebuild the image to update instead.
