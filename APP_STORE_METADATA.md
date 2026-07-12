# App Store Metadata for No-BS White Noise v2.1

## Basic Information

### App Name
**No-BS White Noise**

### Subtitle (30 characters max)
**Fast, focused background noise**

### Bundle ID
`com.chandlercollins.No-BS-White-Noise`

### Version
- **Marketing Version**: 2.1
- **Build Number**: 3

### Privacy Policy URL
Not required (no data collection)

### Categories
- **Primary**: Productivity
- **Secondary**: Health & Fitness

**Rationale**: Positioned as a focus/concentration tool first (inspired by Craig Mod's fast software philosophy), sleep aid second. Productivity category has 2x higher conversion rate (59.7% vs 30.8%) and better aligns with "No-BS" professional branding and Liquid Glass premium design.

### Age Rating
**4+** (No objectionable content)

### Price
**$2.99 (Tier 3)** - One-time purchase

**Rationale** (see [PRICING_ANALYSIS.md](PRICING_ANALYSIS.md) for full analysis):
- Optimal balance: Premium positioning without price resistance
- Market gap: Undercuts $40-70/year subscriptions, 3x premium vs $0.99 commodity apps
- Expected conversion: 40-50% (Productivity category: 59.7% average)
- Revenue per download: $2.09 (after Apple's 30% cut)
- Charm pricing: $2.99 vs $3.00 yields 5-15% conversion boost
- No ads, no in-app purchases, no subscriptions
- Premium pricing justified by: Liquid Glass design, no tracking, professional focus tool

**Alternative scenarios:**
- Conservative: $1.99 (max penetration, -33% revenue per download)
- Aggressive: $3.99 (max revenue, -15% estimated conversion)

---

## App Description (4000 characters max)

White noise that just works. No sign-up, no subscriptions, no BS.

Tap one button and get clean, high-quality background noise for focus, sleep, or calm. Five sounds, one purpose: helping you concentrate.

• White Noise — Classic broadband static
• Brown Noise — Warmer, deeper rumble
• Fire — Crackling fireplace
• Rain — Steady, even rainfall
• Birds — Peaceful forest ambience

WHY IT EXISTS

Most white-noise apps are buried under ads, accounts, paywalls, and pop-ups. This one isn't. It harkens back to a time when an app could do one thing and do it fast. Inspired by Craig Mod's philosophy of fast software, it prioritizes speed and simplicity over feature bloat.

No tracking. No analytics. No ads. No account. Just one fair price.

BUILT FOR iOS 26

Every control is rendered in Apple's real Liquid Glass — the genuine system material, not a lookalike. The play button, sound selector, and menu use live translucency and refraction that respond to light as you move.

DESIGNED TO GET OUT OF YOUR WAY

• Launches instantly and starts with a single tap
• Switches sounds with no glitchy gap
• Runs all night without draining your battery
• Keeps playing in the background and in silent mode
• Full Control Center and Lock Screen playback controls
• Start any sound hands-free with Siri
• Gorgeous in both light and dark mode
• VoiceOver-friendly, accessible controls throughout

PRIVACY BY DEFAULT

The app collects nothing because it is built to collect nothing. No accounts, no network requests, no third-party SDKs, no analytics. Your preferences never leave your device.

Software should lessen burdens, not add to them. This one launches fast, works exactly as expected every time, and gets out of your way so you can focus on what matters.

Built for people who value their time and attention.

---

## Promotional Text (170 characters, updatable without review)

**Now with real iOS 26 Liquid Glass — genuine translucent controls, not a lookalike. Plus Siri, Control Center, and Lock Screen playback. Five sounds, zero BS.**

---

## Keywords (100 characters max, comma-separated)

white noise,brown noise,focus,sleep,study,meditation,rain sounds,fire,relaxation,ambient

---

## What's New in Version 2.1

**Real Liquid Glass, and more ways to play**

• Rebuilt the play button, sound selector, and menu with Apple's genuine iOS 26 Liquid Glass materials
• Start any sound hands-free with Siri
• Control playback from Control Center and the Lock Screen
• Cleaner light and dark themes that match your system on first launch
• Smoother, more responsive controls with accessibility improvements throughout

Same great sounds. Same no-BS philosophy. Now with next-generation design.

---

## App Review Information

### Contact Information
- **Email**: chndlrcllns@gmail.com
- **Phone**: (Provide if required)

### Review Notes

This is a simple white noise app for focus and sleep. No account required.

**How to test:**
1. Tap the large play button to start white noise
2. Tap again to stop
3. Tap the bottom handle to see other sounds
4. Select different sounds (White, Brown, Fire, Rain, Birds)
5. Tap the theme icon (top right) to switch light/dark mode
6. Leave playing overnight to test battery efficiency
7. Test Control Center integration while playing

The app works in silent mode and continues playing in background.
One-time purchase, no subscriptions, no tracking, no account needed.

---

## Screenshots

### iPhone 6.9" (iPhone 17 Pro Max / 16 Pro Max) — READY ✅
- **Resolution**: 1320 x 2868 pixels
- **Location**: [`Screenshots/6.9-inch/`](Screenshots/6.9-inch/)

A finished, captioned 5-shot set is generated and ready to upload:

1. `01_main_light.png` — "White noise that just works" (light)
2. `02_menu_light.png` — "Five clean sounds" (light, sound selector)
3. `03_playing_dark.png` — "One tap. Focus for hours." (dark, playing)
4. `04_menu_dark_fire.png` — "Real Liquid Glass" (dark, Fire selected)
5. `05_main_dark.png` — "No ads. No tracking. No subscriptions." (dark)

App Store Connect requires only the 6.9" set for iPhone; it automatically
down-scales these for 6.7"/6.5" listings, so no separate iPhone sizes are needed.

### iPad (13") — READY ✅
- **Resolution**: 2064 x 2752 pixels
- **Location**: [`Screenshots/13-inch/`](Screenshots/13-inch/)
- Same five concepts as the iPhone set, captured from the iPad Pro 13-inch (M4)
  simulator. Required if the app ships as Universal (it currently does).

**How the screenshots were made / how to regenerate:**
The raw frames are captured from the **iPhone 17 Pro Max** simulator using a
DEBUG-only launch hook (`applyScreenshotStateIfNeeded` in `ContentView.swift`)
that forces a deterministic UI state:

```
# clean status bar
xcrun simctl status_bar "iPhone 17 Pro Max" override --time "9:41" \
  --batteryLevel 100 --batteryState charged --cellularBars 4 --wifiBars 3

# examples — env vars: UITEST_THEME=dark|light, UITEST_MENU=1, UITEST_SOUND=fire, UITEST_PLAYING=1
SIMCTL_CHILD_UITEST_THEME=dark SIMCTL_CHILD_UITEST_MENU=1 SIMCTL_CHILD_UITEST_SOUND=fire \
  xcrun simctl launch "iPhone 17 Pro Max" com.chandlercollins.No-BS-White-Noise
xcrun simctl io "iPhone 17 Pro Max" screenshot raw.png
```

The captions/backgrounds are then composited with `Tools/make_screenshots.py`.

---

## Privacy & Compliance

### Data Collection
**None** - This app does not collect any user data

### Privacy Nutrition Label
- Data Not Collected ✓
- Data Not Linked to You ✓
- Data Not Used to Track You ✓

### Export Compliance
- Uses standard HTTPS encryption only
- No proprietary encryption
- Answer "No" to export compliance questions

### Third-Party Content
- No third-party SDKs
- No analytics frameworks
- No advertising networks
- All audio generated procedurally or from bundled assets

---

## Support & Marketing URLs

### Support URL
`https://github.com/chandlercollins/no-bs-white-noise`

### Marketing URL (optional)
`https://github.com/chandlercollins/no-bs-white-noise`

---

## Copyright
© 2025 Chandler Collins

---

## Build Information

### Archive Location
Regenerate a fresh v2.1 archive before upload (Product → Archive).

### Minimum iOS Version
iOS 18.2 (real Liquid Glass is used on iOS 26+; iOS 18.2–25 fall back to a
translucent-material rendering via `#available` checks)

### Supported Devices
- iPhone (iOS 18.2+)
- iPad (iOS 18.2+)

### Supported Orientations
- **iPhone**: Portrait only
- **iPad**: All orientations (Portrait, Portrait Upside Down, Landscape Left/Right)

---

## Next Steps

1. **Open Xcode**
2. **Window → Organizer**
3. **Select the archive**: NoBS-WhiteNoise-v2.0
4. **Click "Distribute App"**
5. **Select "App Store Connect"**
6. **Choose "Upload"**
7. **Select appropriate signing**
8. **Click "Upload"**
9. **Go to App Store Connect**
10. **Create new app if needed**
11. **Fill in metadata from this document**
12. **Upload screenshots**
13. **Submit for review**

---

## App Store Connect Login
- **Apple ID**: chndlrcllns@gmail.com
- **URL**: https://appstoreconnect.apple.com

---

## Expected Review Time
1-2 business days (typical)

---

## Post-Launch Checklist
- [ ] Monitor App Store Connect for reviewer messages
- [ ] Check email for approval notification
- [ ] Share on social media once approved
- [ ] Monitor reviews and ratings
- [ ] Plan future updates based on feedback
