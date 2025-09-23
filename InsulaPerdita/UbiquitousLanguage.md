# Ubiquitous Language Glossary (InsulaPerdita)

Last updated: 2025-09-12

## Core Physiological Concepts
- Sugar Level (შაქრის დონე): Current blood glucose entered manually or from NFC sensor (mmol/L).
- Target (სამიზნე): Desired glucose level defined in settings.
- Sugar Difference: max(0, current − target); amount above target shown beside target.
- Predicted Glucose: Current Sugar Level plus Trend prediction delta; basis for correction decision.
- Recommended Dose (რეკომენდირებული დოზა): Suggested correction insulin units (rounded to 0.5) computed from Predicted Glucose vs Target.
- Daily Dose (internal): weight * sensitivity.factor (proxy for total daily insulin to derive ISF).
- ISF (Insulin Sensitivity Factor): 1800 / Daily Dose (used in dose calculation logic).
- Sensitivity (მგრძნობიარობა): User-selected insulin response level (low / medium / high) affecting factor.

## Sensitivity Levels
- Low (დაბალი): factor 1.0 (least sensitive → larger calculated daily dose proxy).
- Medium (საშუალო): factor 0.7 (default).
- High (მაღალი): factor 0.4 (most sensitive → smaller daily dose proxy).

## Trend Model
- Trend: Directional glucose movement category (north, northEast, east, southEast, south).
- Trend Symbol: SF Symbol arrow associated with Trend.
- Prediction Delta: Fixed adjustment ( +100, +50, 0, -50, -100 ) added to current glucose to form Predicted Glucose.

## Insulin Injections
- Injection (ინექცია): Logged insulin administration event.
- Injection Period: Time classification (daytime "დღის" / nighttime "ღამის"), shown with sun/moon icons only.
- Injection Action: Record { id, date, period, dose } persisted.
- Injection Dose Input: Non-keyboard stepper style (− / current / +) centered; steps in 0.5 units. Initial value = Recommended Dose if available, else 0.5. Min fixed 0.5. Max = half of computed Daily Dose (or falls back to Recommended Dose / 0.5 if weight unknown).

## Activities (Ad‑hoc)
- Activity (აქტივობა): Quick user-defined contextual effect created inline and stored with its own timestamp (createdAt) so it appears directly in the unified actions list.
- Average Effect (საშალო გავლენა): Discrete expected directional influence value (−150, −100, −50, +50, +100, +150) displayed as colored badge (negative red, positive green, zero gray).

## Pre‑Registered Activities
- Registered Activity (შენახული აქტივობა): Reusable catalog entry { id, title, averageEffect } managed in a dedicated sheet; not itself an action until invoked.
- Registered Activity Action: Instance of usage { id, date, activityId } referencing a Registered Activity; added to actions timeline when selected.

## Unified Actions
- Unified Action (ისტორიის ჩანაწერი): Normalized representation of any timeline item (Injection, Ad‑hoc Activity, Registered Activity Action) with fields { id, date, icon, tint, primaryLine, secondaryLine }.
- Ordering: All items merged and sorted descending by date to form the unified history list (latest first).

## NFC / Sensor
- NFC Sensor (NFC სენსორი): UI section enabling FreeStyle Libre–style scan.
- Scan Button (სკანირება): Starts NFC tag reading session.
- Last Reading (ბოლო სენსორი): Most recent sensor glucose value decoded (placeholder until full decoder implemented).
- NFC Error Message: User-visible reason for scan/session failure or unavailability.

## Persistence Keys
(Currently used in views; note some naming inconsistency vs Models constants—standardize later.)
- weight: User weight (string) via AppStorage.
- sensitivity: Sensitivity storage token ("low" | "medium" | "high").
- target: Target glucose level (string) via AppStorage.
- injectionActions.v1: JSON array of InjectionAction.
- ActivitiesStore.v1: JSON array of ad‑hoc Activity.
- RegisteredActivities.v1: JSON array of RegisteredActivity (pre‑registered catalog).
- ActivityActions.v1: JSON array of ActivityAction (instances referencing RegisteredActivity).

(Models.swift also defines alternative constant names: RegisteredActivitiesStore.v1 / ActivityActionsStore.v1; reconcile in future refactor.)

## UI (Localized Georgian Labels)
- სამიზნე: Target prefix.
- წონა: Weight.
- მგრძნობიარობა: Sensitivity label.
- რეკომენდირებული დოზა: Recommended dose caption.
- შეიყვანეთ მნიშვნელობები: Placeholder until valid sugar input.
- დრო: Time section header (in injection sheet).
- დოზა: Dose section header (in injection sheet).
- ახალი აქტივობა: Add activity sheet title.
- რედაქტირება: Edit sheet title.
- შენახვა / განახლება / გაუქმება / დახურვა: Save / Update / Cancel / Close actions.
- დასახელება: Activity title field placeholder.
- საშალო გავლენა: Average effect picker header.
- აქტივობები ჯერ არ არის: Empty registered activities list placeholder.
- ისტორია: Unified history list header (was მოქმედებები).

## Suggested Short Prompt Handles
- current_glucose → Sugar Level
- predicted_glucose → Predicted Glucose
- target_glucose → Target
- rec_dose → Recommended Dose
- sensitivity_level → Sensitivity
- trend_direction → Trend
- activity_effect → Average Effect
- injection_log → Injection Actions
- registered_activity → Registered Activity
- registered_activity_action → Registered Activity Action
- unified_history → History list
- nfc_reading → Last Reading

## Assumptions
- Glucose values & deltas currently share unit semantics; detailed mmol/L conversions TBD.
- 1800 rule applied directly; adjust for strict mmol/L frameworks if needed.
- Activity/Registered Activity effects presently informational (no algorithmic adjustment to dose yet).

## Change Log
- 2025-09-12: Renamed actions list label from მოქმედებები to ისტორია (History) across UI & glossary.
- 2025-09-11: Added pre‑registered activities, registered activity actions, unified actions list, stepper injection dose UI, updated persistence keys, clarified naming inconsistencies.
- 2025-09-09: Initial glossary extracted from codebase components.
