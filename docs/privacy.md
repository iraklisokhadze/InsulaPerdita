---
title: Privacy Policy
layout: default
---
# Privacy Policy

Effective date: {{ site.time | date: '%Y-%m-%d' }}

## 1. Summary
InsulaPerdita stores your glucose, insulin, activity, and configuration data **locally on your device only**. No data is transmitted to external servers by the app itself.

## 2. Data Collected
Stored locally (in app storage / UserDefaults / in-memory models):
- Glucose entries you manually enter or derive from NFC sensor scans
- Insulin dose recommendations you confirm (and logged injections)
- Activities you add (title, intensity, timestamp)
- Configuration: weight, sensitivity factors, targets
- Basic derived values (e.g., insulin on board, trend estimations)

Not collected:
- Account identifiers
- Location
- Advertising identifiers
- Background network telemetry

## 3. Local Processing Only
All calculations (dose suggestions, sensitivity adjustments, trend estimation) happen on-device. If you back up your device (iCloud / Finder), encrypted backups may include this data under Apple’s platform rules.

## 4. Health Data (Future / Optional)
Planned (not yet active) integrations with HealthKit will:
- Require explicit user consent
- Write only glucose and insulin related records you approve
- Never read unrelated HealthKit categories
This policy will be updated before HealthKit export is enabled.

## 5. NFC Usage
NFC is used solely to attempt reading compatible glucose sensor tag payloads. The app does not retain raw tag UID beyond immediate decoding; only interpreted glucose values (if any) are stored locally.

## 6. Analytics & Tracking
No third‑party analytics SDKs, crash reporters, or advertising frameworks are embedded.

## 7. Data Sharing
The app does not share or upload your data. Any sharing (screenshots, exported logs) is a manual action you perform.

## 8. Permissions
- NFC: Required for sensor scanning. Declining disables scanning only.
- (Future) HealthKit: Optional and request-based.

## 9. Security Measures
- Relies on iOS sandbox and file system protections.
- No custom encryption layer presently; device passcode / FaceID recommended.
- Future roadmap may add optional encrypted export.

## 10. Children
Not directed to children. Users should consult a qualified healthcare professional for dosing decisions; results are advisory only.

## 11. TestFlight / Beta Builds
Beta builds may log additional diagnostic messages **locally** for troubleshooting. If you email logs, review and redact any personal health information before sharing.

## 12. Your Choices
- Delete data: Remove the app (iOS deletes its sandbox). Reinstall produces a clean state.
- Reset configuration: Use in-app settings (if provided) or delete/reinstall.
- Export (future): A planned feature to export anonymized CSV.

## 13. Policy Changes
Material changes will update this document. Continued use after an update indicates acceptance of revised terms.

## 14. Contact
Open a GitHub Issue (do not include personal identifiers or unredacted medical data) or provide feedback via the repository discussions.

---
_Last updated: {{ site.time | date: '%Y-%m-%d' }}_
