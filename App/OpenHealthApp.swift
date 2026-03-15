//
//  OpenHealthApp.swift
//  OpenHealth
//
//  Created for OpenHealth - Free & Open Source Health Data Export
//

import SwiftUI

@main
struct OpenHealthApp: App {
    @StateObject private var healthKitService = HealthKitService()
    @StateObject private var exportService = ExportService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKitService)
                .environmentObject(exportService)
                .onAppear {
                    // Request HealthKit authorization on launch
                    Task {
                        await requestHealthKitAuthorization()
                    }
                }
        }
    }

    private func requestHealthKitAuthorization() async {
        do {
            try await healthKitService.requestAuthorization()
        } catch {
            print("Failed to request HealthKit authorization: \(error)")
        }
    }
}