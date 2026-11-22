# VOLT/RUN backlog: "premium polish" release (v0.5.0)

Owner's rule (2026-11-22): collect items here and build them together as one
release once the list is big enough to be worth it, not one at a time.
Priority: ★★★ biggest visible gain → ★ nice to have. Download/licence items
need the owner's OK first (gate G4) and a ledger entry.

## 1. Look & feel
- ★★★ **Fonts:** Fredoka (titles, buttons, callouts like PERFECT) + Nunito (body,
  tips, settings). OFL, ~1 MB. Needs OK to download from Google Fonts; record in LEDGER.csv.
- ★★★ **UI panels and buttons:** rounded cards with soft shadow, button press
  squash + hover lift, icons on buttons (play, gear, shirt for Garage).
- ★★★ **Screen transitions:** soft fade/slide between title, chapter cards,
  results; no hard cuts.
- ★★ **Animated title screen:** Kite idles, blinks and looks around; slow parallax drift; logo gently breathes.
- ★★ **Chapter postcards:** each chapter opens on an illustrated postcard
  (Greece, Bulgaria, Danube, Carpathians) that becomes a collectible stamp.
- ★★ **Journey map:** a stylised map Greece → Bulgaria → Romania showing
  progress and where Lumi waits.
- ★★ **Dialogue boxes with portraits** of Kite and Lumi, plus wordless
  "chirp" voices (gibberish blips) while text types out.

## 2. Juice (game feel)
- ★★★ **Kite squash & stretch** on jump/land, dust puffs on landing, tiny
  happy hop on PERFECT.
- ★★ **Tier-up celebration:** short sparkle burst + chime when Tailwind
  rises; gentle (no flashing; respects Reduce motion).
- ★★ **Results screen:** animated count-up, star rating, best-run ribbon.
- ★ **Haptics** on phones (light tap on PERFECT); off switch in Settings.

## 3. World beauty
- ★★ **Ambient life:** butterflies (Greece), lantern moths (Bulgaria),
  birds over the Danube, snowflakes under the aurora.
- ★★ **Water reflections** on the Danube chapter.
- ★ **Day-to-night drift** within a chapter.

## 4. Audio
- ★★ Richer UI sounds (soft clicks, page-turn on cards); footstep ticks
  that follow the run cycle.
- ★ A short title theme distinct from the chapter loops.

## 5. Reach & accessibility
- ★★ **Languages:** Romanian, Bulgarian, Greek (the game's own countries), then Spanish/Portuguese.
- ★★ **Colour-blind safe obstacle palette** option, Reduce motion, larger text.
- ★ Proper app icon and splash screen; branded web loading screen with a tip.

## 6. Business / platform (do when the trigger happens)
- CrazyGames SDK (ads, loading events) as soon as CrazyGames asks.
- GameDistribution SDK if they accept us.
- Release-signed APK + Play Store listing (needs owner's Play Console account).
- Windows exe tested on a real Windows PC; code-signing later.

## Done
- v0.4.1: Kite no longer runs in place (moonwalk) after the tutorial / in prompts / when paused.
