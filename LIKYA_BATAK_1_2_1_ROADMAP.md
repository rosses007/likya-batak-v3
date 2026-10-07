# Likya Batak 1.2.1 Roadmap

This document is the canonical patch plan for the next closed-test update.

## Current release state

- App: Likya Batak
- Package: `com.likyastudios.likyabatak`
- Distribution: Google Play Closed Testing
- Target next version: `1.2.1`
- Target next versionCode: `5` **only if Play Console confirms 5 is the next unused code**
- Current GitHub repository must be synchronized from the latest local production project before code patches begin.

## Baseline sync gate

Source of truth on the development PC:

`C:\Users\erkan\likya_batak_new`

Before any code patch:

- confirm `pubspec.yaml`
- confirm `git log -5 --oneline`
- confirm `git status`
- confirm package/applicationId `com.likyastudios.likyabatak`
- confirm minSdk 24+
- confirm the source matches the build currently used for closed testing
- sync the current source to GitHub
- never commit build outputs or signing/private files

Do not commit:

- `.jks`
- `.keystore`
- `android/key.properties`
- `.env`
- credentials/service-account files
- build outputs
- private signing material

---

## V2-016 | Fast Play + Bid UI + HUD Cleanup

Priority: first code patch after baseline sync.

### Fast card play

All three playable modes:

- İhaleli Batak
- Eşli Batak
- Koz Maça

Requirements:

- one legal tap plays the card immediately
- remove selected-card lift/enlarge behavior
- no second tap
- no Es Geç/Skip during trick play
- PAS exists only during bidding
- rapid repeated taps cannot create duplicate plays
- invalid-card tap must not mutate state
- no skipped turn / ghost move
- reduce unnecessary input latency
- do not change AI decisions or scoring

### Bidding UI

- PAS must be clearly visible
- PAS must be at the top of the bidding panel
- PAS tap target must be large
- numeric bid legality remains unchanged

### HUD cleanup

Remove unwanted top-table information corresponding to:

- Koz
- Kara
- Kaç çıktı

Keep only information that is genuinely useful during play.

### Card sizing

- cards may be moderately larger
- preserve premium V2-011 artwork
- preserve stacked hand layout
- 13 cards: 8 + 5
- 16 cards: 8 + 8
- no overflow at 344 / 390 / 430 px widths

### Validation

- flutter analyze
- full flutter test
- rapid tap regression
- invalid move regression
- save/resume regression
- bot lifecycle regression
- visual checks on small/normal Android widths

---

## V2-017 | Eşli Batak bidder-controlled exposed partner hand

This patch changes partner-mode game flow and must remain isolated from V2-016.

Requirements:

- auction winner leads the first card
- after auction, bidder's partner hand becomes visible/open
- bidder controls their own hand normally
- when partner's turn arrives, bidder selects the legal card from partner's exposed hand
- partner AI must not independently choose a card
- opponents continue normally
- legal move rules apply to exposed partner hand exactly as they do to any active hand
- team scoring must not change
- save/resume must persist and restore the exposed-hand/control state
- AI hidden-information policy must remain intact

Required regressions:

- bidding winner lead
- turn order
- exposed partner hand legality
- team scoring
- save/resume
- round completion
- restart/resume during partner turn

---

## V2-018 | AdMob Production + UMP + Privacy

### AdMob

The previously inspected release contained Google's sample AdMob App ID.

Before production/next closed-test build:

- use the real Likya Batak AdMob App ID in release
- verify the production banner ad-unit ID
- debug/test builds may use Google demo IDs or explicit test-device configuration
- release build must reject demo/sample IDs

If production IDs are unavailable, stop and request them. Never invent IDs.

### UMP consent

- request consent information update at app start
- resolve consent before requesting ads
- show required consent form
- use `canRequestAds` / equivalent supported flow
- consent failure must not freeze the game
- show "Gizlilik Seçenekleri" in Settings when required

### Privacy

Add accessible Settings entry:

- Gizlilik Politikası
- https://likyabatak.netlify.app/privacy/

VIP users must not request/show banners.

---

## V2-019 | Billing / VIP Restore + Save Upgrade

Verify Google Play Billing lifecycle:

- purchase stream handling
- pending purchase state
- completePurchase / acknowledgment
- restorePurchases
- reinstall then restore
- cancelled subscription eventually removes VIP entitlement
- no duplicate completion
- no ad load for active VIP

Save/resume upgrade:

- existing saved game from the closed-test build opens in 1.2.1
- schema-version handling remains backward compatible
- no double scoring after resume
- no lost played-card history

---

## V2-020 | Android Hardening + Responsive

- disable unnecessary cleartext traffic if verified safe
- targetSdk 36 edge-to-edge/insets validation
- predictive/back gesture behavior
- adaptive icon
- Android 13+ monochrome icon
- decide portrait-only vs supported landscape/tablet behavior
- test 5-inch / 344 px class width
- test 390 and 430 px widths
- test increased fontScale
- ensure banner and hand cards do not collide with gesture/navigation insets

---

## V2-021 | Final 1.2.1 Release Gate

Only after V2-016 through V2-020 pass.

Release checks:

- confirm exact next unused versionCode in Play Console
- set version `1.2.1+<nextCode>`
- flutter clean
- flutter pub get
- flutter analyze
- flutter test --concurrency=1
- full AI/game simulation suite
- no illegal move
- no duplicate card
- no deadlock
- no scoring mismatch
- save/resume pass
- billing/ad privacy checks pass
- build signed release AAB
- verify package ID
- verify minSdk
- verify signature
- calculate SHA256
- upload to Google Play Closed Testing
- real-device smoke test after Play Store install

---

## Deferred / next versions

Not blockers for 1.2.1 unless a regression is discovered:

- verify whether legacy 184x252 card PNGs are still used; remove them if dead assets
- optimize large image assets/WebP where useful
- crash reporting integration
- How to Play / game rules screens
- local statistics / achievements
- iOS/App Store work
- production Online mode
- production Gömmeli Batak

Gömmeli and Online remain **YAKINDA** until their respective rules/backend are production-ready.

---

## Non-negotiable safety constraints

Do not accidentally change:

- package/applicationId
- signing identity
- working scoring rules
- authoritative GameEngine legality
- AI hidden-information policy
- premium card artwork
- save/resume compatibility
- unfinished Gömmeli/Online availability

Every patch should be committed separately after tests pass so regressions can be isolated.
