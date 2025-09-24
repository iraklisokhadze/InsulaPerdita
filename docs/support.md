---
title: Support
layout: default
---
# Support

## Contact
<p><a href="mailto:irakli.sokhadze@outlook.com?subject=InsulaPerdita%20Support%20Request&body=Device%20Model:%0AiOS%20Version:%0AApp%20Build:%0ASteps%20to%20Reproduce:%0AExpected%20Result:%0AActual%20Result:%0A" style="display:inline-block;padding:0.6em 1em;background:#0366d6;color:#fff;border-radius:6px;text-decoration:none;font-weight:600;">Email Support</a></p>
<small>If the button does not work, email: <a href="mailto:irakli.sokhadze@outlook.com">irakli.sokhadze@outlook.com</a></small>

## Getting Help
Open a GitHub Issue with:
- App version / build number
- Device model & iOS version
- Steps to reproduce
- Expected vs actual result
- (Optional) Screenshots or short video

## Common Issues
### NFC Not Available
- Use a real iPhone (Simulator lacks NFC)
- Ensure Near Field Communication Tag Reading capability is enabled
- If entitlement mismatch: Clean build, re-add capability, rebuild

### Provisioning / Signing
- Update bundle identifiers to a unique reverse-DNS string you control
- Ensure the NFC entitlement (TAG) exists in the provisioning profile

### Data Not Persisting
- Confirm storage keys not changed between launches
- Delete and reinstall if schema was altered during development

## Feature Requests
Create an Issue labeled enhancement describing the use case and expected impact.

## Security / Privacy
Do not post personal health data publicly. Redact sensitive info before attaching logs.

## Roadmap (High-Level)
- Real Libre sensor frame parsing
- Carb entry & bolus advisor
- HealthKit integration (export)
- Charts & historical trends

---
_Last updated: {{ site.time | date: '%Y-%m-%d' }}_
