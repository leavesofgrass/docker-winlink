# Configuration

All settings live in `.env` (copied from `.env.example`). Change them any time;
password and port changes just need `docker compose up -d`.

| Setting | What it does | Default |
| --- | --- | --- |
| `USER_PASSWORD` | Account password (also SSH + `sudo`) | `changeme` |
| `VNC_PASSWORD` | Desktop login password | `changeme` |
| `VNC_GEOMETRY` | Desktop resolution | `1280x800` |
| `VNC_PORT` | Host port for the VNC client | `5900` |
| `NOVNC_PORT` | Host port for the browser desktop | `6080` |
| `SSH_PORT` | Host port for the fallback SSH shell | `2424` |
| `SSH_PUBKEY` | Public key for key-based SSH login (else use password) | empty |
| `PULSE_SERVER` | Where audio goes (see [audio.md](audio.md)) | host default |
| `HAM_USER` | Login name inside the container | `ham` |

## Ports & connecting

| Service | Connect | Notes |
| --- | --- | --- |
| Browser desktop | <http://localhost:6080/vnc.html> | easiest; enter `VNC_PASSWORD` |
| VNC client | `localhost:5900` | any VNC viewer |
| SSH shell | `ssh -p 2424 ham@localhost` | `USER_PASSWORD` or `SSH_PUBKEY`; root login disabled |

Ports bind to `localhost` only, so nothing is exposed to your network unless you
forward it. After a rebuild the SSH host key changes — if SSH complains, run
`ssh-keygen -R "[localhost]:2424"`.

## Data & persistence

Your Winlink messages, VARA registration, and settings live in a Docker volume
(`docker-winlink_ham-home`) and survive stop/start/rebuild. `docker compose
down -v` wipes it and resets to a clean install.

## Offline references

Built into the image, in the **Ham Radio → Ham Radio References** menu (or the
`~/References` folder):

- **FCC Part 97** — the complete amateur rules (public-domain PDF).
- **US Band Privileges** — frequency privileges by license class.
- **MCARES templates** — reference sheets + CHIRP files (Portland, OR area).

## Windows-only apps

Winlink Express and VARA are pre-installed and download from their official
sites at build time. To reinstall or update them, run inside the desktop:

```bash
install-winlink.sh   # re-fetch + reinstall Winlink Express
install-vara.sh      # reinstall VARA FM + HF
```
