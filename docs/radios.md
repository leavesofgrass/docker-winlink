# Connecting a radio

A radio provides two things over USB: **control** (set frequency / key the
transmitter) and **audio** (the modem sound). Getting them into the container
takes one setup step.

## 1. Make the USB device visible

**Docker Desktop (Windows / macOS)** can't see USB directly. On Windows, share
the device into Docker's Linux VM with [usbipd-win](https://github.com/dorssel/usbipd-win),
from an **admin PowerShell**:

```powershell
usbipd list                      # find the radio's BUSID
usbipd bind  --busid <ID>        # once per device
usbipd attach --wsl --busid <ID> # attach (repeat after each replug)
```

**Linux host:** the device is already local — skip this step.

Then in `docker-compose.yml`, un-comment the matching line under `devices:`
(`ttyUSB0` for USB-serial cables, `ttyACM0` for native-USB radios; add
`/dev/snd` for a radio's built-in sound card) and run `docker compose up -d`.

## 2. Map it inside the desktop

Run **Ham Radio → Connect USB Radio** (or `radio-connect` in a terminal). It
fixes permissions and assigns the radio a **COM port**, e.g. `COM1 -> /dev/ttyACM0`.
In Winlink Express / VARA, pick that COM port. It also runs at container start;
re-run it after attaching a radio.

## What each radio needs

| Radio type | Example | Path onto Winlink |
| --- | --- | --- |
| Built-in USB sound card + control | Icom IC-705 / IC-7100 | VARA HF/FM over USB (control + audio in one cable) |
| Built-in packet TNC | Kenwood TH-D75, Yaesu FT-5D | Packet Winlink over USB — no sound card |
| Data port + external interface | mobiles, HTs | Dire Wolf (software TNC) + a SignaLink/DigiRig |
| Programming only | Baofeng UV-5R | CHIRP over the USB cable |

> **Audio caveat:** routing a radio's USB sound card into the container is easy
> on **Linux** (`/dev/snd`), but advanced on Docker Desktop — see
> [audio.md](audio.md). Packet (built-in TNC) and telnet Winlink need no audio.

## Permissions

`radio-connect` puts the serial device in the `uucp` group (which the desktop
user is in). If a device still isn't accessible, add its host group id to
`group_add:` in `docker-compose.yml` (find it with `ls -l /dev/ttyUSB0`), or
run `sudo /usr/local/bin/radio-perms`.
