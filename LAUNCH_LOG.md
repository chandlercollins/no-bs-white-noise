# Launch Log — No-BS White Noise

Running log for the autonomous overnight launch-prep loop. **Newest entries on top.**
Branch: `overnight/launch-prep` — never merged to `main` automatically; review in the morning.

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
