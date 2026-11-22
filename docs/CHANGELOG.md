# Changelog
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
