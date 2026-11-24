# Changelog
## 0.8.23 (2026-11-24): the flicker found, a smoother intro on phones
- **Fixed the flicker** (the owner's phone recording): the front-row leaves blinked between solid and outline-only from frame to frame. Each leaf was one outline polygon; as it swayed, the pointed tip sometimes made a shape the engine couldn't triangulate, so the fill was silently skipped for that frame. Leaves are now built from triangles between their two edges, which can't fail. The same fix applies to the ground grass rows and the foreground grass clumps, which were long zigzag outlines.
- **Smoother intro on phones** (measured on the Honor Magic 7 Pro with the new debug-only `user://intro_timing.json`):
  - The game world was drawn behind the video the whole time, about 16 ms per frame on the phone, so the intro ran at roughly 10–15 fps. Now the world is drawn only during the warm-up steps and hidden until the video ends. Measured on the phone: about 34 → 51 fps after the warm-up.
  - The heavy warm-up now happens on a few black frames before the video starts, so the video begins smoothly. Text warm-up during playback is limited to 2.5 ms per frame. (This last step isn't measured on the phone yet; the USB connection kept dropping.)
- **Clean intro exit:** when the video ends it is swapped for the identical still frame, and the logo, glow and black edges fade out as one piece with a gentle shine-out (scale up 5%, glow swells and fades, 0.8 s). The video square used to fade out after the black edges.
- **Phone save history:** the phone's KAVI data folder dates from a fresh install at 20:35 on 2026-11-24, before any USB testing. Device installs are updates only (`adb install -r`), and benchmarks are save-isolated.
## 0.8.22 (2026-11-24): fixes, zero exit warnings, first real phone benchmark
- **Fixes:**
  - The Danube landmark bridge now has sloped approach embankments at both ends, running down into the hills; it used to end in mid-air.
  - Title: the paper-plane tip hides after the first delivery (it overlapped "Letters delivered"), and the quote sits lower with more space.
  - Balloons no longer pop into view: their look and presence are decided once per lap across the sky, and a lap only changes while they're off-screen. They used to switch every 72 s.
  - Plane smoke hearts are one clean line: smoke is laid every few pixels along the plane's path (it came from a point behind the tail and kinked at the sharp turns), and planes flying left draw the heart mirrored.
- **Intro:**
  - It always plays in full (no skip).
  - The game's sound is muted under the intro, then rises over 2.5 s with a soft curve.
  - Android Back does nothing during the intro or on the main title, so only Home or the swipe gesture leaves the game. It still steps back out of menus and pauses a run.
- **Zero warnings at exit.** Closing now stops the music, finishes background loads, releases the cursor images and shared statics, waits a few frames for the audio thread, then quits. The two intro images are saved as RGBA (no format-conversion warning). A verbose run reports no leaks, errors or warnings.
- **Device benchmark:**
  - Debug builds read benchmark arguments from `user://bench_request.txt`, pushed over USB, because Android launchers drop command-line arguments. The run is save-isolated: the player's save is never read or written.
  - New `tools/phone-bench.sh`. The benchmark now reports fps average, 1% and 0.1% lows, GPU time and the device name.
- **Honor Magic 7 Pro (Snapdragon 8 Elite, Adreno 830, screen capped at 60 Hz)** — evidence in `studio/docs/evidence/2026-11-24-phone-bench/`:

  | Setting | fps avg | 1% low | GPU ms | Draw-building ms |
  |---|---|---|---|---|
  | High | 42.7 | 38 | 3.9 | 16.4 |
  | Medium | 55.7 | 46 | 4.2 | 12.9 |
  | Low | 60.0 (cap) | 60 | 5.1 | 9.1 |
  | High, country change | 39.8 | 32.5 | 4.5 | 17.1 (max 24.4) |

  The phone is limited by the CPU rebuilding the drawings every frame, not by the GPU. Heaviest parts on High: near hills 4.0 ms, ground 2.7, foreground 2.0, far hills 1.9, Kavi 1.7. Next: cache the still scenery.
## 0.8.21 (2026-11-24): BADCOOL INTERACTIVE studio intro
- **Studio intro:** the game now opens on the owner's 5 s BADCOOL INTERACTIVE ident.
  - Converted to Ogg Theora, 1920x1080 at 60 fps (531 KB), and letterboxed to 16:9 on any screen.
  - It replaces the KAVI key-art loading screen.
  - The start is black throughout: Godot's boot splash is plain black and the web page is black, so it flows straight into the video.
- **Loading happens behind the video:** music on background threads, text sizes, each menu and gameplay screen, and all four countries.
  - When the video ends and the game is ready, the title fades in with the menu slide-in; a new player's tutorial starts instead.
  - If loading isn't finished, the last frame of the logo stays and breathes: a soft glow rises and falls over a 2.6 s cycle while the logo dims and brightens.
  - Below it, a slim silver-platinum bar with a moving sheen tracks real progress. It floats above the bottom edge.
- **Graphics picked during the intro:**
  - On first launch with Auto graphics, the frames drawn behind the video choose Low, Medium or High. GPU time is used where the platform reports it, otherwise frame time.
  - Only frames after the loading work count. Later launches use the level that auto-graphics learned in play.
- **Skip:** after the first full viewing, a tap, click or key skips the video (the game still waits until it's ready).
- The web loading bar is now slim silver on black, and the web page no longer shows a splash image.
- Measured: ready at about 5.1–5.2 s in the capture rig and in a real browser (the video length); the hold screen was tested with `--slow-load=9`. New capture flags: `--loading`, `--slow-load=N`.
## 0.8.20 (2026-11-24): the same look on phone and PC
- **Fixed: the game looked pale and washed out on Android** (owner's screen recording from an Honor Magic 7 Pro). HDR 2D renders differently on PC and Android: on PC colours came out darker and richer, the look the game was tuned with, while Android showed plain, pale colours. The 0.8.19 Kavi colour correction then double-brightened him on the phone.
- **HDR 2D is now off on every platform and quality level.** The moody look is applied on purpose by a colour-grade shader on the world layers (sky, hills, ground, obstacles, effects, foreground). Measured against the old PC look, the result is nearly identical.
  - Kavi, Lia, the HUD and the menus are not graded, so they show their true colours everywhere. Kavi's 0.8.19 colour-correction shader is gone.
  - A tiny dither stops dark sky gradients from banding.
  - Glow now blooms near-white lights (threshold 0.90).
  - 8-bit colour is also lighter work for phone GPUs than HDR.
- New key art and loading picture in the final look. Benchmarks are unchanged.
- Not verified on the phone yet: the owner tests first.
## 0.8.19 (2026-11-24): smooth on phones, prettier Low, cuter Kavi
Owner report from an Honor Magic 7 Pro: flicker, quality dropping from High to Medium or Low, a longer boot, and the menu lagging as it slid in.
- **Loading screen with warm-up** (replaces the 0.8.17 warm-up that ran during the menu slide-in):
  - The key art stays up with a progress bar while music loads on background threads. Each in-run text size is prepared within a time budget per frame.
  - Each menu and gameplay screen (route choice, pause, results, out of hearts, settings, Garage) and each country is drawn once behind it.
  - Then the title fades in and slides in smoothly; a new player's tutorial starts after it.
  - The glyph warm-up now covers only the 42 size/outline pairs the HUD really uses (0.8.17 did 216 combinations).
- **Auto graphics fixed:**
  - Every device now starts on High (phones started on Medium).
  - The median frame time is checked over 2 s windows, so one-off hitches no longer count. It needs two slow windows in a row to step down, and steps back up once per session when GPU time shows clear headroom.
  - Changes wait for a calm moment (title, breather, run start) instead of happening mid-run, and the level is remembered for the next launch.
- **Flicker:** HDR now stays on at every quality level. Auto-quality used to switch HDR off mid-run, which flashed the screen and shifted every colour.
- **Phones above 1080p:** Medium and Low draw at 1080p and scale up (about 30% fewer pixels); High stays at full resolution.
- **Low is pretty now:** same rich colours as High (it was pale because HDR was off), plus light rays, balloons, two-tone grass, flowers, foreground grass, soft light specks and Kavi's trail. Low still skips the glow post-process and some scenery density.
- **Kavi (and Lia) in true colours, with no black outlines:**
  - With HDR on, plain colours render darker and more saturated; the world keeps that moody look, while the characters are now re-encoded to their real bright colours (owner: the Low Kavi was cuter).
  - Kavi's shapes no longer get black outline strokes at any quality.
- New loading-screen key art in the new look. Draw timing in Painter only runs while benchmarking.
- Medium benchmark: 5.8 ms, 461 draws. Low: 4.4 ms, 314 draws.
- Not verified on a real phone yet.
## 0.8.18 (2026-11-23): obstacles with character
- **Every country has its own hop obstacles** (60% of the time; the rest are courier parcels). Hitboxes are unchanged:
  - Greek amphoras with a black-figure band, and crates heaped with oranges.
  - Forest log piles with a little mushroom on top.
  - Danube barrels with iron hoops and a rope coil.
  - Mountain snowmen with a carrot nose and a red scarf.
- **The scoot sign hangs from a proper gateway** that stands on the ground: stone with ivy in Greece, timber in the forest, lantern poles by the Danube, icicles in the mountains. Fixed: the sign's posts used to run straight up off the top of the screen.
- **Gaps have depth instead of a black box:** sea glinting below in Greece, a fern ravine in the forest, the river by the Danube, an ice-blue crevasse in the mountains. Rocky lips at both edges.
- **Obstacles react:**
  - Hop obstacles wobble when cleared; the sign swings after Kavi scoots under it, more on a perfect.
  - A perfect clear bursts confetti from the obstacle itself.
- **Less repetitive:** the generator never places the same single obstacle three times in a row.
- Performance (Medium benchmark): 5.68 ms, 489 draws (0.8.17: 5.45 / 460).
- Capture mode `--obs` (autopilot through all four countries).
## 0.8.17 (2026-11-23): smoother country changes, lighter everywhere, current Kavi on the loading screen
- **Fixed: hitch when the country changes** (owner felt it going from Greece to Bulgaria). Measured with the new `tools/bench.sh … --bench-transition`, where the run starts in Greece and switches to Bulgaria at 5 s:
  - Cause: the chapter card and popping texts drew letters at font sizes not yet rasterised, so one HUD frame took 6.7 ms.
  - Fix: every letter is rasterised up front, a few font sizes per frame while the title is up. Toast pops and the route countdown now scale the drawing instead of changing the font size. The worst HUD frame during the switch is now 1.8 ms.
  - Each country's music is now loaded at start instead of at the switch.
  - Overall, the worst frame during the switch fell from 17.7 to 9.2 ms of draw-generation time.
- **Lighter everywhere, same look:**
  - Rounded rectangles and ellipses (Kavi's parts, ground stones and more) are cached instead of rebuilt every frame; a cache hit is about 12× cheaper.
  - Medium benchmark: draw generation 6.3 → 5.45 ms, draw calls 467 → 460.
- **Low quality is lighter for low-end devices:** fewer fern fronds and no extra grass clumps in the foreground. Low benchmark: 4.35 ms, 278 draw calls.
- MSDF fonts were tried and rejected: they removed the hitch too, but cost about 48 draw calls because text stops batching.
- **Loading screen:** new key art with the current (original) Kavi waving at Lia; it was still the 0.8.8 sprite Kavi.
- **Title quotes** change every 30 s (was 12 s) and on every return to the title.
- Benchmark output now has a per-layer cost breakdown (`tags`, `tags_tr`).
## 0.8.16 (2026-11-23): love lines on the title, shuffled
- **Title quotes:** Kavi's 9 notebook lines are now mixed with 24 short public-domain love lines, each credited:
  - Shakespeare, Elizabeth Barrett Browning, Burns, Christina Rossetti, Byron, Robert Browning, Yeats, Shelley, Sara Teasdale, Emily Dickinson, Marlowe, Tagore, Emily Brontë and Keats.
  - Mostly sweet, a few deeper ones for grown-ups.
  - Each line was matched word for word on Wikisource. Two that could not be matched were left out.
- **Randomizer:** a shuffle bag, so every line shows once before any repeats. It reshuffles each time you return to the title, and the same line never shows twice in a row. Long lines split over two rows.
- Capture mode `--quotes`. Ledger row for the quotes.
## 0.8.15 (2026-11-23): new suits, a richer ground, a fluid Garage, Kavi's poems
- **Five suits that change Kavi's silhouette** (his face screen and scarf always stay):
  - Astro Bubble: a fishbowl dome with a collar.
  - Teapot: wide head, spout, lid and handle.
  - Bunny: tall ears, one floppy.
  - Blocky: square head with bolts.
  - Sprout: leaves and a little flower.
- **Garage is fluid:**
  - Moving along the category tabs with the arrows, A/D or the mouse switches the list straight away; no Enter needed.
  - Only the list rebuilds, with a quick staggered slide-in, so the tabs, wallet and focus stay put.
  - Down from a tab enters the list; Up from the first item goes back to the selected tab.
  - Kavi does a springy squash each time his look changes.
- **Ground and foreground** (owner: unchanged since the first version):
  - The ground takes the world's colours: lit near the top with sunlight washing down its face, deepening below, with soft soil strata.
  - Two-tone grass, sunlit at the front, plus wildflowers per country: Greek poppies, forest bluebells, Danube buttercups, and frost glints on the snow.
  - Softer contact shadow under the path.
  - Near-camera plants carry the scene's colour with a stronger sunlit rim, little grass clumps between them, and soft out-of-focus light specks drifting in front of the lens.
- **Kavi's poems** (his name means "poet"): a line from Kavi's notebook fades in under the logo every 12 s (9 original lines), and four breathers show him writing in his notebook.
- **Cursor:** a soft, rounded cream-to-peach arrow with a teal edge and a gentle shadow, in a modern desktop style. Hover adds the glowing kite diamond.
- **Performance** (Medium, chapter 2 benchmark): 0.8.14 was 438 draws / 5.8 ms script; 0.8.15 is 467 / 6.3. The bigger jump since 0.8.8 (365) comes from going back to the code-drawn Kavi in 0.8.9.
- Capture mode `--suits`.
## 0.8.14 (2026-11-23): tidy keyboard menus, lighter title, plane flies its heart
- **Keyboard navigation is predictable** (owner: A/D and the arrows felt messy). Every screen's buttons are grouped into rows, where a horizontal box is one row. Up/Down (W/S) step between rows and wrap around; Left/Right (A/D) move along a row and wrap, and do nothing on single-item rows, so focus never jumps somewhere odd.
- **Lighter title screen again** (owner: the 0.8.13 shade made the game feel dark). Menu text instead gets a soft drop shadow and a thin ink outline (custom drawn in `MenuItem`), and labels and headings get shadows too.
- **The plane flies its smoke heart:** its nose follows its path through the heart, rolling through the loop, and the smoke comes out of its tail, so the heart is drawn behind it.
- **New cursor:** a chunky cream arrow with an ink outline and a teal edge, replacing the paper plane (owner: too many paper planes). The hover version still adds the glowing kite diamond.
## 0.8.13 (2026-11-23): sky toys, custom cursor, keyboard menus
- **Clickable sky and sea on the title screen and in Scenic View** (classmates kept trying the balloons):
  - Balloons: hop with a burner puff and a squash; a tiny passenger waves, a heart floats out and it calls "Hello!" or "Ahoy!". Three quick clicks send it whooshing up and away ("Wheeeee!"), then it floats back.
  - The plane loops a smoke heart into the sky ("Sending love!").
  - Ships: toot their horn and puff steam with a music note ("Toot toot!"); the ship bobs.
  - Birds: scatter and tweet, then regroup.
  - The paper plane bumps balloons and birds when it flies into them.
- **Custom mouse cursor:** a cream paper-plane pointer, and a glowing kite-diamond version over anything clickable (menu items, sky toys, the paper plane). Desktop and web only. Made by `tools/art/make_cursor.py`.
- **Keyboard menus:** WASD as well as the arrows, and E as well as Enter and Space to select. If nothing has focus (the mouse was used last), the first menu key focuses the first item.
- **Easier to read:** a deeper, wider shade behind the menu column; unselected items are brighter with a stronger outline; soft hover ticks.
- The title rows are only as wide as their words, so the sea and sky behind them stay clickable. Before, clicking a ship behind "Scenic View" would have started Scenic View.
- The paper-plane tip now sits under the logo instead of following the plane. Capture mode `--sky`.
## 0.8.12 (2026-11-23): route choice countdown
- **Route choice after a breather ("A fork in the road"):** now shows a big countdown and a draining bar (7 s). In the last seconds the number and bar turn orange, then red, pulse with each second, tick with rising pitch and shake, and the screen edges throb red (off with Reduced motion).
- **Easy option (owner idea):** with about 2 seconds left, the Scenic route becomes a glowing "EASY ROUTE: tap anywhere!". Any key, click or tap (except on the Wild route or the pause button) takes it, and it is picked automatically at zero.
- The choice panel uses the new menu style and sits right of Kavi so it never covers him.
- **Fixed:** pausing during the choice no longer eats the countdown. It has its own timer, which used to be the global state timer.
- Up/Down still pick Wild/Scenic directly; that handling moved to `_input` so menu focus can't swallow the arrow keys. Capture mode `--junction`.
## 0.8.11 (2026-11-23): paper-plane mini-game and Quit
- **Title mini-game (owner idea):** click or tap near the paper plane to push it away from where you clicked (click above it and it dips, click below and it climbs). Steer it to Kavi: he waves with heart eyes, the plane circles him and you get "Letter delivered!" plus a counter. Click too many times too fast and it stalls, tumbles and falls, and a new plane glides in from an edge. A hint shows until the first push.
- **Quit:** a Quit item with a "Leave the game?" confirmation on Linux, Windows and Android. Hidden on the web build, where closing the tab is how you leave.
- **Esc / Android Back:** leaves Scenic View, pauses a run, steps back out of a menu, or asks before quitting from the title. Before, Android's Back quit the app instantly, even mid-run (`quit_on_go_back` is now off).
- Capture mode `--plane` (steer, deliver, stall, quit dialog). `tools/capture.sh` takes `VOLT_TAIL` for longer logs.
## 0.8.10 (2026-11-23): a more fluid title screen
- **Menu:** the rows slide in one after another, and a soft warm light band glides to whichever item you hover or select, sized to the words. The focused item swells slightly. Reduced motion turns off the slide-in.
- **Logo:** a sheen sweeps across KAVI every few seconds, and letters hop up and glow when the mouse passes over them.
- **Ambience:** warm motes of light drift up through the title scene, twinkling, with gentle mouse parallax (14/26/40 motes on Low/Medium/High).
## 0.8.9 (2026-11-23): the original Kavi is back
- **Owner request:** bring back the Kavi from before the full replacement. `scripts/kite_view.gd` is restored from 0.8.4: the code-drawn white and teal robot with a TV head, red scarf and blue boots, plus his faces, wobbly limb-jet hover, rough landings and the front-facing reunion.
- The Classic paint and Sunset Orange scarf are back to their 0.8.4 colours.
- Everything else from 0.8.5–0.8.8 stays: batched ferns (the performance fix), world, obstacles and menus.
- The 0.8.8 sprite parts stay in `assets/kavi/` (unused) in case they're wanted later.
## 0.8.8 (2026-11-23): Kavi is the concept art
- **Kavi is now the approved concept art itself** (`codex-r1/kavi-e-keystone-floating.png`), not a code redraw:
  - `tools/art/kavi_parts.py` cuts it into parts: front body and head, side body and head, mittens and boots.
  - The script also removes the background, softens the outline edge, and erases the drawn face and antenna.
  - The game animates the parts on Codex's stride rig.
- **Facing:** Kavi faces the camera when standing (title, waves, reunion) and turns sideways with a quick squash when he starts running.
- **Live face:** blinks, happy, heart eyes, surprised and determined eyes plus a smile on his real screen. The antenna is drawn live, so it wobbles and the Garage tips (diamond, star, heart, leaf) still work.
- **Garage colours** go through a palette-swap shader that keeps the art's own shading: paints, scarf colours, stripes and an animated rainbow.
- **Fixed:** under HDR 2D the sprite came out darker and more saturated. The shader re-encodes it so the colours match the sheet (measured: body 252/238/214 against 254/240/216).
- Settings → "Kavi's limbs" is removed (the art is the floating design).
- **Performance fix** (regression from 0.8.3/0.8.4, missed because those builds were not benchmarked): the leafy ferns and foreground fronds drew every leaflet as its own shape, about 1,500 draw calls on Medium in the forest. Each plant is now one batched draw.
  - Draw calls (chapter 2): Low 220, Medium 365, High 569, back below 0.8.1.
  - Script time per frame: Medium 5.3 ms and High 7.1 ms, still about 1–2 ms above 0.8.1 because of the extra scenery. An optimisation pass is on the backlog.
## 0.8.7 (2026-11-23): Kavi's helmet matches the concept sheet
- Kavi's helmet shapes are measured from `codex-r1/kavi-e-keystone-floating.png`:
  - **Side view:** a flat top with a large diagonal back-top corner, a back edge that slants in towards the bottom, a dark screen wrapping the front with a slanted edge, a low teal side panel, one tall eye pill and a small smile near the front.
  - **Front view:** a true keystone (wide top with cut corners, sides tapering in), a keystone screen, teal strips low on both sides, two tall eye pills and a filled smile.
- The helmet is flat cream like the sheet (the heavy shading bands are gone), and the front-view body is wider.
## 0.8.6 (2026-11-23): stronger, rounder Kavi E
- Matched to the owner's illustrations: **chunky jointed body by default**. Thick cylinder arms and legs with dark ball joints, big mitten fists, heavier boots, a sturdier torso with a large teal chest plate, and a bigger satchel.
- **3D look through cel shading:** every limb has a lit top and a shaded underside. The helmet has faceted planes (lit top, shaded lower band and back), and the screen is glassy with a reflection. The joints and fists have gloss spots, and the boots have a shaded heel and a highlighted toe.
- Kavi is about 8% larger. The front view (reunion) uses the same chunky limbs.
- Settings → Kavi's limbs still switches to Floating.
## 0.8.5 (2026-11-23): Kavi E is in the game
- **New Kavi, the owner's pick:** design E ("keystone floating") from the Codex concept round, built to Codex's handoff (`studio/docs/brand/characters/codex-r1/`):
  - a big keystone helmet whose front is a dark screen face (one glowing eye and a mouth in side view, two eyes in front view), a teal side panel and a teal diamond antenna,
  - a small cream body with a teal collar, a brown courier satchel with an envelope and two jet nozzles, and an orange scarf,
  - dark mittens with cream cuffs, and cream boots with teal toes.
- **Run:** played straight from Codex's comparison rig (`assets/kavi/stride.json`, one 28-frame cycle), interpolated smoothly. Planted boots move back at exactly road speed. The stride stretches with speed (up to 1.9×), and the pelvis bob is calmed to 60%.
- **Two body treatments for comparison**, under Settings → Kavi's limbs: Floating (hands and boots, the default) or Jointed (thin limbs with teal knees and dark joints).
- **Other poses** (jump, fall, hover with limb jets, scoot, wave, gust, rough landing) use the same parts. The reunion front view shows the keystone face with both eyes and both mittens, and he waves beside his head.
- **Garage looks carry over:** Kitty ears, Explorer lamp and band, paints, visors, scarf patterns, and the star, heart and leaf tips. The default tip is now the diamond, and the Classic paint is cream and teal.
## 0.8.4 (2026-11-23): obstacles that belong, closer layers, the fisher
- **Obstacles reworked for a courier's journey:**
  - Hop over tied parcels with a shipping label and a red stamp (stacked when tall).
  - Scoot under a wooden shop sign with bunting (on top, so the gap stays clear).
  - The gust gate is now a wooden picket gate with a pinwheel.
  - Bell posts and drawbridges are wooden, and the bounce wall is stone with ivy.
- **Foreground plants per country** (tinted, with a rim of light; no more black spikes): agave leaves (Greece), big ferns (Bulgaria), reeds and cattails (Danube), snowy pine boughs (Carpathians).
- **Under the road:** a Greek stone wall, river water with ripples below the Danube boardwalk, roots and glowing mushrooms in the forest, snow layers in the mountains.
- **The fisher** sits on a little jetty with a sun hat and a bucket; the rod curves and a red float bobs.
## 0.8.3 (2026-11-22): prettier Greece, softer people, clean pause
- **Greece:** the domes (they read as the wrong culture) and the sci-fi ring and spires are replaced by Greek temples (stepped base, columns, pediment), white windmills with turning sails, and a rare lighthouse whose beam slowly sweeps the sky.
- **Ferns** are now arching fronds with paired leaflets, not sticks.
- **Background people** have rounded bodies, tapered limbs, and round hands and feet instead of boxy stick figures.
- **Pause** hides every game text (HUD, chapter cards, captions, toasts) and uses a much darker overlay.
## 0.8.2 (2026-11-22): fair respawns, funny jetpack, Kavi faces Lia
- **Fixed** (bug from 0.8.1): the results screen showed 0 perfect moves and Tailwind x1. The game banked Stamps and Sparks before reading the run's stats.
- **New respawn** (owner design):
  - A cartoon smoke puff covers Kavi where he fell, and small puffs hide every obstacle that disappears.
  - He pops out running with about 4 s of clear road, and the meters keep counting.
  - Before, he was sent back 1.4 s and often hit the same obstacle again straight away.
- **Funny hover:** holding jump fires the bag jets plus little jets under both hands and both boots. He wobbles, kicks and flaps.
- **Rough landings:** after a long hover or a big drop he sometimes lands rough, stumbles forward and springs back up. This is visual only (gentler with Reduced motion).
- **Reunion:** when Kavi reaches Lia he turns to face the camera, a front view with both arms, then waves with heart eyes.
- **Fixed:** the glowing envelope badge showed through Kavi's arm (it was drawn on the glow layer). It now sits under the arm.
- **Title screen:**
  - Stamps, Sparks and the best score are bigger and outlined, so they read over the bright ground.
  - "Best" now counts every mode. Story scores were never saved before.
- Small text has a dark outline everywhere.
## 0.8.1 (2026-11-22): new Kavi and Lia, fixes from the owner's playtest
- **Kavi redesigned** after research on memorable cartoon robots: recognisable from his silhouette alone, big simple shapes, a round face on a sturdy body, one accent colour.
  - A wide rounded TV head whose whole front is a screen face (eyes and mouth).
  - A kite antenna.
  - A broad chest with shoulder pads and a glowing envelope badge.
  - A courier's messenger bag with a strap (hover nozzles underneath).
  - Thick tapered arms and legs with joint rings, mitten hands with thumbs, chunky boots.
- **Calmer run:** the upper body barely bobs and the head stays level, while the legs do the work. Strides get longer and the lean grows with speed, and the feet still match the ground.
- **Standing pose:** Kavi stands tall with straight legs and relaxed arms, breathing slowly.
- **Lia redesigned** to match, with round, soft shapes against Kavi's boxy ones: an oval screen face (eyes, blush, smile, blinks), a flower crown, side buns, an A-line body with an embroidered shawl, real arms holding her sketchbook, and little boots.
- **Fixed:** clicking the pause button with the mouse did nothing (only touch worked).
- **Menus:** Pause, Settings, Results, "Out of hearts", "Nice moves" and the ending now use the new in-world style. Settings opens in the right-hand column with On/Off and percent values. The tutorial from the menu asks for confirmation first.
- **Garage:**
  - Switching tabs and buying no longer replays the fade, so it feels instant.
  - A stronger shade behind the list.
  - A little extra letter spacing everywhere.
  - Everything is free while the game is in development.
- **Two currencies** (owner design):
  - Stamps are collected while running and buy everyday items.
  - Sparks are rare (+1 at Tailwind x4, +1 per 10 perfect moves, +2 per story chapter) and buy suits and patterned scarves.
  - The Garage exchanges 50 Stamps for 1 Spark, or 1 Spark for 25 Stamps.
  - Story runs now bank what you collect too; before, Story stamps were never saved.
- **Poetic place names:** The Amber Shore (Greece), Lanternwood (Bulgaria), Mirrorwater (the Danube), Starfall Heights (Romania).
## 0.8.0 (2026-11-22): smooth journeys, Kavi, new Garage
- **New name (owner's choice):** the hero is now **Kavi** (KAH-vee). He's easy to say anywhere and means "poet", which suits a robot who carries letters. The game is **KAVI: Letters to Lia**.
- **Smooth country changes:**
  - The new country sweeps in from the right, layer by layer. Far hills follow more slowly, and a soft haze band sits where the two worlds meet. Before, everything swapped in one frame.
  - The old sun sets while the new sun or moon rises.
  - Colours blend over 7 s (was 3 s).
  - The walking surface changes at a seam in the road ahead.
  - Towns, people, ships and the far mountain shape change with the sweep. Sky things crossfade.
- **Light from the sun and moon:**
  - Light rays fade when the sun or moon is behind hills or mountains.
  - The ridge in front of a low sun gets a glowing silver lining.
  - The water reflection dims when the sun is hidden.
- **New title screen:**
  - A clean KAVI logo in the world's style: cream letters with an ink outline and a rim of the country's light. The letters rise in one by one, the letterspaced subtitle sits between hairlines, and a paper plane flies around it. The blurry glow is gone.
  - The menu is a column of text items with no boxes. A glowing diamond and underline mark the selected item.
  - On the title, the sun sets behind Kavi instead of behind the menu.
  - Kavi stands still and looks around; the world no longer slides under him.
- **New Garage:** a story idea from the owner: Kavi is a little memory chip who can move into new suits.
  - 5 categories, 25 items:
    - Suits: Courier, Kitty, Explorer with a headlamp
    - Paint: 5 colour schemes
    - Visor: 5 eye colours
    - Scarves: 8, including Candy Stripes and an animated Rainbow
    - Antenna tips: kite, star, heart, leaf
  - The camera zooms in on Kavi, hovering an item tries it on, and buying one plays a sparkle and a chime.
  - Pace: the first scarf (15) and visor (20) take about 3 runs; everything costs 790 Sparks in total.
  - Old saves keep their scarves.
- **Face animations:**
  - Kavi's eyes follow what he's doing: ahead when running, up on a jump, down when falling. When he's idle they wander around.
  - He sometimes double-blinks.
  - A small smile shows when he's happy, and an "o" mouth when he's amazed.
- **Fixed:** the test script's boot check could report "clean" even when the game had script errors. It now uses a here-string instead of `echo | grep -q` under pipefail.
- Performance (chapter 2 benchmark vs 0.7.0):
  - Script time per frame: Low 2.97 → 3.20, Medium 3.81 → 3.93, High 4.87 → 5.08 ms.
  - Draw calls are about the same: 269 / 391 / 589.
## 0.7.0 (2026-11-22): a living world
- **Towns at night:** distant city skylines (Greece, Danube) and hillside villages with little church towers (Bulgaria, Carpathians). Their windows switch on and off slowly, and some rooftop antennas blink red.
- **People doing things** in the background:
  - kids flying colourful kites
  - a café table under an umbrella
  - a couple on a bench under a street lamp
  - someone fishing
  - dog walkers with wagging tails
  - a donkey grazing beside a farm cart
  - people waving

  They fade out while they pass behind Vayu, so they never look attached to him.
- **Ships:** sailboats and a lit ferry on the Greek sea; barges and a paddle steamer, with smoke puffs, on the Danube. Their lights reflect in the water.
- **Sky:** a plane now and then, with blinking lights and a faint contrail. Striped hot-air balloons with a flickering burner. A flock of birds over the Danube.
- **Quality levels:** Low keeps the skylines (without windows), ships, planes and birds, and skips the people and balloons. Medium shows fewer than High.
- Performance (chapter 2 benchmark vs 0.6.0):
  - Draw calls: Low 243 → about 267, Medium 353 → 398, High 524 → 584.
  - Script time per frame: Low +0.15 ms, Medium about +0.0 ms, High +0.36 ms.
## 0.6.0 (2026-11-22)
- **New names (owner's choice):** the hero is **Vayu** (Hindi/Sanskrit for "wind"), and the girl is **Cornelia, called Lia**. The game is shown as **VAYU: Letters to Lia** (window or tab title, title screen, loading screen, story text). The internal project name stays "VOLT/RUN" so desktop saves are kept. Store pages are not renamed yet.
- **New menu:** a big logo with a subtitle ribbon and a paper plane, plus a frosted card with a warm "Play Story" button. Every screen fades in softly, and buttons lift on hover and squash when pressed. All panels have new rounded, shadowed styles.
- **Fonts:** Fredoka for titles, buttons and the HUD, Nunito for body text. Both are bundled and under the OFL licence.
- **Scenic View** (main menu): no obstacles and no HUD. Vayu just runs while the four countries go by, about 38 s each, then it loops. Esc or Back returns to the menu.
- **Fixed:** the sun and moon light rays started far above the disc. They now fan out from the sun or moon itself.
- **Less repetitive scenery:**
  - Landmarks (bridge, castle, ring, spire) are rare.
  - Trees come in small groves with varied height, tiers, width and lean.
  - New props: village houses with lit windows, bushes, birches and rocks.
  - Some Greek columns are broken ruins.
  - Reed clumps vary.
  - Foreground leaves vary.
  - Some props sit further back in the haze.
- The stones and roots in the ground are soft-tinted instead of near-black blobs.
- Performance (chapter 2 benchmark vs 0.5.0):
  - Draw calls: Low 246 → 243, Medium 329 → 353, High 488 → 524.
  - Script time per frame: unchanged (2.82 / 3.80 / 4.51 ms).
## 0.5.0 (2026-11-22)
- **Kite runs forward for real.** The old run cycle pushed the planted foot forward (a moonwalk). The new cycle plants each foot and slides it back at ground speed, lifts and tucks it, and swings it forward; the body bobs twice per stride, squashes slightly on landing, leans in, and the arms swing against the legs.
- **Flowing scarf:** 12-segment cloth with air drag and a ripple running to the tip, drawn as smooth tapered ribbons (two tails, outline and sheen). It holds still while the game is frozen or paused.
- **More detail on Kite:** glossy helmet highlight and shadow, shaded chest, boot soles.
- **Prettier worlds, about the same speed:** hills fade with distance (aerial perspective); a sea with the sun's reflection in Greece and a river on the Danube; every country has its own ground: Greek stone paving, Bulgarian moss, a Danube boardwalk on posts, Carpathian snow. The ground is no longer a black band.
- **Fixed:** the Danube bridge floated in the air. It is now a tied-arch bridge on piers with end towers.
- **Three hearts per run** (was two).
- Garage explains how Sparks are earned (1 per 25 stamps, +1 for Tailwind x4); web-portal builds no longer mention ads.
- Performance (chapter 2 benchmark vs 0.4.2): draw calls +4-5%, script time +0.05-0.5 ms per frame.
## 0.4.2 (2026-11-22)
- **New loading screen:** Kite and Lumi under the aurora with the VOLT/RUN title (sharp 3x render) and a rounded gold progress bar, instead of the Godot logo. Also used as the splash on Android and desktop.
## 0.4.1 (2026-11-22)
- **Fixed:** Kite ran in place on the "Nice moves, courier!" screen after the tutorial, which looked like running backwards. He now stands and smiles; his legs also hold still during tutorial prompts and while paused.
- Release builds for web portals (CrazyGames, itch.io) hide the in-game ad prompt.
## 0.4.0 (2026-11-21)
- **Runs much better on low-end phones and in browsers** (measured in chapter 2 with the built-in benchmark, `tools/bench.sh`): draw calls per frame 890 → 307 (medium) / 237 (low), primitives 37.7k → 7.7k / 6.2k, script draw time 4.2–6.2 ms → 2.1–2.6 ms. Glows are now single textured quads, grass is one shape per ground piece, Kite's limbs are 2 shapes instead of 6, and detail scales with quality.
- **Graphics quality** Auto / Low / Medium / High (Settings). Auto starts at Medium on phones and browsers, High on desktop, and steps down on its own if the game runs slowly. Low turns off HDR and bloom. Phones and browsers are capped at 60 fps.
- **Music is pre-rendered**, so there is no 1–3 s freeze on weak devices when an area loads.
- **Keyboard or touch, detected automatically:** on computers the touch buttons are hidden and a key bar shows at the bottom (W/Up/Space hop, S/Down scoot/dive, X gust, C letter, Esc pause). Touching the screen brings the buttons back. Tutorial prompts name the controls you actually use.
- **Two hearts per run.** After the second fall the story sends you back to the home screen (your chapter is saved: "Continue chapter N"); Endless/Daily show the results.
## 0.3.0 (2026-11-21)
- **Interactive tutorial ("Practice run"):** starts automatically on the first launch. At each new move the game freezes on a prompt ("HOP", "SCOOT", "HOLD to HOVER", "GUST", "LETTER", "DIVE", "SWOOP"), the matching touch button pulses, and play resumes when you do it. Mistakes just pop Kite back to retry. It can be skipped at any time; returning players (with earlier progress) are never forced into it. A **Tutorial** button on the title screen replays it.
- Test suite now also boots the real game (catches script errors the unit tests can't).
## 0.2.0 (2026-11-21)
- **Fixed:** obstacles were nearly invisible in chapter 2 (Rhodope Lanterns) and hard to read elsewhere. They are now solid, light shapes with an outline and a colour band (amber = hop, rose = scoot, green = gust, gold = letter, pink = dive bloom), readable without glow.
- **Fixed:** after a biker rescue, leftover obstacles could overlap the next stretch.
- **Calmer, more premium look:** much less bloom, softer sun and light shafts, fewer floating motes, gentler palettes (chapter 2 is now blue hour instead of near-black), the trail appears only at Tailwind x3+.
- **Pacing:** every stretch starts with ~3 s of free running and eases into speed. Difficulty ramps smoothly within each stretch. Breaks come less often (story stretches 50–62 s, endless 55 s) and are a little shorter.
- Windows and Linux builds alongside the Android APK.
- **Browser version** on GitHub Pages: https://singh679.github.io/volt-run-luminous/ (no install; works on iPhone).
## 0.1.0 (2026-11-20)
- First playable 2D slice: story, Endless, Daily, rescues, recovery breaks, Tailwind, touch controls, ad stub.
