# Changelog

All notable changes to this project are documented here.

## [v1.0.0] — First public release

The first release of CRCW Biome Hopper. Everything below is new.

### Added

- **OCR-based biome detection** — reads Roblox chat via Descolada's OCR
  library and matches biome announcements against a configurable list.
- **Auto-hop / camp-on-good** — automatically rejoins the private server
  when a bad biome appears; stays and pings when a good biome appears.
- **Discord notifications** — biome arrival, boss spawn, ore spawn,
  error alerts, and watchdog softlock alerts. Optional secondary webhook
  for a community Discord.
- **Priority boss override** — bosses flagged `priority` (e.g. Orenga)
  pause the script and fire a Discord ping immediately, cancelling any
  pending rejoin.
- **Boss-bar OCR fallback** — catches bosses not announced in chat.
- **Multi-boss per biome** with `autoAttack`, `attackSequence`, and
  `leave` flags per boss.
- **Fast rejoin** via URL navigation (`Run(link)` + Ctrl+R of an existing
  Roblox tab), with fallback to click-Join.
- **Ore spawn pings** — selectable per ore via **Tools → Select Ores**.
- **Alt Joiner** — quick account-switching tool for multi-boxing.
- **Biome Luck Calculator** — quick 1/N → adjusted-odds helper.
- **GUI:** dark main window, biome selector, ore selector, Discord
  config window, attack sequence editor, event simulator.
- **Global hotkeys** — F6/F7/F8/F9/F10, plus Ctrl+Shift+1..4 for multi-RDP.
- **Watchdog timer** — Discord alert if the script stays in a status too
  long (3 min for rejoin states, 15 min otherwise).

### Known issues

- The Roblox error-screen check (`CheckRobloxErrorScreen`) is **disabled**
  in this release. Its OCR regions false-positive on freshly-joined
  servers, causing an instant rejoin loop before chat is ever scanned.
  A fix is planned for v1.1.
- Multi-RDP setups are capped around 5–6 Roblox instances on a 16 GB host.
  Use Bubblestrap or similar memory trimming, minimize background windows,
  and consider excluding the Roblox folder from Defender scanning.
- Player-count monitoring is not implemented. If a friend joins your
  private server, you lose the biome — there's no detection for that yet.

### Notes

- Config is stored in `biome_hopper_config.ini` (gitignored, per-account).
- OCR regions, join coordinates, and Play button position must be
  captured per machine. See `docs/first-run.md`.
