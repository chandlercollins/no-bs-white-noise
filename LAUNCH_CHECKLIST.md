# 🚀 Launch Checklist — v2.1 (morning session)

Everything below needs **you** (Apple ID / judgment). All engineering is done and
verified on branch `overnight/launch-prep` (draft PR #1). Est. total: ~45 min.

## 1. Review & merge (~10 min)
- [ ] Skim [PR #1](https://github.com/chandlercollins/no-bs-white-noise/pull/1) & `LAUNCH_LOG.md` (newest-first)
- [ ] Merge `overnight/launch-prep` → `main`

## 2. Ears-on QA — the one thing I couldn't verify (~15 min, use a real device or sim with sound on)
- [ ] Play/stop each of the 5 sounds — fade-in (~0.5s) and fade-out (~0.3s) feel right, no clicks
- [ ] **Relative loudness**: fire/rain/birds vs white/brown at the same volume (I set base gains
      from measured RMS — fire 0.60, rain 0.45, birds 1.0 — but ears beat math; tweak
      `mp3BaseVolume(for:)` in ContentView.swift if needed)
- [ ] Drag the volume slider while playing — live change, no glitches
- [ ] Arm a 15-min sleep timer, confirm chip + countdown; optionally wait it out → 3s fade to stop
- [ ] Control Center: play/pause + next/prev sound works; Now Playing shows title + artwork
- [ ] Siri: "Play rain in White Noise"

## 3. Archive & upload (~10 min, needs your Apple ID in Xcode)
- [ ] Xcode → open project → select "Any iOS Device (arm64)"
- [ ] Bump build number if needed (currently **2.1 (3)**)
- [ ] Product → Archive → Organizer → **Distribute App → App Store Connect → Upload**
      (ExportOptions.plist already in repo if you prefer CLI)
- [ ] No export-compliance prompt should appear (`ITSAppUsesNonExemptEncryption=false` is set)

## 4. App Store Connect (~15 min) — paste from `APP_STORE_METADATA.md`
- [ ] appstoreconnect.apple.com → My Apps → No-BS White Noise (create the app record if absent:
      bundle id `com.chandlercollins.No-BS-White-Noise`, SKU whatever you like)
- [ ] **Price: $2.99 (Tier 3)** · Category: Productivity / Health & Fitness
- [ ] Description, subtitle, keywords, promo text → all in APP_STORE_METADATA.md (updated tonight)
- [ ] **What's New** → the v2.1 section (sleep timer, volume, fades, Liquid Glass)
- [ ] Screenshots: upload `Screenshots/6.9-inch/` (01→05 order) and `Screenshots/13-inch/` (iPad)
- [ ] Privacy: "Data Not Collected" (matches the shipped PrivacyInfo.xcprivacy)
- [ ] Age rating 4+ · Review notes: see "App Review Information" section in metadata doc
- [ ] Select the uploaded build → **Submit for Review**

## 5. Optional aftercare
- [ ] Tag the release: `git tag v2.1 && git push origin v2.1`
- [ ] Delete merged branches: `git branch -d real-liquid-glass-and-fixes overnight/launch-prep`
- [ ] Kill the overnight caffeinate: `pkill caffeinate`

## Known follow-ups (not blockers — see IMPROVEMENTS.md)
- Audio-engine refactor plan written (§3.5) — do with v3.0 sound mixing
- Mac support: roadmap ("eventually", your call 2026-07-11)
- Drawer pins Dynamic Type at default size (empirically necessary; VoiceOver fully labeled)
