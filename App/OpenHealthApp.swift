//
//  OpenHealthApp.swift
//  OpenHealth
//
//  Created for OpenHealth - Free & Open Source Health Data Export
//

import SwiftUI
import BackgroundTasks

@main
struct OpenHealthApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register background tasks
        AutomationScheduler.shared.registerTasks()
        
        // Schedule any existing automations
        Task { @MainActor in
            await AutomationScheduler.shared.executeDueAutomations()
        }
        
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Schedule background tasks when app enters background
        scheduleBackgroundTasks()
    }
    
    private func scheduleBackgroundTasks() {
        // Ensure background tasks are scheduled
        for automation in AutomationScheduler.shared.automations where automation.isEnabled {
            AutomationScheduler.shared.reschedule(automation)
        }
    }
}