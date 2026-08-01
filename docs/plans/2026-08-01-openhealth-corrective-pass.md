# OpenHealth Post-Implementation Corrective Pass

**Status:** Completed on 2026-08-01; retained as the verification record for the implemented refactor.

The architecture/UI refactor in `docs/plans/2026-08-01-openhealth-architecture-ui-overhaul.md` already existed when this checklist was executed. Its temporary “do not commit or push” implementation constraint was superseded when the repository owner explicitly authorized the final commit and push. No third-party runtime dependencies or secret values were added.

## P0 — correctness, privacy, and data-loss fixes

1. **Fix the HealthKit authorization API compile failure.** In `Infrastructure/HealthKit/LiveHealthDataSource.swift`, replace the unavailable async call `getRequestStatusForAuthorization(toShare:read:)` with the imported Swift async name `statusForAuthorizationRequest(toShare:read:)`. Repeatedly type-check Core + HealthKit against the local macOS SDK until all actionable errors are gone.
2. **Attach background dependencies before a background launch can fire.** `BackgroundTaskRegistration` must have the live `AppContainer` before registration/launch handling; do not rely only on `ContentView.onAppear` because the UI may never appear during a background-only launch. Keep exactly one live composition root.
3. **Cancel the actual export task on BG expiration.** In `AutomationCoordinator`, store/cancel the real `Task<ExportReport, Never>` (or equivalent), not a wrapper waiting on a separate child task. Preserve cancelled outcome/history and reschedule.
4. **Hydrate missing schedule dates.** Enabled, nonmanual jobs with nil `nextEligibleAt` must get a computed date persisted before reconciliation. A BG refresh must not repeatedly wake and skip such jobs forever.
5. **Make legacy migration non-destructive.** Merge legacy automations with existing v2 entries by ID instead of overwriting the repository. Infer auth before moving tokens. Never remove the legacy blob until every required secret and automation is durably verified. Detect sensitive legacy headers (`Authorization`, API-key headers, etc.) and move them to Keychain or fail safely; never write them to JSON. Unknown/planned destinations must migrate disabled with an explicit warning, not silently become enabled Local Files. Avoid orphaning/loss of legacy Home Assistant/API credentials.
6. **Make destination secret editing transactional.** Validate all nonsecret fields first. Only then save/update/delete Keychain material and commit the destination. Editing an invalid destination then cancelling must not overwrite or delete an existing secret. Removing a destination should delete its referenced secret after confirmation; report deletion failures. Do not create orphan secrets on failed save/cancel.
7. **Respect data selection and location privacy.** `.allDetected` must use detected coverage, or be renamed/copy-changed to “All supported” with truthful behavior. In explicit mode, `includeWorkoutRoutes` must never force workout/location export unless workout/route is selected. Default route export OFF for new users/settings. Make route inclusion deliberate and clearly warn that it contains location.
8. **Harden REST redirects and auth headers.** Reject cross-host/cross-origin redirects when credentials are attached, in addition to HTTPS→HTTP downgrade. Validate auth header names as strictly as custom headers. Never leak endpoints, headers, secrets, or health details to logs.

## P1 — product completeness and truthful UX

9. **Make the automation editor complete.** Let users select data types and add/edit/remove real destinations (Local, iCloud, REST) with the same validated destination UI used by manual export. Show validation errors, run progress, draft result, and run failures. Replace the seven cramped weekday buttons with an adaptive grid or wrapping layout.
10. **Fix coverage caching.** Do not synthesize fake IDs such as `detected.0`. Persist actual detected IDs or a truthful cached count model; Home and Data Coverage must agree after relaunch.
11. **Fix onboarding retry.** A failed HealthKit request must remain visible and retryable; do not auto-dismiss onboarding after failure. A deliberate skip may still finish onboarding.
12. **Remove crashy fallback force-tries.** Replace `try!` repository fallback construction in `AppContainer` with a noncrashing in-memory fallback or a controlled fatal configuration state that displays a recoverable UI. App startup must not crash merely because Application Support/temp storage is unavailable.
13. **Use explicit data protection.** Apply appropriate iOS file protection to automation/history files and exported artifacts. Preserve background usability after first unlock without weakening health exports unnecessarily. Document the trade-off.
14. **Fix plist/privacy truthfulness.** In `Info.plist`, replace invalid `NSUbiquitousContainerSupportedFolderLocations` with supported `NSUbiquitousContainerSupportedFolderLevels` = `Any`; remove `processing` from `UIBackgroundModes` unless a BGProcessing task exists; use one app-prefixed BG identifier consistently. In `PrivacyInfo.xcprivacy`, remove FileTimestamp/SystemBootTime declarations unless code truly calls those APIs; retain UserDefaults CA92.1 as applicable.
15. **Logging privacy.** Change generic localized errors logged with OSLog from `.public` to `.private(mask: .hash)` or log safe error codes only.
16. **Keychain update safety.** Prefer `SecItemUpdate`, adding only when not found, so a failed replacement does not delete the existing secret first.
17. **Clean copy and stale state.** Fix “Private health exports, under you.” to “Private health exports, under your control.” Remove or correctly wire dormant `exportSeed`/quick-export state. Ensure quick export uses valid destination IDs and current defaults.
18. **Documentation honesty.** State that v1 currently materializes the export snapshot/encoded document in memory if true. Do not claim streaming or bounded-memory export until implemented. Document unsupported/planned destination migration and iCloud capability prerequisites.

## Tests and verification

Add meaningful Foundation tests for selection/route privacy, legacy migration helpers where extractable, redirect origin policy, sensitive-header validation, schedule hydration logic, and any new pure logic. Update explicit MiniXCTest registration. Then run:

```bash
Scripts/run_core_tests.sh
swift package clean && Scripts/run_core_tests.sh
swift build --build-system native
python3 Scripts/validate_project_references.py
python3 Scripts/check_secrets.py
plutil -lint Resources/Info.plist Resources/OpenHealth.entitlements Resources/PrivacyInfo.xcprivacy OpenHealth.xcodeproj/project.pbxproj
git diff --check
```

Also run a production-source `swiftc -parse` pass and the local HealthKit subset type-check. Full `xcodebuild` remains blocked only if full Xcode/iOS SDK is absent. Finish with a concise list of changed files, checks, and any explicitly unresolved item.
