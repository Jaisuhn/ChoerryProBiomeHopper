# First-Time Setup

This guide takes you from "I just downloaded this" to "the script is
hopping biomes". Takes about 10 minutes.

If you get stuck at any step, see [troubleshooting.md](troubleshooting.md).

---

## Step 1 — Install AutoHotkey v2

1. Go to https://www.autohotkey.com/v2/
2. Click **Download**
3. Run the installer
4. Pick **v2** during install (not v1)

To check it worked: right-click any `.ahk` file on your computer, and
you should see an option like **Run Script**. If you don't, reinstall.

---

## Step 2 — Extract the script folder

Do **not** run the script from inside the zip file. Windows opens zips
in a temporary folder that gets deleted, and the script won't find its
support files.

1. Right-click the downloaded zip
2. Click **Extract All...**
3. Choose a permanent folder (e.g. `C:\CRCW Hopper\`)
4. Click Extract

You should now have a folder containing:
- `ChoerryProBiomeHopper.ahk` (the main script)
- `Lib/OCR.ahk` (the OCR library)
- `attack_sequences.txt` (auto-attack definitions)
- `README.md` (documentation)

---

## Step 3 — First launch

Double-click `ChoerryProBiomeHopper.ahk`.

If Windows asks for permission, click **Yes**.

The GUI opens. You'll see:
- **CURRENT STATUS** — shows `IDLE` for now
- **BIOME HOPPING** — the buttons you'll use
- **LAST OCR RESULT** — shows what the script is reading from chat

Nothing should be happening at this point. Continue to the next step.

---

## Step 4 — Paste your private server link

You need the **share link** for the private server you want to hop on.

1. In your browser, open Roblox (or use the Roblox app)
2. Go to your private server for CRCW
3. Click **Share** (or the ⋯ menu)
4. Copy the link — it looks like `https://www.roblox.com/share?code=xxxxx&type=Server`

In the script:
1. Click **Tools → Discord Notifications...**
2. Paste the link into **Private Server Link**
3. Click **SAVE & CLOSE**

---

## Step 5 — Set up Discord notifications (optional but recommended)

If you want pings when biomes appear:

1. In Discord, open the server you want pings in (usually YOUR own server since you have admin permissions for webhooks)
2. Right-click the channel → **Edit Channel** → **Integrations** → **Webhooks** → **New Webhook**
3. Name it (e.g. "Biome Hopper"), pick a channel, copy the URL
4. In the script: **Tools → Discord Notifications...**
5. Paste the URL into **Webhook URL**
6. Click **SEND TEST PING** to confirm it works

If you want a specific role mentioned (e.g. `@Old Dragon`):
1. In Discord, right-click the role → **Copy Role ID** (needs Developer
   Mode enabled in your Discord settings)
2. Paste the role ID into the bot's **Role ID to ping** field

---

## Step 6 — Capture your coordinates (the important part)

The script needs to know where things are on your screen. This is
per-account, so you'll do this once for each PC/RDP you use.

**Do these in order, with Roblox open in the background.**

> ⚠️ **Every capture below is per-account.** If you run this on your main PC
> and three RDPs, you need to repeat Step 6 on each machine (or copy
> `biome_hopper_config.ini` after capturing on one, if the screens are
> identical). Same for Step 4 — each account has its own private server link.

### 6a. Capture Join Window

1. In Roblox Account Manager (or your browser), open the private server
   join page
2. In the script: **Tools → Capture Join Window**
3. A message box appears — click **OK**
4. Switch to your browser/RAM window (the one with the Join page)
5. The script captures the active window automatically

You should see confirmation in the **LAST OCR RESULT** box.

### 6b. Capture Join Click

1. Still in your browser/RAM, hover over the **Join** button
2. In the script: **Tools → Capture Join Click**
3. Click **OK** on the message box
4. **Click once on the Join button** in your browser
5. The script captures that click position

### 6c. Capture Safe Click (optional)

This is used to dismiss the "Roblox is loading" overlay in the browser
before the Join button is clicked. Only set it if you actually see that
overlay.

1. **Tools → Capture Safe Click**
2. Click **OK**
3. Click somewhere on the Roblox page that does nothing (not a button,
   not a link)
4. The script captures it

If you skip this, the script just doesn't perform the safe click. That's
fine for most setups.

### 6d. Capture Play Button

This one runs inside Roblox, on the title screen.

1. Launch Roblox, get to the title screen (the one with the **PLAY**
   button and the CLASSIC RETRO CRAFTWARS logo)
2. **Tools → Capture Play Button**
3. Click **OK**
4. **Click once on the PLAY button** in Roblox

The script saves those coordinates.

---

## Step 7 — Choose your biomes

1. **Tools → Select Biomes / Bosses...**
2. Click a row to cycle between:
   - **GOOD** (camp on this biome — the script stays and pings you)
   - **BAD** (hop out of this biome — the script rejoins)
   - **IGNORED** (no reaction, keep hopping)
3. Select multiple rows by clicking and dragging, or holding Shift
4. Use the **Mark Selected GOOD/BAD/IGNORED** buttons for bulk changes
5. Close the window — changes save automatically

**Suggested starter config:**

- Rare biomes → **GOOD** (you want to be pinged, script stays)
- Ultra-rare biomes → **GOOD**
- Common biomes → **BAD** (script hops out immediately)
- The default state (`world has returned to normal`) → **GOOD**

The default state being GOOD is what makes the script sit on a fresh
server and watch for a boss spawn instead of immediately hopping again.

You can tweak this any time.

---

## Step 8 — Choose ores (optional)

1. **Tools → Select Ores to Notify...**
2. Click a row to toggle between NOTIFY and IGNORE
3. Close — changes save automatically

Now you'll get pinged whenever one of those ores spawns in the mines.

---

## Step 9 — Start hopping

1. Make sure Roblox is open and you're in the private server
2. Press **F9** (or click **TRUE BIOME HOP**)

The script will:
1. Look at the chat
2. If it sees a good biome → stay, ping Discord, watch for the boss
3. If it sees a bad biome → close Roblox, rejoin the private server,
   and check again
4. If a boss spawns and the biome is marked GOOD → send a boss ping
5. **Priority boss override** — if Orenga (or any boss flagged as `priority`)
   spawns, the script stops immediately, pauses hopping, and pings you on
   Discord. This fires even if the script was about to rejoin out of a bad
   biome, so you never lose the spawn to an auto-hop.

Watch the **LAST OCR RESULT** box to see what the script is reading.

---

## Step 10 — Stop or pause

- **F6** — Pause / Resume (keeps Roblox open, stops scanning)
- **F7** — Stop (stops scanning, leaves Roblox open)
- **F8** — Exit the script entirely

---

## Troubleshooting

If something doesn't work, the answer is usually one of these:

- **Private server link changed** — Regenerate the link from Roblox and
  paste it again
- **Play button missed** — Recapture **Tools → Capture Play Button**
- **Biome detection not firing** — Try **Tools → Calibrate OCR Region**
  and re-draw the chat area

Full list: [troubleshooting.md](troubleshooting.md)