# Changelog
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
