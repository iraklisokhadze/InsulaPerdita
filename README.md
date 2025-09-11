# InsCounter

SwiftUI iOS app for insulin dose suggestion, NFC sensor scan scaffold (FreeStyle Libre style), injection & activity logging, and configurable targets.

## Main Features
- Glucose input + trend arrows (simple prediction deltas)
- Recommended insulin dose (rounded to 0.5 units) based on weight, sensitivity, target
- NFC reading scaffold (CoreNFC ISO15693) with placeholder Libre decoder
- Injection logging (day / night) persisted locally
- Ad‑hoc & pre‑registered activities with average effect values
- Unified actions timeline (injections + activities) newest first
- Settings (პარამეტრები) for weight, sensitivity, target
- Georgian UI labels + UbiquitousLanguage.md glossary

## Structure
```
InsCounterApp.swift        # App entry
Views/                     # SwiftUI views
Models.swift               # Data models & persistence helpers
NFCManager.swift           # CoreNFC session handling
LibreSensorDecoder.swift   # Placeholder / scaffold for Libre decoding
Utils.swift                # Formatting & persistence utilities
UbiquitousLanguage.md      # Domain glossary
```

## Build & Run
1. Open `InsCounter.xcodeproj` in Xcode 16+
2. Select a real iPhone device (NFC not available in Simulator)
3. (If team supports) Add Near Field Communication Tag Reading capability
4. Run the app

If using a free personal team, NFC entitlement may be unavailable (session will report not supported).

## Local Persistence
All user data (settings, injections, activities) is stored in `UserDefaults` using versioned keys.

## Roadmap Ideas
- Real Libre frame parsing & calibration
- Carb entry & bolus advisor
- iCloud sync / HealthKit export
- Charts & trends

## License
MIT – see LICENSE.
