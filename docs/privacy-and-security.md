# Privacy and Security

## Product statement

**OpenHealth does not collect your data.** Health samples stay on device unless **you** export them to a destination you configure (Local Files, iCloud Drive, or a REST endpoint you control).

Do **not** claim that data is “never shared” while REST export is available—user-directed export is intentional sharing to *their* endpoint, not developer collection.

## HealthKit

- Read-only access.
- Permission is requested only after explicit user action (onboarding CTA or Settings).
- Read authorization is **not** shown as granted/denied (Apple API limitation).
- No HealthKit background delivery entitlement is claimed when disabled.
- Workout **routes contain precise location** and default **off**. Explicit data selection never exports routes unless workouts/routes are selected (or routes are part of “all supported” with the route toggle on).

## Destinations

| Destination | Data path |
|-------------|-----------|
| Local Files | App Documents / Files app |
| iCloud Drive | User’s iCloud container `iCloud.com.shersingh7.openhealth` (must exist in the Apple Developer portal; iCloud Drive must be signed in) |
| REST API | HTTPS upload to user-configured endpoint |

Planned destinations (Google Drive, Dropbox, MQTT, Home Assistant, Calendar) are not selectable. Legacy planned/unknown destinations migrate **disabled** with warnings; credentials move to Keychain when possible and are never left in JSON.

## Secrets

- Bearer tokens and API keys are stored in the **Keychain**.
- Accessibility: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` so best-effort background exports can run after first unlock.
- Secrets are never written to `UserDefaults`, JSON automation files, logs, or notifications.
- Editing a masked secret field without changes does not overwrite Keychain values.
- Destination editors validate non-secret fields first, then stage secret writes/deletes in a `StagedSecretStore`. Keychain is committed only when the parent automation is **Saved**. Cancelling the parent automation (or dismissing without save) **discards** staged mutations so existing credentials are not corrupted and new secrets are not orphaned. Commit receipts provide compensating rollback if durable automation persistence fails after a Keychain mutation; partial Keychain commits are also restored before an error is surfaced.
- Manual export holds credentials in the same staging layer for the session and feeds them to a pipeline that reads the stage; ephemeral export destinations do not permanently litter Keychain on abandon.
- Keychain updates prefer `SecItemUpdate`, adding only when not found, so a failed replacement does not delete the existing secret first.
- Removing a destination stages secret deletion (automation) or removes staged material (export); confirmed automation save also prunes secrets no longer referenced by any automation. Deletion failures are reported.

## Files and history

- Configuration and automation state: Application Support (atomic writes, excluded from backup when appropriate).
- File protection: `completeUntilFirstUserAuthentication` for automation/history files and exported artifacts — usable after first unlock for background export; not readable before first unlock after boot.
- Export history: operational metadata only (counts, outcome, destination status)—**not** duplicated health samples.
- Temporary encode artifacts are written under a protected temp directory.
- **v1 materializes the export snapshot and encoded document fully in memory** before writing. Streaming / bounded-memory export is not implemented.

## Networking (REST)

- HTTPS required in release builds.
- Loopback HTTP only behind an explicit DEBUG allow-list.
- Ephemeral `URLSession` (no cookie/cache credential persistence).
- HTTPS→HTTP redirects rejected.
- When credentials are attached, **cross-host / cross-origin redirects are rejected**.
- Custom headers and API-key header names share strict validation; reserved headers (`Host`, `Content-Length`, `Authorization`, `Content-Type`) cannot be overridden.
- Logs never include Authorization headers, endpoints with credentials, response bodies, or health values. Generic errors use private/hashed privacy markers.

## Logging

Production code uses `OSLog` / `Logger` with privacy markers. Prefer operational counts over identifiers. Localized error strings are logged with `.private(mask: .hash)` (or safe codes only).

## Privacy manifest

`Resources/PrivacyInfo.xcprivacy` declares:

- No tracking
- No collected data types (developer does not collect)
- Required-reason API usage for UserDefaults (CA92.1) only, as applicable

File timestamp and system boot time APIs are **not** declared unless/until code truly calls them.

App Store privacy questionnaire answers must still be reviewed before release.

## Notifications

Requested only when the user enables completion notifications. Bodies never include destination URLs, filenames, health types, or health values.

## Background execution

Background App Refresh / `BGTaskScheduler` execution is **best effort**. The UI must describe “earliest after …” timing, never exact schedules. Background task dependencies attach at composition root (not only UI appear). Expiration cancels the active export task; cancelled outcomes are recorded and jobs reschedule.
