# Sound

The container sends audio to a PulseAudio server on your computer (set by
`PULSE_SERVER` in `.env`). **Nothing breaks if audio isn't set up** — the apps
just run silently, which is fine for telnet Winlink, packet, and exploring.

## Windows / macOS (Docker Desktop)

Silent by default. For speaker sound, run a PulseAudio server on the host and
leave `PULSE_SERVER` at its default (`tcp:host.docker.internal:4713`). Search
"PulseAudio for Windows" (e.g. the pgaskin build) for a server; enable its TCP
module and allow it through the firewall.

## Linux host

Share your host audio socket. In `.env`:

```dotenv
PULSE_SERVER=unix:/run/user/1000/pulse/native   # 1000 = your UID (`id -u`)
```

and un-comment the "Linux native audio" bind mount in `docker-compose.yml`, then
`docker compose up -d`.

## Inside the desktop

**PulseAudio Volume Control** (`pavucontrol`) is installed for routing and
levels. `pactl info` confirms whether the container reached an audio server.

> **VARA is timing-sensitive.** A network audio bridge works for testing but a
> local/low-latency path (Linux socket, or the radio's own USB codec) is best
> for real operation.
