# OpenHealth

<div align="center">
  <img src="Resources/Assets.xcassets/AppIcon.appiconset/icon.png" alt="OpenHealth Logo" width="120" height="120">

  <h3>Free & Open Source Health Data Export App</h3>

  <p>Export your Apple Health data to anywhere - No account required, no data collection, no paywall.</p>

  <p>
    <a href="#features">Features</a> •
    <a href="#installation">Installation</a> •
    <a href="#usage">Usage</a> •
    <a href="#contributing">Contributing</a> •
    <a href="#license">License</a>
  </p>

  <p>
    <img src="https://img.shields.io/badge/Platform-iOS%20%7C%20iPadOS%20%7C%20macOS%20%7C%20visionOS-blue" alt="Platform">
    <img src="https://img.shields.io/badge/iOS-17%2B-green" alt="iOS 17+">
    <img src="https://img.shields.io/badge/License-MIT-yellow" alt="License: MIT">
  </p>
</div>

---

## Features

### 📊 Export 150+ Health Metrics

- **Activity**: Steps, distance, active energy, VO2 Max, flights climbed
- **Cardiovascular**: Heart rate, resting heart rate, HRV, blood pressure
- **Body Measurements**: Weight, height, BMI, body fat percentage
- **Mobility**: Walking speed, step length, asymmetry
- **Respiratory**: Breathing rate, blood oxygen (SpO2)
- **Sleep**: Sleep analysis, breathing disturbances
- **Nutrition**: Dietary tracking (carbs, protein, vitamins, etc.)
- **Workouts**: Full workout data with GPS routes (GPX export)
- **And more**: Symptoms, cycle tracking, medications, ECG, etc.

### 📁 Export Formats

| Format | Description |
|--------|-------------|
| **CSV** | Spreadsheet-compatible, great for data analysis |
| **JSON** | Structured format with nested data, ideal for developers |
| **GPX** | GPS Exchange Format for workout routes |

### 🚀 Export Destinations

- **Local Files** - Save to your device
- **iCloud Drive** - Auto-sync across all Apple devices
- **REST API** - Send to any custom endpoint
- **Google Drive** - Upload to your Google account (coming soon)
- **Dropbox** - Upload to Dropbox (coming soon)
- **MQTT** - Publish to IoT platforms (coming soon)
- **Home Assistant** - Direct HA integration (coming soon)

### ⏰ Automations

- Schedule automatic exports daily, weekly, or monthly
- Background operation (no need to keep app open)
- Activity logging and error tracking

### 🔒 Privacy First

- **No account required** - Just install and use
- **No data collection** - Your health data stays on your device
- **No third-party sharing** - You control where data goes
- **Open source** - Audit the code yourself

---

## Screenshots

<div align="center">
  <img src="Docs/screenshots/dashboard.png" alt="Dashboard" width="200">
  <img src="Docs/screenshots/export.png" alt="Export" width="200">
  <img src="Docs/screenshots/automations.png" alt="Automations" width="200">
  <img src="Docs/screenshots/settings.png" alt="Settings" width="200">
</div>

---

## Installation

### Requirements

- iOS 17.0+ / iPadOS 17.0+ / macOS 14.0+ / visionOS 1.0+
- Xcode 16.0+ (for development)
- Apple Developer account (for device testing)

### From Source

1. **Clone the repository**
   ```bash
   git clone https://github.com/shersingh/OpenHealth.git
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

1. Select **Data Types** - Choose which health metrics to export
2. Select **Date Range** - Choose a preset or custom range
3. Select **Format** - CSV, JSON, or GPX
4. Select **Destinations** - Where to save your export
5. Tap **Export Now**

### Setting Up Automations

1. Go to the **Automations** tab
2. Tap **+** to create a new automation
3. Configure:
   - Name
   - Schedule (hourly, daily, weekly, monthly)
   - Export settings
   - Destination
4. Enable and save

---

## Architecture

```
OpenHealth/
├── App/                    # App entry point
├── Models/                 # Data models
├── Services/               # HealthKit, Export, CloudKit
├── ViewModels/             # MVVM view models
├── Views/                  # SwiftUI views
├── Utilities/              # Exporters, Extensions
├── Resources/              # Assets, Localizations
└── Widgets/                # WidgetKit widgets
```

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
- Write documentation comments for public APIs
- Add tests for new functionality

---

## Roadmap

- [ ] Apple Watch app
- [ ] Complications support
- [ ] Siri Shortcuts integration
- [ ] Google Drive integration
- [ ] Dropbox integration
- [ ] MQTT/Home Assistant support
- [ ] Custom export templates
- [ ] Data visualization improvements
- [ ] Multi-language support

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- [Apple HealthKit](https://developer.apple.com/documentation/healthkit) - Health data framework
- [Health Auto Export](https://www.healthyapps.dev/health-auto-export) - Inspiration for this project
- [healthkit-exporter](https://github.com/StanfordBioinformatics/healthkit-exporter) - Reference implementation

---

<div align="center">
  <p>Made with ❤️ for the open source community</p>
  <p>
    <a href="https://github.com/shersingh/OpenHealth/issues">Report Bug</a> •
    <a href="https://github.com/shersingh/OpenHealth/issues">Request Feature</a>
  </p>
</div>