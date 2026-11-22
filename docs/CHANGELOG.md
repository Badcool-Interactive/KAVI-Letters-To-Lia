# Changelog
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
