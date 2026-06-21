# Kontiva for iOS

The iPhone app. A touch-native UI on top of the shared **[KontivaKit](../KontivaKit)**
engine (domain model, cryptography, encrypted storage) — the same proven core that
powers the macOS app.

- **iPhone first** (iPad later, as its own workspace).
- **iOS 26+**, SwiftUI, Swift 6.
- Bundle id: `ch.kontiva.ios`.
- Privacy-first: fully local, no networking, AES-256-GCM at rest, no passphrase recovery.

## Project generation (XcodeGen)

The `.xcodeproj` is **generated** from `project.yml` — it is not committed. To create
or refresh it:

```sh
brew install xcodegen          # one-time
xcodegen generate              # writes Kontiva.xcodeproj
open Kontiva.xcodeproj
```

`project.yml` references KontivaKit by relative path (`../KontivaKit`), so keep the
two repos as siblings:

```
~/kontiva/        macOS app (frozen — never touched by iOS work)
~/KontivaKit/     shared engine (SwiftPM)   ← this app depends on it
~/kontiva-ios/    this app
```

## Status

Skeleton: lock screen · onboarding (vault creation) · empty `TabView` shell, all
wired to the real encrypted store. Screen ports (Übersicht, Planung, Rechnungen,
Sparen, Schulden, Insights, Settings, Report) follow.
