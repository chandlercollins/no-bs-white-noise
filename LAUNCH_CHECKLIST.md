# 🚀 Launch Checklist — v2.1 (morning session)

Everything below needs **you** (Apple ID / judgment). All engineering is merged
to `main` (currently `6914f5a`) and verified — Debug + Release build clean,
15/15 tests green, 0 warnings. Est. remaining: ~40 min.

## 1. Review & merge — ✅ DONE
[PR #1](https://github.com/chandlercollins/no-bs-white-noise/pull/1) (compliance,
iPad, sleep timer/volume/fades) and
[PR #2](https://github.com/chandlercollins/no-bs-white-noise/pull/2) (audio-engine
refactor) are both merged to `main`. Both branches are deleted, locally and on
GitHub. Nothing to do here — skip to QA.

## 2. Ears-on QA — the one thing I couldn't verify (~15 min, use a real device or sim with sound on)
- [ ] Play/stop each of the 5 sounds — fade-in (~0.5s) and fade-out (~0.3s) feel right, no clicks
- [ ] **Relative loudness**: fire/rain/birds vs white/brown at the same volume (base gains
      set from measured RMS — fire 0.60, rain 0.45, birds 1.0 — but ears beat math; tweak
      `mp3BaseVolume(for:)` in AudioEngine.swift if needed)
- [ ] Drag the volume slider while playing — live change, no glitches
- [ ] Arm a 15-min sleep timer, confirm chip + countdown; optionally wait it out → 3s fade to stop
- [ ] Tap the countdown chip while a timer is running — it should do nothing now (fixed: used to
      look tappable and play a pointless animation)
- [ ] Control Center: play/pause + next/prev sound works; Now Playing shows title + artwork
- [ ] Siri: "Play rain in White Noise" and "Set a sleep timer in White Noise"
- [ ] iPad: rotate to landscape once — confirm layout holds (30 seconds)
- [ ] If you have a Larger Text / Accessibility Sizes setting handy: bump it up and confirm
      the countdown chip grows instead of clipping (fixed this session; verified in sim, not
      on a real device)

## 3. Archive & upload (~10 min, needs your Apple ID in Xcode)
- [ ] Xcode → open project → select "Any iOS Device (arm64)"
- [ ] Bump build number if needed (currently **2.1 (3)** — unchanged since last archive;
      bump if you've already uploaded a build 3 before)
- [ ] Product → Archive → Organizer → **Distribute App → App Store Connect → Upload**
      (ExportOptions.plist already in repo if you prefer CLI)
- [ ] No export-compliance prompt should appear (`ITSAppUsesNonExemptEncryption=false` is set)

## 4. App Store Connect (~15 min) — paste from `APP_STORE_METADATA.md`
- [ ] appstoreconnect.apple.com → My Apps → No-BS White Noise (create the app record if absent:
      bundle id `com.chandlercollins.No-BS-White-Noise`, SKU whatever you like)
- [ ] **Price: $2.99 (Tier 3)** · Category: Productivity / Health & Fitness
- [ ] Description, subtitle, keywords, promo text → all in APP_STORE_METADATA.md
- [ ] **What's New** → the expanded v2.1 section (Liquid Glass, sleep timer + Siri,
      volume, fades, Control Center/Lock Screen, accessibility pass — rewritten to be
      more detailed, ready to paste as-is)
- [ ] Screenshots: upload `Screenshots/6.9-inch/` (01→05 order) and `Screenshots/13-inch/` (iPad)
- [ ] Privacy: "Data Not Collected" (matches the shipped PrivacyInfo.xcprivacy)
- [ ] Age rating 4+ · Review notes: see "App Review Information" section in metadata doc
- [ ] Select the uploaded build → **Submit for Review**

## 5. Aftercare — ✅ DONE
- [x] Tagged the release: `v2.1` is on GitHub
- [x] Merged branches deleted (local + remote)
- [x] Overnight `caffeinate` killed

## Known follow-ups (not blockers — see IMPROVEMENTS.md)
- Sound mixing (layering sounds) is still a future feature — the AudioEngine refactor
  (PR #2, merged) was the groundwork for it, not the feature itself
- Mac support: roadmap ("eventually", your call 2026-07-11)
- Drawer pins Dynamic Type at default size (`.large`) for its 7-chip sleep-timer row —
  empirically necessary (chips overflow above that), VoiceOver fully labeled. Re-verified
  this session at max accessibility size (AX5): drawer and main screen both render clean.
