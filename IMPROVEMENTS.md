# No-BS White Noise — Review, Modernization & Enhancement Notes

_Last updated: 2026-07-11 · reviewed against Xcode 26.5 / iOS 26.5 SDK_

This document records (1) what was changed in this pass, (2) the code-review
findings, and (3) prioritized ideas for future feature work. It's meant to be a
living planning doc — prune it as items ship.

---

## 1. What changed in this pass

### Real Liquid Glass migration (the headline)
The app previously **claimed** Liquid Glass but hand-rolled it entirely with
stacked gradients + `.ultraThinMaterial`. It now uses Apple's **genuine iOS 26
Liquid Glass APIs**, gated with `#available(iOS 26.0, *)` and a clean
material fallback for iOS 18.2–25:

| Surface | Now uses |
|---|---|
| Play/Stop hero button | `.glassEffect(.regular.tint(stateColor).interactive(), in: Circle())` |
| Theme toggle | `.glassEffect(.regular.interactive(), in: Circle())` + `.symbolEffect(.replace)` morph |
| Sound buttons | `.glassEffect`, tinted when selected, wrapped in a `GlassEffectContainer` |
| Sound menu panel | `.glassEffect(.regular, in: RoundedRectangle(...))` |

Reusable helpers were added at the bottom of `ContentView.swift`
(`glassCircle`, `glassPanel`, `glassGroup`, `makeGlass`) so call sites stay
readable and the availability branching lives in one place. This removed
~250 lines of gradient/material scaffolding.

### Code-quality fixes
- **Accessibility:** the main Play/Stop button had **no accessibility label** —
  added label + hint; sound buttons now expose an `.isSelected` trait.
- Removed **8 `print("DEBUG: …")`** statements that shipped to the console.
- Removed dead code: `stopAudio()`, `frameCounter`, and 6 unused computed
  properties (`textColorForCurrentTheme`, `themeButtonStrokeWidth`, etc.).
- De-duplicated `startAudio()` / `startAudioQuick()` (near-identical) down to one.
- Hardened `setupRemoteCommandCenter()` against duplicate handlers
  (`removeTarget(nil)` before `addTarget`).
- Consolidated the theme toggle's redundant `Button` + `.onTapGesture`.
- Fixed a stale comment ("Cycles through system, light, and dark" → toggle).

### Preferences now persist
`themeMode` and `selectedSoundType` moved from `@State` to `@AppStorage`.
Previously the theme matched the system **only on the very first launch** and
then silently reset to Light on every subsequent launch, ignoring the user's
manual choice. Both now persist.

### App Store assets & copy
- **Screenshots:** a finished, captioned 5-shot set at the exact 6.9"
  resolution (1320×2868) is in `Screenshots/6.9-inch/`. See
  `Tools/make_screenshots.py` and `APP_STORE_METADATA.md` for regeneration.
- Rewrote the App Store **description / promo / what's-new** to be tighter and
  honest (the Liquid Glass claim is now literally true), and fixed stale
  version numbers (2.0 → 2.1) and the `YOUR_USERNAME` GitHub link in the README.

> **Note:** `ContentView` contains a small `#if DEBUG` hook,
> `applyScreenshotStateIfNeeded()`, that forces UI states from launch env vars
> for reproducible screenshots. It is compiled **only in Debug** and has zero
> effect on the shipping app. Remove it if you'd rather not keep it.

---

## 2. Review findings not auto-fixed (worth a look)

- **Audio render thread reads SwiftUI `@State`.** `createWhiteNoiseNode()`'s
  real-time callback reads `self.selectedSoundType` and `self.brownNoiseFilter`
  directly. It works today, but reading/writing view state from the audio
  thread is a latent data race. Cleaner: move audio into a small `@Observable`
  audio-engine class that owns those values, and have the view drive it. This
  also fixes the fragile pattern of the view struct being captured in the
  `MPRemoteCommandCenter` / `NotificationCenter` closures.
- **MP3 vs generated loudness mismatch.** Preloaded MP3s were dropped to
  `volume = 0.3` while generated white/brown noise runs at `finalGain = 0.8`.
  Fire/Rain/Birds may now feel noticeably quieter than White/Brown — worth an
  A/B listen and per-sound normalization.
- **Reduce Motion.** The play button's infinite pulse animation runs regardless
  of `accessibilityReduceMotion`. Gate it on that environment value.
- **Info.plist duplication.** The target sets both `GENERATE_INFOPLIST_FILE = YES`
  and a hand-maintained `INFOPLIST_FILE`. It builds clean today, but consider
  consolidating to one source of truth for version keys.

---

## 3. Major feature enhancements (prioritized)

### Tier 1 — highest impact, low/medium effort
1. **Sleep timer.** The #1 expectation for a sleep/focus app. Add 15/30/45/60/90/120‑min
   options to the menu; reuse the existing structured-concurrency `Task.sleep`
   pattern from `resetScreenDimTimer`, fade out, then stop. Surface remaining
   time on the play button.
2. **Fade in / fade out.** Start and stop are abrupt. `AVAudioPlayer` supports
   `setVolume(_:fadeDuration:)`; a 300–600 ms fade feels dramatically more
   premium and prevents the "click" on stop.
3. **Volume control.** A single glass slider in the menu (master, or per-sound).
   Pairs naturally with the loudness-normalization fix above.

### Tier 2 — strong differentiators, medium effort
4. **Home Screen + Control Center widgets.** You already ship `PlaySoundIntent`.
   A WidgetKit control (`ControlWidget`) and Lock Screen widget to start a
   specific sound in one tap is a great fit for "fast software" and is mostly
   wiring you already have.
5. **Sound mixing.** Let users layer sounds (e.g., Rain + Fire). Requires moving
   from "one player at a time" to an `AVAudioEngine` mixer graph with a node per
   active sound — the biggest architectural lift here, but a headline feature.
6. **A few more sounds.** Ocean, thunderstorm, café/coffee-shop, fan. Each is an
   MP3 + one `SoundType` case + one icon; near-zero risk. (Keep the "no bloat"
   bar — every sound must earn its place.)

### Tier 3 — ecosystem polish
7. **Focus filter integration** (`SetFocusFilterIntent`) — auto-start a sound
   when a Focus turns on.
8. **Apple Watch companion** — start/stop from the wrist (already on the roadmap).
8b. **Mac support** *(confirmed "eventually" by Chandler, 2026-07-11)* — likely via Mac
    Catalyst or "Designed for iPad" first, native SwiftUI Mac app later. Audio engine and
    Liquid Glass code are already cross-platform-friendly; main work is layout + menu bar.
9. **Interactive "Set sleep timer" App Intent / Shortcuts action.**
10. **iPad-specific layout.** Today the UI just scales 1.6×; the extra canvas
    could host the sound selector inline instead of in a drawer.

---

## 3.5 Audio-engine refactor plan (v3.0 — planned 2026-07-11, not yet built)

**Problem:** `createWhiteNoiseNode()`'s real-time render closure reads SwiftUI view state
(`self.selectedSoundType`, `self.brownNoiseFilter`) from the audio thread — a latent data
race — and the view struct is captured by `MPRemoteCommandCenter` / `NotificationCenter`
closures.

**Plan (≈1 day):**
1. New `AudioEngine` class, `@Observable @MainActor`, owning: `isPlaying`,
   `selectedSound`, `masterVolume`, sleep-timer state, the AVAudioEngine/players,
   and all the current audio methods (start/stop/fade/preload/nowPlaying/remote commands).
2. Render-thread safety: the source-node closure captures a small `final class
   RenderState { let sound: Atomic<SoundType>; var brownFilter: Float }` (or
   `os_unfair_lock`-guarded struct) owned by AudioEngine — never touches SwiftUI state.
   `brownFilter` lives only on the render thread; `sound` is written from MainActor via
   atomic store, read via atomic load per render cycle.
3. ContentView becomes pure presentation: `@State private var engine = AudioEngine()`,
   bindings for volume/sound/timer; remote-command + Siri-notification targets move into
   AudioEngine (fixing the struct-capture smell).
4. Tests: unit-test AudioEngine state transitions without UI (play→stop, timer expiry
   cancels, volume math); keep the existing bundle smoke tests.
5. Migration is mechanical (move code, rename `self.` references); screenshot set should
   be pixel-identical — regenerate to confirm.

**Risk:** low-medium; biggest care point is not regressing Control Center/Now Playing
behavior. Do it as v3.0 groundwork alongside sound mixing (Tier 2 #5), which needs the
same engine class.

## 4. Suggested next steps
1. Ship this pass (real Liquid Glass + fixes + screenshots) as **2.1**.
2. Fold in **sleep timer + fade** for **2.2** — the two features users will
   notice most.
3. Tackle the **audio-engine refactor** (Tier‑2 mixing) as **3.0**, which also
   resolves the render-thread `@State` concern.
