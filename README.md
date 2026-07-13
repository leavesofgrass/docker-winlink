# Ham Shack in a Box 📻

A ready-to-run **amateur-radio desktop in a container**. It gives you a full
Linux desktop — reachable from your web browser — with **Winlink Express**,
**VARA FM**, **VARA HF**, **Dire Wolf**, and **CHIRP** already installed and set
up. No Linux knowledge required, and you never have to install or configure any
of the radio software yourself.

You run one command, open a web page, and you're on a working ham-radio
workstation.

> 📡 You need an **amateur radio license** to transmit. Winlink's telnet mode
> and everything else here work fine for practice with no radio and no license.

---

## What you get

| App | What it's for |
| --- | --- |
| **Winlink Express** | Send/receive Winlink email (radio *or* internet "telnet") |
| **VARA FM / VARA HF** | The modems Winlink and others use over the air |
| **Dire Wolf** | Software TNC for packet / APRS |
| **CHIRP** | Program your handheld/mobile radios |
| **hamlib** | Rig control (`rigctl`) |
| **Offline references** | Full FCC Part 97 rules + a US band-privileges chart, built in |

You reach it three ways (all on your own computer, nothing exposed to the
internet):

| How to connect | Address | Port |
| --- | --- | --- |
| **Web browser** (easiest — nothing to install) | <http://localhost:6080/vnc.html> | 6080 |
| VNC client | `localhost:5900` | 5900 |
| SSH (a plain terminal, for fixing things) | `ssh -p 2424 ham@localhost` | 2424 |

---

## Quick start

### 1. Install Docker Desktop

Docker is the program that runs this container. Install **Docker Desktop** for
your system and **start it** (wait for the whale icon to say it's running):

- Windows / macOS: <https://www.docker.com/products/docker-desktop/>
- Linux: install Docker Engine + the Compose plugin from your distro.

That's the only thing you install by hand. Everything else is automatic.

### 2. Get these files

Download this project — either click **Code → Download ZIP** on GitHub and
unzip it, or if you have `git`:

```bash
git clone <your-repo-url> ham-shack
cd ham-shack
```

### 3. Set your passwords

Copy the example settings file to `.env` and open it in any text editor to
change the two passwords (the desktop login and the account password):

```bash
# Windows (PowerShell):
Copy-Item .env.example .env
# macOS / Linux:
cp .env.example .env
```

The defaults work, but they're `changeme` — set your own. `.env` stays on your
computer and is never shared.

### 4. Build and start it

From the project folder, run:

```bash
docker compose up -d --build
```

**The first time takes about 20–30 minutes** — it's downloading and setting up
all the software for you. Leave it running; you only wait once. (After that,
starting it again is instant.)

Want to watch progress? `docker compose logs -f` (press Ctrl+C to stop
watching — it keeps running).

### 5. Open the desktop

Go to **<http://localhost:6080/vnc.html>** in your browser, click **Connect**,
and enter the **VNC password** from your `.env`. You're now looking at the
desktop.

### 6. Launch an app

Click **Applications → Ham Radio** (top-left), and pick **Winlink Express**,
**VARA FM**, or **VARA HF** — or use the desktop icons.

**That's it.** You have a working ham-radio workstation.

---

## First thing to try (no radio needed)

Prove the whole thing works without any hardware:

1. Open **Winlink Express**. On first run it asks for your callsign and settings
   (you can put a test callsign to look around).
2. Start a **Telnet Winlink** session — this sends real Winlink email over the
   internet, no radio required. It's the fastest way to confirm everything is
   wired up.

When you're ready for over-the-air operation, connect a radio (below).

---

## Connecting a radio

Radios plug in over **USB**. There are two things a radio provides — **control**
(set frequency / key the transmitter) and **audio** (the sound the modem makes)
— and getting them into the container takes one setup step.

### Make the USB device visible

**On Windows/macOS, Docker can't see USB directly.** On Windows, share the
device into Docker's Linux VM with the free tool
[usbipd-win](https://github.com/dorssel/usbipd-win), from an admin PowerShell:

```powershell
usbipd list                         # find your radio's BUSID
usbipd bind  --busid <ID>           # once per device
usbipd attach --wsl --busid <ID>    # attach it (repeat after unplugging)
```

**On Linux**, the radio is already available — skip that step.

Then open `docker-compose.yml`, un-comment the matching line under `devices:`
(there are comments telling you which is which), and run `docker compose up -d`.

### Hook it up inside the desktop

In the desktop, run **Ham Radio → Connect USB Radio** (or type `radio-connect`
in a terminal). It finds the radio and assigns it a **COM port** — then in
Winlink Express / VARA you just pick that COM port.

### Radio notes

| Kind of radio | Example | How it gets on Winlink |
| --- | --- | --- |
| Built-in USB sound card + control | Icom IC-705 / IC-7100 | VARA HF/FM over USB (control + audio in one cable) |
| Built-in packet TNC | Kenwood TH-D75, Yaesu FT-5D | Packet Winlink over USB — no sound card needed |
| Data port + external interface | mobiles, HTs | Dire Wolf (software TNC) + a SignaLink/DigiRig sound interface |
| Programming only | Baofeng UV-5R | Program it in CHIRP over its USB cable |

> **Sound on Docker Desktop is the tricky part.** Getting a radio's USB audio
> into the container is straightforward on a **Linux** host but advanced on
> Windows/macOS — see [Sound](#sound) and the notes in `docker-compose.yml`.
> Packet radios (built-in TNC) and telnet Winlink don't need any of this.

---

## Sound

By default the container sends audio to a PulseAudio server on your computer.

- **Windows/macOS (Docker Desktop):** if you don't set anything up, the apps run
  **silently** — that's fine for telnet Winlink, packet, and just exploring.
  For speaker sound you can run a PulseAudio server on the host; see the
  comments in `docker-compose.yml`.
- **Linux:** share your PulseAudio/PipeWire socket (there's a commented block in
  `docker-compose.yml` and a `PULSE_SERVER` line in `.env`).

The desktop includes **PulseAudio Volume Control** (`pavucontrol`) for routing.

---

## Offline references

Built into the image and reachable from **Ham Radio → Ham Radio References** (or
the `~/References` folder) — handy when you're off-grid:

- **FCC Part 97** — the complete amateur rules (official public-domain PDF).
- **US Band Privileges** — a quick chart of who can transmit where, by license
  class.
- **MCARES frequency & programming templates** — reference sheets plus CHIRP
  files (Portland, OR area — swap in your own).

---

## Everyday commands

Run these from the project folder:

```bash
docker compose up -d          # start it
docker compose stop           # stop it (keeps everything)
docker compose logs -f        # watch what it's doing
docker compose up -d --build  # rebuild after changing something
docker compose down           # stop and remove the container (your data is kept)
```

Your Winlink messages, VARA registration, and settings live in a Docker volume
and **survive stops, restarts, and rebuilds**.

---

## Settings (`.env`)

| Setting | What it does | Default |
| --- | --- | --- |
| `USER_PASSWORD` | Account password (also SSH + `sudo`) | `changeme` |
| `VNC_PASSWORD` | Desktop login password | `changeme` |
| `VNC_GEOMETRY` | Desktop resolution | `1280x800` |
| `VNC_PORT` / `NOVNC_PORT` / `SSH_PORT` | Host ports | `5900` / `6080` / `2424` |
| `SSH_PUBKEY` | Optional SSH key (instead of a password) | empty |
| `PULSE_SERVER` | Where audio goes | host default |
| `HAM_USER` | Login name inside the container | `ham` |

Change these before or after building — port and password changes just need a
`docker compose up -d`.

---

## Troubleshooting

- **The web page won't load / "connection refused":** the container is still
  building or starting. Check `docker compose ps` and `docker compose logs -f`.
  The first build takes 20–30 minutes.
- **"Port is already in use":** something else uses 5900/6080/2424 — change
  `VNC_PORT` / `NOVNC_PORT` / `SSH_PORT` in `.env` and `docker compose up -d`.
- **SSH says the host key changed** (after a rebuild): clear the old key —
  `ssh-keygen -R "[localhost]:2424"`.
- **Windows build error mentioning `\r` or "bad interpreter":** the files were
  saved with Windows line endings. This repo's `.gitattributes` prevents it; if
  it still happens, re-clone rather than copy-pasting the files.
- **Want a clean slate:** `docker compose down -v` wipes the saved data and
  resets to a fresh install (the apps re-appear automatically).

---

## About the bundled software

This project **does not redistribute** Winlink Express or VARA — the image
downloads them from their official sites when *you* build it.

- **Winlink Express** — free for licensed amateur radio operators (winlink.org).
- **VARA FM / VARA HF** — third-party shareware by EA5HVK; unregistered it runs
  speed-limited. Buy a key from the author to unlock full speed
  (rosmodem.wordpress.com).
- **Dire Wolf, CHIRP, hamlib** and the rest are open-source.

You are responsible for holding the appropriate license to transmit and for
complying with your local regulations.

---

*73!* Built on Arch Linux + XFCE + Wine. Runs on Windows, macOS, and Linux with
Docker.
