# Troubleshooting

Common problems and how to fix them.

---

## Script won't start / closes immediately

**Symptom:** Double-clicking the `.ahk` file opens a window that
immediately closes, or you see a syntax error.

**Causes:**
1. **AutoHotkey v1 is installed instead of v2** — Uninstall v1, install
   v2 from https://www.autohotkey.com/v2/
2. **You're running from inside a zip file** — Extract first. Windows
   can't find the `Lib/OCR.ahk` dependency if you don't.
3. **`Lib\OCR.ahk` is missing** — Re-download the release, extract
   fresh. Don't move files around manually.

---

## Play button doesn't click

**Symptom:** Roblox launches, you see the title screen, but the script
doesn't click PLAY. You have to click it manually.

**Cause 1 — Coords wrong for this PC/RDP.** Every Windows user account
has its own screen coordinates. If you set this up on your main PC but
are running on an RDP, the coordinates don't carry over.

**Fix:** Open the script on that RDP, launch Roblox, get to the title
screen, then run **Tools → Capture Play Button** and click PLAY.

**Cause 2 — Different resolution or DPI scaling.** If your RDP uses a
different screen resolution or Windows scaling (100% vs 125%), the
capture needs to be redone on that session.

**Fix:** Recapture. The coordinates are saved per-user, so you only need
to do it once per RDP.

---

## "Join Error 524" or similar

**Symptom:** Roblox shows a big error box saying you don't have
permission to join, or "server became unavailable".

**Cause:** Your private server code has changed or expired. Roblox
regenerates the code when:
- The owner (you) leaves and rejoins the private server
- The server is deleted from your account
- Roblox updates their sharing system

**Fix:**
1. In Roblox, open your private server
2. Click **Share** → copy the new link
3. In the script: **Tools → Discord Notifications...** → paste the
   new link → SAVE & CLOSE
4. Press **F9** to restart

If it keeps happening, your private server might be getting reset by
Roblox every session. Consider a permanent private server (paid feature)
or a different sharing approach.

---

## Biome not detected even though it's clearly in chat

**Symptom:** A rare biome appears in chat, but the script doesn't react.

**Cause 1 — Biome marked BAD or IGNORED.** Open
**Tools → Select Biomes / Bosses...** and check the biome's status.
Make sure it's **GOOD**.

**Cause 2 — Chat region not calibrated.** The script's OCR is looking
at the wrong part of the screen.

**Fix:** **Tools → Calibrate OCR Region**. Drag a box around just the
chat text area (top-left of the Roblox window). Release.

**Cause 3 — Chat is hidden.** Some Roblox UI settings hide the chat by
default.

**Fix:** In Roblox settings, enable the chat window. The script can't
read text that isn't rendered.

**Cause 4 — Font changed.** Custom Roblox fonts break OCR.

**Fix:** Restore default Roblox fonts (Settings → Chat → Font).

---

## Discord pings not arriving

**Symptom:** Biomes appear, the script says it's pinging, but nothing
shows up in Discord.

**Cause 1 — Webhook URL wrong.** The URL must be a webhook URL, not a
channel URL or invite link. It should look like:
`https://discord.com/api/webhooks/123456789/abcdef...`

**Fix:** **Tools → Discord Notifications** → **SEND TEST PING**. If it
fails, re-copy the webhook URL from Discord.

**Cause 2 — Role mention not working.** If you set a role ID, it must be
the numeric ID (e.g. `1234567890123456789`), not the role name.

**Fix:** Enable Developer Mode in Discord (User Settings → Advanced),
right-click the role → Copy Role ID.

**Cause 3 — Webhook deleted.** If someone on the Discord server deleted
the webhook, the URL stops working.

**Fix:** Create a new webhook and paste the new URL.

---

## Script gets stuck on "REJOINING" or "LAUNCHING ROBLOX"

**Symptom:** Status shows REJOINING or LAUNCHING ROBLOX and never
changes.

**Cause:** Roblox is taking longer than expected to launch, or an
unexpected error dialog is blocking it.

**Fix:**
1. Wait up to 3 minutes — the script retries automatically
2. If still stuck, press **Ctrl+Alt+R** to Force Resume
3. If that doesn't work, press **F7** to stop, then **F9** to restart

The script will also send you a Discord alert if it detects it's been
stuck for too long.

---

## Anti-AFK not working / Roblox kicks you

**Symptom:** You get disconnected for inactivity after 20 minutes.

**Cause:** Anti-AFK is disabled, or the anti-AFK key (`Shift`) doesn't
register.

**Fix:**
1. Check `AntiAfkEnabled` is `true` in the script globals
2. The script sends `Shift` every 45 seconds — this resets the idle timer
   in most Roblox games
3. Some games use custom idle detection — in that case the script can't
   help and you'll need to check in periodically

---

## Auto-attack doesn't fire (NOTE THIS IS A WORK IN PROGRESS, CURRENTLY BUGGY)

**Symptom:** A boss spawns in a biome marked `autoAttack: true`, but the
script doesn't attack.

**Cause 1 — Attack hold point not captured.** The script needs a "safe
click point" it can use to swing.

**Fix:** **Tools → Capture Attack Hold Point** → click a spot in the
game world where clicking does nothing harmful.

**Cause 2 — Attack sequence not defined.**

**Fix:** **Tools → Edit Attack Sequences** and check that the sequence
name matches what the biome uses (e.g. `autoswing`).

**Cause 3 — Chat focus interfering.**

**Fix:** This shouldn't happen anymore, but if it does, close the chat
window manually and press **Ctrl+Shift+A** to restart auto-attack.

---

## Multiple RDPs — one works, others don't

**Cause:** Each RDP/Windows user account needs its own captured
coordinates. What works on one won't work on another.

**Fix:** On each RDP:
1. Launch the script as that user
2. Run every **Tools → Capture** step once
3. Run **Tools → Calibrate OCR Region** once
4. Save the private server link once

After that, each RDP runs independently.

---

## "This experience has ended or the server became unavailable"

**Cause:** The Roblox server actually crashed or was shut down.

**Fix:** The script detects this automatically and retries up to 3
times. If the server is genuinely dead, you'll need to start a new one
and update the private server link in the script.

---

## Script eats too much CPU / RAM

**Cause:** Running many Roblox instances without optimization.

**Fixes:**
1. **Minimize every Roblox window** you're not actively looking at —
   Roblox stops rendering when minimized
2. Use **Bubblestrap** instead of the default Roblox launcher (or really any other optimized/customizable bootstrapper tbh) — it has
   built-in memory trimming
3. Set **graphics quality to 1** in Roblox settings
4. Cap FPS at 20-30 for alt accounts
5. Close Firefox, Discord, and other heavy apps on the same PC

See the README for more multi-boxing tips.

---

## Still stuck?

1. Take a screenshot of the script GUI (especially the **LAST OCR RESULT** box)
2. Open **Help → About** to confirm the version
3. Post on the GitHub **Issues** tab with the screenshot and what you
   were doing OR DM me on Discord @Jaisuhn