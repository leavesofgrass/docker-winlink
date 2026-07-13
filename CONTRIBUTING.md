# Contributing

Thanks for helping make Docker WinLink better! This started as a way to make
Winlink and VARA easy to run anywhere, and it gets more useful every time
someone tests it with a new radio, host, or setup. Contributions of all kinds
are welcome — code, docs, or just a good bug report.

## Ways to help

- **Report what worked (or didn't).** Especially: your **host OS**, your
  **radio model**, and how you connected it. Radio compatibility notes are
  gold — they help the next person.
- **Improve radio support.** Better USB/CAT/audio handling, notes for specific
  rigs, or fixes for the `radio-connect` / device passthrough flow.
- **Docker Desktop audio.** Getting a radio's USB sound card into the container
  on Windows/macOS is the biggest rough edge — real solutions very welcome.
- **Docs.** Corrections, clearer wording, and screenshots. Keep docs concise
  (see the short files in [`docs/`](docs/)).
- **Slim the build.** Faster builds or a smaller image without losing function.

## Reporting a bug or asking for a radio

Open an [issue](../../issues) and include:

- Host OS and Docker version (`docker version`)
- What you did and what happened (paste relevant `docker compose logs` output)
- For radios: model, how it's connected, and the output of `radio-connect`

## Making a change

1. **Fork** the repo and create a branch: `git checkout -b my-fix`.
2. Make your change. If it touches the build, rebuild and confirm it still
   comes up: `docker compose up -d --build`, then open the desktop.
3. Keep it cross-platform — this runs on Windows, macOS, and Linux. Shell
   scripts and the `Dockerfile` **must stay LF** (the repo's `.gitattributes`
   enforces this; don't commit CRLF).
4. **Open a pull request** describing what changed and how you tested it.

Small, focused PRs are easiest to review. If you're planning something big,
open an issue first so we can talk it through.

## Style

- Match the existing style; comment the *why*, not the obvious.
- Prefer prebuilt packages over source compiles to keep builds fast.
- Don't commit secrets, installer binaries, or personal config — `.gitignore`
  already blocks `.env`, `*.zip`, and friends. Double-check `git status` before
  committing.

## License

By contributing, you agree that your contributions are licensed under the
project's **GPL-2.0** license (see [LICENSE](LICENSE)).

## Be kind

This is a hobby project in the spirit of amateur radio — helpful, patient, and
welcoming to newcomers. 73! 📻
