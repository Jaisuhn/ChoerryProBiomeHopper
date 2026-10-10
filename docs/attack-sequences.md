# Attack Sequences (THIS ENTIRE FUNCTION IS A WORK IN PROGRESS SO EXCEPT BUGS!!!)


Attack sequences let the script auto-attack while camping a biome. They
are optional — you only need this if you want the script to farm kills
while it waits.

---

## What it's for

Some biomes are GOOD because you want to camp them until a specific
boss spawns (e.g. Hydra, where you're waiting for The Old Dragon). While
you're camping, you might as well be attacking any enemies that appear.

An **attack sequence** is a list of commands the script runs on repeat
whenever it's camping a biome that has `autoAttack: true`.

---

## Opening the editor

**Tools → Edit Attack Sequences...**

The editor is a plain text box. You edit the file directly, then click
**SAVE** to apply the changes.

---

## File structure

The file is divided into **sections**. Each section is one named
sequence:

```
[default]
click 961 713
sleep 800

[hydra]
equip 5
click 961 713
sleep 700
send q
sleep 300
send z
sleep 300
```

- `[name]` starts a new sequence
- Everything below it belongs to that sequence until the next `[name]`
- Lines starting with `;` or `#` are comments (ignored)
- Blank lines are ignored

---

## Commands

| Command | What it does |
|---|---|
| `click X Y` | Move the mouse to (X,Y) and left-click once |
| `hold X Y` | Move to (X,Y) and press-and-hold left mouse button |
| `release` | Release the left mouse button |
| `move X Y` | Move the mouse to (X,Y) without clicking |
| `send KEY` | Press a keyboard key (e.g. `send q`, `send {Enter}`) |
| `equip N` | Press the number key N (usually equips weapon slot N) |
| `sleep MS` | Wait MS milliseconds before the next command |
| `wait MS` | Same as `sleep` |

### About `hold` and `release`

For weapons that auto-swing when you hold the mouse button:

```
hold 961 713
sleep 700
move 250 250
release
sleep 100
```

This:
1. Moves to the attack point and holds the mouse down
2. Waits 700ms (swing happens)
3. Moves the cursor to (250,250) while still holding
4. Releases the button

Why move before releasing? Because the cursor moving over the chat
area makes the chat visible to OCR, but the attack continues until
the button is released. So you get both: attack + chat readable.

---

## Assigning a sequence to a biome

In `ChoerryProBiomeHopper.ahk`, find the biome definition (search for
the biome's `id:`). Add `attackSequence: "name"`:

```ahk
{ id: "hydra", keywords: ["hydra has come"], biomeName: "Hydra has come to the overworld!",
  roleID: "1544373201893851168", defaultGood: true,
  autoAttack: true, attackSequence: "hydra",
  bosses: [ ... ] },
```

If a biome has `autoAttack: true` but no `attackSequence`, the
`[default]` sequence is used.

---

## Getting coordinates

Open Roblox. Hover over the spot you want to click or hold. Read the
coordinates from any screen coordinate tool, or just click the point
and read it out of the script after capturing an attack hold point.

Common spots:
- **Attack point** — a safe spot in the game world, e.g. in front of
  your character
- **Chat area** — around (200, 200), near the top-left
- **Your weapon slot** — key `5`, `6`, `7`, etc.

---

## Example: autoswing with abilities

For a weapon that auto-swings while held, plus Q/Z/X abilities:

```
[hydra]
hold 961 713
sleep 400
send q
sleep 200
send z
sleep 200
send x
sleep 200
move 250 250
release
sleep 100
```

Loops: hold → fire abilities → move to chat → release → repeat.

---

## Example: click-swing (no autoswing)

For a weapon that swings once per click:

```
[default]
click 961 713
sleep 800
```

Just click, wait, click, wait. Simple and reliable.

---

## Testing

In the editor, click **TEST ACTIVE SEQ** to run the current sequence
once. Watch Roblox — the character should perform the actions.

Click **STOP TEST** to stop. Or press **F7** (Stop).

---

## Common problems

**Auto-attack fires but doesn't hit anything** — Your attack point
might be pointing at a UI element or moving your character. Recapture
with **Tools → Capture Attack Hold Point**.

**Abilities don't fire** — Roblox requires keyboard focus on the game
window. If chat input is open, keys go to chat instead of the game.
The script presses Escape before starting, but check manually if it's
still happening.

**Sequence runs too fast / too slow** — Adjust `sleep` values. 800ms
between clicks is a good starting point. Most abilities have a 300ms
cooldown window.

**The `send` command types into chat** — Make sure the chat input isn't
open. The script tries to close it automatically, but if it's still
failing, capture a safe click point outside the chat and call `click`
on it before the `send` commands.