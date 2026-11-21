# VOLT/RUN

Kite, a little courier robot, runs from Greece through Bulgaria to Romania to see Lumi again.
Precision auto-runner with a cinematic, glowing 2D look. Godot 4.7.2, all art and audio generated in code.

## Download and play
Get the latest build from **[Releases](../../releases/latest)**:
| Platform | File | How to run |
|---|---|---|
| Android (64-bit phones) | `VOLT-RUN-android.apk` | Copy it to the phone, open it, allow "install unknown apps". Play in landscape. |
| Windows 10/11 (64-bit) | `VOLT-RUN-windows.exe` | Double-click it. SmartScreen may warn because the exe isn't signed: choose *More info → Run anyway*. |
| Linux (x86_64) | `VOLT-RUN-linux.x86_64` | `chmod +x VOLT-RUN-linux.x86_64 && ./VOLT-RUN-linux.x86_64` |

## Play from source
```bash
../../tools/bin/path/godot --path .
```
| Action | Keyboard | Gamepad | Touch (Rocker + Action) |
|---|---|---|---|
| Hop (hold = higher; keep holding in the air = Hover) | Up / W / Space | A | left thumb, upper half |
| Scoot (hold) · Dive (in the air) · Dive into a slide = Swoop | Down / S | B | left thumb, lower half |
| Gust (short-range wind: gates) | X / J | X | right thumb, big button |
| Letter (paper plane: bells and bridges, max 3) | C / K | Y | right thumb, small button |
| Pause | Esc | Start | top-right button |

## What is in this build (v0.2.0)
- **Story, "Find Lumi":** 4 chapters (Kalymera Bay, Rhodope Lanterns, Danube Mirror, Carpathian Aurora). First-time hints, chapter cards, Scenic/Wild junctions (Wild is shorter and harder), one scripted hover-biker rescue, and the Lumi finale.
- **Endless Road** and **Daily Relay** (date-seeded). Speed and difficulty ramp per segment, biomes cycle, Wild route scores ×1.5. Local bests.
- **Tailwind** ×1–×4 (3/8/15 perfects; a mistake drops one tier). In-key notes, glowing thrusters, trail, slow-mo on tier-up.
- **Recovery breaks** (12 s story, 8 s endless, skippable): strangers' kindness, messages from Lumi, photos and the map.
- **Rescues:** 4 hover-biker strangers (Marek, Nana Vira, Zip, Bogdan & Sharo). They never count as a failure.
- **Fairness:** each generated segment is replayed by a solver bot on the real simulation. Anything it cannot clear is moved or removed.
- **Accessibility:** Kind Mode (no fails), hover assist, relaxed speed, reduced motion, shake toggle, left-handed layout, button size.
- **Garage:** scarf colours bought with Sparks (earned from stamps or Tailwind ×4).
- **Rewarded ad slot (stub):** title screen only, max 3/day, never in gameplay, story or after a failure. **No ad SDK is integrated.** See `scripts/ads.gd` for the legal checklist.

## Develop
```bash
tools/test.sh                 # headless tests, isolated user dir (refuses otherwise)
tools/capture.sh /tmp/shots   # autopilot capture of 18 story/endless beats (Xvfb, isolated user dir)
```
Code map: `sim.gd` deterministic 120 Hz physics and verbs · `track.gd` generator, solver bot, validation · `main.gd` flow, camera, HUD, capture director · `world_view.gd` sky and parallax biomes · `track_view.gd` ground and obstacles · `kite_view.gd` / `chars.gd` characters · `synth.gd` procedural audio · `ui.gd` menus · `touch.gd` controls · `ads.gd` ad stub.

## Not done yet
Android export/APK and on-phone control testing, GPU performance profiling, a real ad SDK (blocked on the legal review), save cloud sync, more biomes and set pieces, voice and SFX polish, a scrapbook screen.
