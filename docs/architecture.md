# OpenHealth Architecture

## Scope

OpenHealth is an **export operations** app for **iPhone and iPad on iOS/iPadOS 17+**. It reads Apple Health data the user allows and writes export artifacts to user-chosen destinations. It does not provide medical advice, write to HealthKit, or ship macOS/visionOS/watchOS targets in this phase.

## Dependency flow

```text
SwiftUI Features → MainActor View Models → Use Cases / Coordinators
        ↓                                         ↓
   OpenHealthCore (Foundation-only)     Infrastructure adapters
        ↑                                         ↓
   Protocols & pure logic          HealthKit / Keychain / BGTasks / Files / Network
```

**Rule:** `Core` imports Foundation only. `Infrastructure` depends on Core types. Features depend on protocols and coordinators, not concrete HealthKit/Keychain types. `AppContainer` is the only composition root for live dependencies.

## Modules

| Area | Role |
|------|------|
| `Core/` | Models, protocols, schedule math, path/URL validation, CSV/JSON/GPX encoders, export pipeline coordinator |
| `Infrastructure/` | Live HealthKit source, destinations, Keychain, JSON repos, migration, automation coordinator, logging |
| `DesignSystem/` | Theme tokens and reusable SwiftUI components |
| `Features/` | Onboarding, Home, Export builder, Automations, Settings |
| `App/` | `AppContainer`, tabs, `@main`, background task registration |

## Single dependency graph

`AppContainer.live()` constructs exactly one of each:

- `LiveHealthDataSource` (+ shared `HKHealthStore`)
- `ExportPipeline` with Local / iCloud / REST clients
- `JSONAutomationRepository` / `JSONExportHistoryRepository` (or non-crashing in-memory fallbacks if storage is unavailable)
- `KeychainSecretStore`
- `UserDefaultsSettingsStore`
- `AutomationCoordinator` + `BGTaskSchedulerClient` + `NotificationClient`

The live container attaches itself to `BackgroundTaskRegistration` at composition time so background-only launches can run without UI. Views and view models receive protocols/use cases via the container. They must not call `HealthKitService()`-style constructors or use a global scheduler singleton.

## HealthKit read access

Apple does **not** reveal whether read access was granted. The app models:

- Health data availability
- Request state (`notRequested` / `requestRecommended` / `previouslyRequested` / `unavailable`)
- Last request timestamp

UI copy never says “Authorized” or “Denied” for read types. Empty query results are treated as ambiguous.

## Export pipeline

1. Validate request and destinations
2. Resolve date interval (start inclusive, end exclusive)
3. Resolve metric selection (`allDetected` is **all supported** catalog types; explicit IDs never expand to routes solely from a toggle)
4. Read requested metrics (bounded concurrency)
5. **Materialize the full export snapshot and encoded document in memory**, then write once to a temporary artifact (JSON schema v1 / CSV sections / GPX). v1 does **not** stream or bound memory for large exports.
6. Deliver the same artifact to each destination
7. Persist operational history (counts/status only)
8. Report complete / partial / failed / cancelled

Serialized `totalRecords` is always derived from written sections.

## Automations

One repository and one coordinator own save/load/run/background paths. Background scheduling maintains **one** pending `BGAppRefreshTaskRequest` for the earliest eligible job. Timing is **best effort** (`earliestBeginDate` is not a guarantee). Enabled non-manual jobs with a missing `nextEligibleAt` are hydrated before reconciliation so BG refresh does not wake and skip forever.

## Secrets

Destination tokens live only in Keychain (`AfterFirstUnlockThisDeviceOnly`). Codable models store `SecretReference` IDs only. Legacy `UserDefaults` automations merge into Application Support JSON + Keychain by ID. Sensitive legacy headers are moved to Keychain or dropped safely—never written to JSON. Unknown/planned destinations migrate **disabled** with an explicit warning (they do not become enabled Local Files).

## Destinations

| Kind | Status |
|------|--------|
| Local Files | Implemented |
| iCloud Drive | Implemented (requires iCloud capability + container `iCloud.com.shersingh7.openhealth` in the Apple Developer portal and on-device iCloud Drive) |
| REST API | Implemented (HTTPS; credentialed redirects stay same-origin) |
| Google Drive, Dropbox, MQTT, Home Assistant, Calendar | Planned only — not selectable for new configs; legacy entries migrate disabled |

## File protection

Automation, history, and export artifacts use **complete protection until first user authentication** so best-effort background work can run after first unlock without leaving health-related files fully unprotected before unlock. Trade-off: files are inaccessible before first unlock after boot (acceptable for this product).

## Testing

Foundation-only logic is covered by the `OpenHealthCore` package / executable test harness (`Scripts/run_core_tests.sh`). Full Xcode iOS Simulator builds and on-device HealthKit tests are separate gates.
