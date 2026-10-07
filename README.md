# Likya Batak

Likya Batak is a Flutter-based Turkish Batak card game by Likya Studios.

## Current status

- Distribution: Google Play Closed Testing
- Package: `com.likyastudios.likyabatak`
- Playable modes: İhaleli Batak, Eşli Batak, Koz Maça
- Gömmeli Batak: YAKINDA
- Çevrimiçi Batak: YAKINDA

## Important repository note

Before implementing the next release patches, this repository must be synchronized with the latest production project on the development PC:

`C:\Users\erkan\likya_batak_new`

The local production project is the source of truth for the closed-test build. Do not patch an older GitHub baseline.

Never commit:

- `.jks` / `.keystore`
- `android/key.properties`
- `.env`
- credentials / service-account files
- build outputs
- private signing material

## Next release

Target: **Likya Batak 1.2.1**

Canonical patch plan:

[`LIKYA_BATAK_1_2_1_ROADMAP.md`](./LIKYA_BATAK_1_2_1_ROADMAP.md)

Current planned sequence:

1. V2-016 Fast Play + Bid UI + HUD Cleanup
2. V2-017 Eşli Batak bidder-controlled exposed partner hand
3. V2-018 AdMob Production + UMP + Privacy
4. V2-019 Billing / VIP Restore + Save Upgrade
5. V2-020 Android Hardening + Responsive
6. V2-021 Final 1.2.1 Release Gate

Each patch should be isolated, tested, and committed separately.

## Core release constraints

Do not unintentionally change:

- package/applicationId
- signing identity
- authoritative GameEngine legality
- existing scoring rules
- AI hidden-information policy
- premium card artwork
- save/resume compatibility
- unfinished Gömmeli/Online availability
