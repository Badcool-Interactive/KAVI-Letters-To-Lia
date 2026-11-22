# Changelog
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
