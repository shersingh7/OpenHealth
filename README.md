# OpenHealth

<div align="center">
  <h3>Free & Open Source Health Data Export App</h3>

  <p>Export your Apple Health data to anywhere - No account required, no data collection, no paywall.</p>

  <p>
    <a href="#features">Features</a> •
    <a href="#installation">Installation</a> •
    <a href="#usage">Usage</a> •
    <a href="#automations">Automations</a> •
    <a href="#contributing">Contributing</a> •
    <a href="#license">License</a>
  </p>

  <p>
    <img src="https://img.shields.io/badge/Platform-iOS%20%7C%20iPadOS%20%7C%20macOS%20%7C%20visionOS-blue" alt="Platform">
    <img src="https://img.shields.io/badge/iOS-17%2B-green" alt="iOS 17+">
    <img src="https://img.shields.io/badge/License-MIT-yellow" alt="License: MIT">
    <img src="https://img.shields.io/badge/Status-Alpha-orange" alt="Status: Alpha">
  </p>
</div>

---

## Features

### 📊 Export 150+ Health Metrics

Export all your Apple Health data including:
- **Activity**: Steps, distance, active energy, VO2 Max, flights climbed
- **Cardiovascular**: Heart rate, resting heart rate, HRV, blood pressure, ECG
- **Body Measurements**: Weight, height, BMI, body fat percentage
- **Mobility**: Walking speed, step length, asymmetry, running metrics
- **Respiratory**: Breathing rate, blood oxygen (SpO2)
- **Sleep**: Sleep analysis, breathing disturbances
- **Nutrition**: Dietary tracking (carbs, protein, vitamins, etc.)
- **Workouts**: Full workout data with GPS routes (GPX export)
- **Symptoms**: Coughing, fever, headache, and more
- **State of Mind**: Mental health tracking data
- **Notifications**: Heart rate alerts, irregular rhythm

### 🔄 One-Tap "Export All"

New! Export **all** your health data types with a single toggle. No more manually selecting each type:
- All 87+ quantity types
- All category types (sleep, symptoms, etc.)
- Workouts with routes
- ECG readings
- Activity summaries (Apple Watch rings)

### 📁 Export Formats

| Format | Description |
|--------|-------------|
| **CSV** | Spreadsheet-compatible, great for data analysis |
| **JSON** | Structured format with nested data, ideal for developers |
| **GPX** | GPS Exchange Format for workout routes |

### 🚀 Export Destinations

- ✅ **Local Files** - Save to your device
- ✅ **iCloud Drive** - Auto-sync across all Apple devices
- ✅ **REST API** - Send to any custom endpoint
- ⏳ **Google Drive** - Coming soon
- ⏳ **Dropbox** - Coming soon
- ⏳ **MQTT** - Coming soon
- ⏳ **Home Assistant** - Coming soon

### ⏰ Background Automations (NEW!)

Set it and forget it:
- ✅ Schedule automatic exports (hourly, daily, weekly, monthly)
- ✅ Background execution - works even when app is closed
- ✅ iCloud destination with custom folder paths
- ✅ Local notifications on completion/failure
- ✅ Execution history and retry logic
- ✅ "Test Now" button to verify configuration

### 🔒 Privacy First

- **No account required** - Just install and use
- **No data collection** - Your health data stays on your device
- **No third-party sharing** - You control where data goes
- **Open source** - Audit the code yourself
- **Self-hostable** - Export to your own servers

---

## Installation

### Requirements

- iOS 17.0+ / iPadOS 17.0+ / macOS 14.0+ / visionOS 1.0+
- Xcode 16.0+ (for development)
- Apple Developer account (for device testing)

### From Source

1. **Clone the repository**
   ```bash
   git clone https://github.com/shersingh7/OpenHealth.git
   cd OpenHealth
   ```

2. **Open in Xcode**
   ```bash
   open OpenHealth.xcodeproj
   ```

3. **Configure Signing**
   - Select the "OpenHealth" target in Xcode
   - Under "Signing & Capabilities", select your development team
   - Add the HealthKit capability
   - Add Background Modes capability (check "Background fetch" and "Background processing")

4. **Build & Run**
   - Select your device or simulator
   - Press `Cmd+R` to build and run

### App Store

Coming soon!

---

## Usage

### First Launch

1. **Grant HealthKit Access**: OpenHealth will request access to your health data. Select the data types you want to export.

2. **Dashboard**: View your health metrics at a glance - steps, heart rate, recent workouts, and available data types.

3. **Export**: Tap the Export tab to create your first export.

### Creating an Export

**Quick Export (All Data):**
1. Toggle **"Export All Health Data"**
2. Select **Date Range** (e.g., "Yesterday", "Last 7 Days")
3. Select **Format** (JSON recommended for complete data)
4. Select **Destination** (iCloud Drive recommended)
5. Tap **Export Now**

**Custom Export:**
1. Leave "Export All Health Data" disabled
2. Tap **Data Types** to select specific metrics
3. Configure date range, format, and destination
4. Tap **Export Now**

### Setting Up Automations

1. Go to the **Automations** tab
2. Tap **+** to create a new automation
3. Configure:
   - **Name**: e.g., "Daily Health Export"
   - **Schedule**: Set frequency (daily recommended) and time
   - **Export Settings**: Toggle "Export All Health Data" for complete exports
   - **iCloud Destination**: Set folder path (e.g., `OpenHealth/DailyExports`)
4. Tap **"Test Now"** to verify the configuration
5. Toggle **"Enabled"** and tap **Save**

The automation will now run automatically in the background according to your schedule!

---

## Automations

### How It Works

OpenHealth uses iOS Background Tasks (`BGTaskScheduler`) to run exports automatically:

1. **Scheduling**: When you create an automation, it's registered with the system
2. **Background Execution**: iOS wakes the app at the scheduled time to run the export
3. **Completion**: The app sends a local notification when the export completes
4. **Rescheduling**: The next execution is automatically scheduled

### Requirements

- App must be opened at least once after installation (to register background tasks)
- Background App Refresh must be enabled in Settings
- For iCloud exports: iCloud Drive must be enabled

### Troubleshooting

**Automation not running?**
- Ensure "Background App Refresh" is enabled in Settings > General > Background App Refresh
- Open the app at least once every few days (iOS suspends background tasks for unused apps)
- Check that HealthKit permissions are still granted

**Export fails?**
- Check iCloud storage space
- Verify HealthKit permissions
- Test the automation manually with "Test Now" button
- Check last error message in automation details

---

## Architecture

```
OpenHealth/
├── App/
│   ├── OpenHealthApp.swift         # App entry with BGTaskScheduler registration
│   └── ContentView.swift            # Main tab view
├── Models/
│   ├── Automation.swift             # Automation models with execution status
│   ├── ExportConfiguration.swift      # Export settings including "Export All" flag
│   ├── ExportDestination.swift       # iCloud, local, API destinations
│   └── HealthData.swift             # Data models including HealthDataBundle
├── Services/
│   ├── AutomationScheduler.swift    # NEW: Background task scheduling and execution
│   ├── HealthKitService.swift       # HealthKit fetching including fetchAllHealthData()
│   └── ExportService.swift          # Export logic with format conversion
├── ViewModels/
│   └── DashboardViewModel.swift     # Dashboard data management
├── Views/
│   ├── Automation/                  # Automation list and detail views
│   ├── Dashboard/                   # Health metrics dashboard
│   ├── Export/                      # Export configuration views
│   └── Settings/                    # App settings
├── Utilities/
│   └── HealthTypeMetadata.swift     # Health type categorization
├── Widgets/
│   └── HealthExportWidget.swift     # Home screen widget
├── Tests/
│   └── ExportServiceTests.swift     # Unit tests
└── Resources/
    └── Info.plist                   # Background task permissions
```

---

## Development Status

### ✅ Implemented
- [x] Manual export of all health data types
- [x] "Export All" toggle for one-tap exports
- [x] CSV, JSON, GPX export formats
- [x] Local Files and iCloud Drive destinations
- [x] REST API destination
- [x] Background task scheduling (BGTaskScheduler)
- [x] Daily/weekly/monthly automation
- [x] Execution status tracking
- [x] Local notifications
- [x] "Test Now" button for automations

### ⏳ In Progress / Planned
- [ ] Apple Watch app
- [ ] Siri Shortcuts integration
- [ ] Google Drive integration
- [ ] Dropbox integration
- [ ] MQTT/Home Assistant support
- [ ] Custom export templates
- [ ] Data visualization charts
- [ ] Multi-language support

---

## Known Issues

### Build Issues
- ⚠️ **Missing Xcode Project**: The repository doesn't include `.xcodeproj` - you'll need to create one or use Swift Package Manager
- ⚠️ **Build Errors**: Some Swift syntax issues may need fixing in `DestinationPickerView.swift`

### Functional Limitations
- ⚠️ **Workout Routes**: GPX export for routes is simplified and may not capture all route data
- ⚠️ **ECG Export**: ECG data fetching works but visualization in exports is basic
- ⚠️ **Large Exports**: Exporting "All Time" with all data types may be slow or memory-intensive

### Background Automation
- ⚠️ **iOS Restrictions**: Background tasks may be delayed by iOS based on battery, usage patterns
- ⚠️ **First Run**: App must be opened at least once to register background tasks

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Setup

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Code Style

- Follow Swift naming conventions
- Use SwiftUI for all views
- Add `@MainActor` for UI-related code
- Write documentation comments for public APIs
- Add tests for new functionality

### Priority Areas

1. **Testing**: Add comprehensive unit and UI tests
2. **Error Handling**: Improve error messages and recovery
3. **Performance**: Optimize large exports
4. **Documentation**: Add inline code documentation

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- [Apple HealthKit](https://developer.apple.com/documentation/healthkit) - Health data framework
- [Health Auto Export](https://www.healthyapps.dev/health-auto-export) - Inspiration for this project
- [Apple Background Tasks Framework](https://developer.apple.com/documentation/backgroundtasks) - For automation support

---

<div align="center">
  <p>Made with ❤️ for the open source community</p>
  <p>
    <a href="https://github.com/shersingh7/OpenHealth/issues">Report Bug</a> •
    <a href="https://github.com/shersingh7/OpenHealth/issues">Request Feature</a>
  </p>
</div>
