# Changelog

All notable changes to this project are documented here.

## [v1.1.0] — Performance & Stability Update

This update completely refactors the core macro loop for maximum speed and reliability on multi-RDP setups, and introduces new standalone tools.

### Added
- **RDP Manager:** Included a new standalone script (`rdp_manager.ahk`) to automatically tile and organize RDP windows across multiple monitors.
- **AFK Farm Button:** You can now start/stop auto-attacking independently of biome hopping for pure AFK farming.
- **Auto-Attack Selector:** Added a new menu option (`Tools -> Select Auto-Attack Biomes`) so you can choose exactly which biomes trigger auto-attack.
- **Halloween Biomes:** Added detection for the new Halloween and Hallowed event biomes (for y'all to farm and also 'cuz I keep getting it when I don't need it anymore LOL)

### Changed
- **Faster Startup:** Removed pixel-detecting the Play button in favor of fast keyboard navigation.
- **Faster Rejoin:** Removed URL-rejoin fallback; now relies purely on the browser/RAM window for consistent hops.
- **Double-Confirm:** Requires 2 consecutive OCR hits of a BAD biome before hopping, preventing false-positives.
- **Compact GUI:** Restored the small main window and moved Discord Config back to `Tools -> Discord Notifications`.
- **Error Checking:** Fixed the lag bug by throttling the Roblox error check to run every 3 seconds instead of 16 times a second.
- **Chat Focus Fix:** Auto-attack now safely pauses for a split second to refresh the chat window, preventing OCR blindness and softlocks.

### Removed
- **Orenga Priority Override:** Temporarily removed to streamline the main loop.
- **Ore Spawn Pings:** Temporarily removed.

## [v1.0.0] — First public release

The first release of CRCW Biome Hopper. Everything below is new.

### Added
- **OCR-based biome detection** — reads Roblox chat via Descolada's OCR library and matches biome announcements against a configurable list.
- **Auto-hop / camp-on-good** — rejoins the private server when a bad biome appears; stays and pings when a good biome appears.
- **Discord notifications** — biome arrival, boss spawn, error alerts, and watchdog softlock alerts.
- **Boss-bar OCR fallback** — catches bosses not announced in chat.
- **Global hotkeys** — F6/F7/F8/F9/F10.
- **Watchdog timer** — Discord alert if the script stays in a status too long.