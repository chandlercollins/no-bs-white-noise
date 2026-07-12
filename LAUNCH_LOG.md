# Launch Log — No-BS White Noise

Running log for the autonomous overnight launch-prep loop. **Newest entries on top.**
Branch: `overnight/launch-prep` — never merged to `main` automatically; review in the morning.

---

## 2026-07-11 — Cycle 5: P3 polish ✅ (verified)
- **Reduce Motion:** pulse animations (play button + drawer handle) now skipped when
  `accessibilityReduceMotion` is on.
- **Dynamic Type:** main screen scales; the drawer is pinned at the default size after
  empirically verifying that even `xxxLarge` overflows the 7-chip timer row (AX5 screenshots
  at each cap). Standard compact-control-cluster pattern; all controls have VoiceOver labels.
- **Loudness normalization with real data:** decoded the MP3s and measured RMS
  (fire 0.025, rain 0.045, birds 0.008 vs generated white ~0.185). Applied √-compressed
  per-sound base gains anchored to Chandler's previous 0.3 tuning: fire 0.60, rain 0.45,
  birds 1.0. **Morning ears-on QA recommended** (relative levels are estimates).
- **Verified:** Debug + Release clean; AX5 drawer confirmed pixel-perfect in sim.
- **Next up:** P4 — minimal test target with smoke tests; audio-engine refactor PLAN;
  then final regression pass + LAUNCH_CHECKLIST.md.

---

## 2026-07-11 — Cycle 4: P2 complete — fades + volume control ✅ (build + UI verified)
- **Fade in/out:** playback now fades in over 0.5s (MP3 `setVolume(_:fadeDuration:)`,
  engine mixer ramp) and manual stop fades out over 0.3s. Sound switching stays instant.
- **Master volume:** `@AppStorage("masterVolume")` (default 0.7) with a slider row in the
  drawer (speaker icons, combined a11y element); changes apply live to whatever is playing.
- Refactored the sleep timer's fade into a shared `fadeCurrentAudio(to:duration:)`;
  volumes are re-applied on every play, so the MP3 volume-restore hack is gone.
- Preload no longer bakes in per-sound volumes (applied at play time as base × master).
  MP3 base gain 0.45 keeps loudness near previous levels at the default master volume.
- **Refreshed marketing screenshots** (iPhone + iPad): drawer shots now show volume +
  sleep timer; "playing" shot shows the live countdown chip. `What's New` copy updated.
- **Verified:** Debug + Release builds clean; drawer UI + countdown visually confirmed.
  **Residual risk:** fades are audio-domain — not audibly verified in the sim; morning QA:
  play/stop each sound once (fade-in/out) and drag the volume slider while playing.
- **Next up:** P3 — Reduce Motion for the pulse, Dynamic Type pass, loudness normalization.

---

## 2026-07-11 — Cycle 3: P2 sleep timer ✅ (build + UI verified; expiry logic-verified)
- **New feature:** sleep timer with Off/15/30/45/60/90/120-min glass capsule chips in the
  sounds drawer (drawer height 160→238), indigo tint when armed, `.isSelected` a11y traits.
- Live countdown capsule under the play button while armed (`Text(timerInterval:)` — no
  Timer objects), fixed-height slot so the play button never shifts.
- Expiry: ~3s fade-out — MP3 via `setVolume(0, fadeDuration:)` (restores volume after stop
  so the next play isn't silent); generated noise via a 30-step mixer ramp — then full stop.
- Cancellation wired into: manual stop, audio interruption, re-arm, "Off", and view cleanup.
- DEBUG hook extended with `UITEST_TIMER=<minutes>` for screenshot states.
- Fixed two visual defects found during verification: chip text wrapping ("15m" → two
  lines) and adjacent capsules blending into blobs (removed GlassEffectContainer for chips).
- **Verified:** Debug + Release builds clean (zero warnings); menu chips and live countdown
  visually confirmed in the sim. **Residual risk:** end-to-end expiry fade not audibly
  verified (needs a ≥15-min wait); logic is compile-verified and cancellation-checked —
  suggest a quick 15-min manual QA in the morning.
- **Next up:** P2 (continued) — fade in/out on play/stop, then volume control in the menu.

---

## 2026-07-11 — Cycle 2: P1 iPad screenshots ✅ (verified)
- Captured all five marketing states on the **iPad Pro 13-inch (M4)** simulator at the
  exact App Store 13" spec (2064×2752), clean 9:41 status bar, via the DEBUG launch hook.
- Refactored `Tools/make_screenshots.py` to be device-parametric (iPhone + iPad configs).
  **Verified the iPhone 6.9" set is byte-identical** after the refactor (git shows no diff).
- Finished set in `Screenshots/13-inch/`; raw frames in `raw/ipad/` (gitignored).
- Visually verified the iPad composite (captions, floating frame, dark Fire state).
- `APP_STORE_METADATA.md` updated: iPad section now READY with location.
- **Verified:** script ran clean; both sets at exact spec; iPad app renders correctly (1.6× scaling).
- **Next up:** P2 — sleep timer (15/30/45/60/90/120 min with fade-out), then fade in/out, then volume.

---

## 2026-07-11 — Cycle 1: P0 compliance ✅ (verified)
- Added `Sources/PrivacyInfo.xcprivacy` — `NSPrivacyTracking=false`, no collected data
  types, declares the UserDefaults required-reason API (`NSPrivacyAccessedAPICategoryUserDefaults`,
  reason `CA92.1`) for the `@AppStorage` theme/sound prefs. **Confirmed bundled** into the built `.app`.
- Added `ITSAppUsesNonExemptEncryption = false` to `Simple-White-Noise-Info.plist` so uploads
  skip the export-compliance prompt. **Confirmed present** in the built `Info.plist`.
- Verified the app icon set: one 1024² icon with light/dark/tinted appearances for iOS 26.
- **Verified:** Debug build SUCCEEDED, zero warnings; manifest + flag confirmed in the bundle.
- **Next up:** P1 — iPad 13" (2064×2752) screenshots via the iPad Pro 13-inch (M4) simulator,
  reusing the DEBUG launch hook + `Tools/make_screenshots.py`.

---

## 2026-07-11 — Kickoff (session handoff)
- Overnight self-paced loop started locally with full Xcode 26.5 available.
- Starting state: **v2.1**, real iOS 26 Liquid Glass already shipped to `main`;
  6.9" App Store screenshots done; docs/metadata updated.
- Queue to work, in order:
  - **P0 compliance** — `PrivacyInfo.xcprivacy`, `ITSAppUsesNonExemptEncryption=false`, app-icon completeness check
  - **P1 assets** — iPad 13" screenshots (2064×2752)
  - **P2 features** — sleep timer (+ fade-out), fade in/out, volume control
  - **P3 polish** — Reduce Motion, Dynamic Type, MP3/generated loudness normalization
  - **P4 quality** — minimal test target; plan the audio-render-thread `@State` refactor
- **Next up:** P0 — add the privacy manifest + export-compliance flag.
