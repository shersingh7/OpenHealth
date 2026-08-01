# OpenHealth

Private, local-first **health export** for **iPhone and iPad (iOS/iPadOS 17+)**.

OpenHealth does **not** collect your data. You choose what to read from Apple Health and where export files go.

**Repository:** [github.com/shersingh7/OpenHealth](https://github.com/shersingh7/OpenHealth)
**License:** MIT
**Status:** Architecture refresh (2026-08). **Not production-ready** until full Xcode/device gates and personal signing/capabilities are verified on a machine with Xcode.

---

## Implemented

| Capability | Status |
|------------|--------|
| Platforms | iOS / iPadOS 17+ (iPhone + iPad only) |
| HealthKit | Read-only; request after explicit user action |
| Metrics | Quantity + category catalog in Core (count proven by catalog tests, not a marketing “150+”) |
| Special sections | Workouts, workout routes, ECG, activity summaries |
| Formats | CSV, JSON (schema **v1**), GPX (routes only) |
| Destinations | **Local Files**, **iCloud Drive**, **REST API** |
| Automations | Manual / hourly / daily / weekly / monthly — **best-effort** background only |
| Secrets | Keychain references only (`AfterFirstUnlockThisDeviceOnly`) |
| Tests | Foundation-only `OpenHealthCore` MiniXCTest harness (**91** tests) |

## Not in this phase (planned / deferred)

- Google Drive, Dropbox, MQTT, Home Assistant, Calendar (shown as non-selectable “Planned”)
- macOS, visionOS, watchOS, Mac Catalyst app targets
- Widget / App Group
- Exact-time background guarantees
- Writing data to HealthKit
- Medical interpretation or clinical scoring
- Streaming / bounded-memory export (v1 materializes the full snapshot and encoded document in memory)

---

## Privacy-correct Health access

Apple does **not** tell apps whether Health **read** access was granted. OpenHealth shows:

- Health access not requested
- Choose data access in Apple Health
- Health access requested
- Empty results: may mean no data **or** access not granted

It never shows “Read access authorized/denied.”

Workout **routes contain precise location** and default **off**. “All supported” uses the full Core catalog (not a silent detection scan). Explicit selection never exports routes solely because a route toggle is on without workouts/routes in the selection.

---

## Destinations

| Destination | Implemented | Notes |
|-------------|-------------|--------|
| Local Files | Yes | Documents / Files app |
| iCloud Drive | Yes | Requires Apple Developer portal container **`iCloud.com.shersingh7.openhealth`**, matching entitlements, and an on-device iCloud Drive account |
| REST API | Yes | HTTPS; bearer / API key via Keychain; credentialed redirects stay same-origin |
| Google Drive / Dropbox / MQTT / HA / Calendar | No | Planned only; legacy entries migrate **disabled** with warnings |

---

## Automations and background

Background exports use a single `BGAppRefreshTask` identifier (`com.shersingh7.openhealth.refresh`) for the earliest eligible job.

**Execution is best effort.** “Earliest after 2:00” is not a promise of exact fire time. Enable Background App Refresh for better odds; still never guaranteed. The live `AppContainer` attaches to background registration at composition time so a background-only launch can run without the UI appearing. On expiration, the active export task is cancelled and outcomes are recorded.

---

## Memory model (export)

v1 **materializes** the HealthKit snapshot and the encoded export document **fully in memory**, then writes a temporary artifact for delivery. Do not assume streaming or bounded memory for large “All Time” exports.

---

## Requirements

- **Xcode 15+** with iOS 17 SDK for app builds, simulator, and device runs (not available on Command Line Tools–only hosts)
- Apple Developer team for device + HealthKit + iCloud capabilities
- No third-party runtime dependencies

Local signing: set your **Development Team** in Xcode locally. Shared project settings do **not** hard-code a team.

---

## Build & run (Xcode — required for the app)

1. Open `OpenHealth.xcodeproj`
2. Select the **OpenHealth** shared scheme
3. Choose an iPhone/iPad simulator or device
4. Set your Development Team under Signing & Capabilities
5. Ensure HealthKit + iCloud container capabilities match `Resources/OpenHealth.entitlements`
6. Run

These steps have **not** been executed on Command Line Tools–only hosts. Treat them as an explicit external gate.

---

## Tests & local gates (Command Line Tools friendly)

Core logic is Foundation-only and runs without full Xcode:

```bash
# Observed locally: 91 passed, 0 failed, 91 total
swift package clean && Scripts/run_core_tests.sh

# Compile the Core library
swift build --build-system native
```

The package uses an executable MiniXCTest-compatible harness because this development host may have Apple Command Line Tools without the XCTest framework. The shared Xcode scheme / CI simulator job remains the required app-level gate.

### Static and subset checks

```bash
# Production Swift syntax (all App/Core/Infrastructure/DesignSystem/Features sources)
# Prefer an array so paths are not word-split:
bash -c 'files=(); while IFS= read -r f; do files+=("$f"); done < <(find App Core Infrastructure DesignSystem Features -name "*.swift" | sort); xcrun swiftc -parse -sdk "$(xcrun --sdk macosx --show-sdk-path)" -target arm64-apple-macos13 "${files[@]}"'

# Core + HealthKit subset type-check against the local macOS SDK
bash -c 'SDK=$(xcrun --sdk macosx --show-sdk-path); core=(); hk=(); log=(); while IFS= read -r f; do core+=("$f"); done < <(find Core -name "*.swift" | sort); while IFS= read -r f; do hk+=("$f"); done < <(find Infrastructure/HealthKit -name "*.swift" | sort); while IFS= read -r f; do log+=("$f"); done < <(find Infrastructure/Logging -name "*.swift" | sort); xcrun swiftc -typecheck -sdk "$SDK" -target arm64-apple-macos13 "${core[@]}" "${hk[@]}" "${log[@]}"'

# Core + Export + Persistence subset type-check
bash -c 'SDK=$(xcrun --sdk macosx --show-sdk-path); core=(); exp=(); pers=(); log=(); while IFS= read -r f; do core+=("$f"); done < <(find Core -name "*.swift" | sort); while IFS= read -r f; do exp+=("$f"); done < <(find Infrastructure/Export -name "*.swift" | sort); while IFS= read -r f; do pers+=("$f"); done < <(find Infrastructure/Persistence -name "*.swift" | sort); while IFS= read -r f; do log+=("$f"); done < <(find Infrastructure/Logging -name "*.swift" | sort); xcrun swiftc -typecheck -sdk "$SDK" -target arm64-apple-macos13 "${core[@]}" "${exp[@]}" "${pers[@]}" "${log[@]}"'

python3 Scripts/validate_project_references.py
python3 Scripts/check_secrets.py   # prints rule + path only; never secret values
plutil -lint Resources/Info.plist Resources/OpenHealth.entitlements Resources/PrivacyInfo.xcprivacy OpenHealth.xcodeproj/project.pbxproj
python3 -c 'import json,pathlib; [json.load(open(p)) for p in pathlib.Path("Resources/Assets.xcassets").rglob("Contents.json")]'
git diff --check
```

### App icon

Source: `Resources/AppIconSource.svg` (solid fills only; no SVG filters/strokes — ImageMagick-compatible).
Checked-in asset: `Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` (1024×1024, sRGB, opaque).

```bash
# Requires ImageMagick (`magick`). Regenerates PNG + previews and validates pixels/colors.
Scripts/generate_app_icon.sh
```

Previews (not part of the asset catalog): `Resources/icon-previews/`.

### Xcode-only gates (not runnable on CLT-only hosts)

```bash
xcodebuild -project OpenHealth.xcodeproj -scheme OpenHealth \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Plus device HealthKit smoke tests, background-task smoke tests, and archive validation listed in the implementation plan. **These remain explicitly unverified** when full Xcode is absent.

---

## Project layout

```text
App/               Composition root + @main + background registration
Core/              Foundation-only domain (also SwiftPM OpenHealthCore)
Infrastructure/    HealthKit, destinations, Keychain, automation, persistence
DesignSystem/      Theme + components
Features/          Onboarding, Home, Export, Automations, Settings
Resources/         Info.plist, entitlements, privacy manifest, assets, icon source
Tests/             OpenHealthCore MiniXCTest harness (91 tests)
Scripts/           Test runner, project validation, secret scan, icon generation
docs/              Architecture, privacy, export schema, plans
```

---

## Documentation

- [Architecture](docs/architecture.md)
- [Privacy & security](docs/privacy-and-security.md)
- [Export schema v1](docs/export-schema-v1.md)
- [Implementation plan](docs/plans/2026-08-01-openhealth-architecture-ui-overhaul.md)
- [Corrective pass checklist](docs/plans/2026-08-01-openhealth-corrective-pass.md)

---

## Contributing

Keep Core free of UIKit/HealthKit. Prefer protocols and `AppContainer` injection. Do not commit secrets, signing teams, personal data, or generated `.build` artifacts. Do not claim production readiness without Xcode simulator/device verification.
