# Needs Input — decisions for Chandler

Things the overnight loop can't decide, or can't do without you. Each open decision has a
**recommended default** so nothing is blocked — the loop proceeds on the recommendation
and you can override in the morning.

## Open decisions
1. **iPad support for v2.1?** The app is currently Universal (iPhone + iPad,
   `TARGETED_DEVICE_FAMILY = 1,2`).
   - **Recommendation:** ship **iPhone-only** for v2.1 (faster launch, one screenshot set),
     then add polished iPad support in v2.2. The loop will still generate an iPad screenshot
     set so you're covered whichever way you choose.
2. **Feature scope before launch?** The loop is building Tier-1 features (sleep timer,
   fade in/out, volume control) on this branch. If you'd rather launch the current app
   as-is and defer features, say so and they'll be dropped/reverted.

## Requires your Apple ID / account — the loop will NOT do these (for you)
- **App Store Connect:** create/verify the app record, set price to **$2.99**, upload the
  build, submit for review, and TestFlight. All need your Apple ID login.
- Any distribution signing/provisioning that isn't handled automatically by Xcode.

## Blockers logged during the run
_(none yet)_
