# V2-018 AdMob release configuration

The Android release build requires the real Likya Batak AdMob App ID and banner ad unit ID. Neither ID was present in the repository during V2-018 development. Supply them without committing them:

```powershell
flutter build appbundle --release `
  --dart-define=ADMOB_APP_ID_ANDROID=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY `
  --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ
```

Replace the placeholders with IDs copied from the existing AdMob account. The build rejects missing IDs, malformed IDs, and Google's sample publisher ID. Debug builds use Google's official test App ID and test ad units. The optional `ADMOB_INTERSTITIAL_ANDROID` define enables production interstitials; without a verified production ID, the release build does not request interstitials.

At startup, UMP updates consent information and shows a required form before the first ad request. A failed consent request leaves the game usable and requests no ad unless UMP reports that ads can be requested. The Settings dialog shows privacy options only when UMP requires them and always links to the [privacy policy](https://likyabatak.netlify.app/privacy/).

VIP status must finish loading before any ad request. VIP players do not load or display banners or interstitials.
