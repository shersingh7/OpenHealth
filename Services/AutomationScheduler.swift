//
//  AutomationScheduler.swift
//  OpenHealth
//
//  Background task scheduler for automated health data exports
//

import Foundation
import BackgroundTasks
import UserNotifications

/// Service for scheduling and executing background automation tasks
@MainActor
class AutomationScheduler: ObservableObject {
    
    // MARK: - Properties
    
    static let shared = AutomationScheduler()
    static let taskIdentifier = "com.openhealth.dailyexport"
    
    private let healthKitService = HealthKitService()
    private let exportService = ExportService()
    private let userDefaults = UserDefaults.standard
    private let automationsKey = "openhealth.automations"
    
    @Published var automations: [Automation] = []
    @Published var isRunning = false
    @Published var lastRunResult: String?
    
    // MARK: - Initialization
    
    private init() {
        loadAutomations()
        requestNotificationPermissions()
    }
    
    // MARK: - Task Registration
    
    /// Register background tasks with the system
    func registerTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: AutomationScheduler.taskIdentifier, using: nil) { [weak self] task in
            guard let self = self else { return }
            Task { @MainActor in
                await self.handleBackgroundTask(task as! BGAppRefreshTask)
            }
        }
        print("Registered background task: \(AutomationScheduler.taskIdentifier)")
    }
    
    // MARK: - Automation Management
    
    /// Schedule an automation for background execution
    func schedule(_ automation: Automation) {
        // Update or add automation
        if let index = automations.firstIndex(where: { $0.id == automation.id }) {
            automations[index] = automation
        } else {
            automations.append(automation)
        }
        
        saveAutomations()
        
        // Schedule background task if enabled
        if automation.isEnabled {
            scheduleBackgroundTask(for: automation)
        }
    }
    
    /// Remove an automation
    func removeAutomation(_ automation: Automation) {
        automations.removeAll { $0.id == automation.id }
        saveAutomations()
        cancelBackgroundTask(for: automation)
    }
    
    /// Execute all due automations
    func executeDueAutomations() async {
        let now = Date()
        let dueAutomations = automations.filter { automation in
            guard automation.isEnabled else { return false }
            guard let nextRun = automation.nextRun else { return false }
            return nextRun <= now
        }
        
        for automation in dueAutomations {
            await executeAutomation(automation)
        }
    }
    
    /// Execute a specific automation immediately
    func executeAutomation(_ automation: Automation) async {
        guard let index = automations.firstIndex(where: { $0.id == automation.id }) else { return }
        
        isRunning = true
        automations[index].markRunning()
        saveAutomations()
        
        do {
            // Check HealthKit authorization
            guard healthKitService.isAuthorized else {
                throw ExportError.validationError("HealthKit not authorized")
            }
            
            // Perform export
            let result = try await exportService.export(configuration: automation.exportConfiguration)
            
            if result.success {
                automations[index].markCompleted()
                lastRunResult = "✅ Exported \(result.recordsExported) records"
                
                // Send success notification
                sendNotification(
                    title: "Health Export Complete",
                    body: "Successfully exported \(result.recordsExported) health records"
                )
            } else {
                let errorMessage = result.error?.localizedDescription ?? "Unknown error"
                automations[index].markFailed(error: errorMessage)
                lastRunResult = "❌ Failed: \(errorMessage)"
                
                // Send failure notification
                sendNotification(
                    title: "Health Export Failed",
                    body: errorMessage
                )
            }
            
        } catch {
            automations[index].markFailed(error: error.localizedDescription)
            lastRunResult = "❌ Error: \(error.localizedDescription)"
            
            sendNotification(
                title: "Health Export Failed",
                body: error.localizedDescription
            )
        }
        
        // Reschedule for next run
        if automations[index].isEnabled {
            scheduleBackgroundTask(for: automations[index])
        }
        
        saveAutomations()
        isRunning = false
    }
    
    /// Reschedule an automation
    func reschedule(_ automation: Automation) {
        cancelBackgroundTask(for: automation)
        if automation.isEnabled {
            scheduleBackgroundTask(for: automation)
        }
    }
    
    // MARK: - Background Task Handling
    
    private func scheduleBackgroundTask(for automation: Automation) {
        guard let nextRun = automation.nextRun else { return }
        
        let request = BGAppRefreshTaskRequest(identifier: AutomationScheduler.taskIdentifier)
        request.earliestBeginDate = nextRun
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Scheduled background task for \(nextRun)")
        } catch {
            print("Failed to schedule background task: \(error)")
        }
    }
    
    private func cancelBackgroundTask(for automation: Automation) {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: AutomationScheduler.taskIdentifier)
    }
    
    private func handleBackgroundTask(_ task: BGAppRefreshTask) async {
        // Create a task expiration handler
        task.expirationHandler = {
            print("Background task expiring")
        }
        
        // Execute due automations
        await executeDueAutomations()
        
        // Mark task as complete
        task.setTaskCompleted(success: true)
        
        // Schedule next background task
        scheduleNextBackgroundTask()
    }
    
    private func scheduleNextBackgroundTask() {
        // Find the next automation that needs to run
        let now = Date()
        let nextAutomation = automations
            .filter { $0.isEnabled && ($0.nextRun ?? now) > now }
            .min { ($0.nextRun ?? now) < ($1.nextRun ?? now) }
        
        if let automation = nextAutomation, let nextRun = automation.nextRun {
            let request = BGAppRefreshTaskRequest(identifier: AutomationScheduler.taskIdentifier)
            request.earliestBeginDate = nextRun
            
            do {
                try BGTaskScheduler.shared.submit(request)
                print("Scheduled next background task for \(nextRun)")
            } catch {
                print("Failed to schedule next background task: \(error)")
            }
        }
    }
    
    // MARK: - Persistence
    
    private func loadAutomations() {
        guard let data = userDefaults.data(forKey: automationsKey),
              let savedAutomations = try? JSONDecoder().decode([Automation].self, from: data) else {
            return
        }
        automations = savedAutomations
    }
    
    private func saveAutomations() {
        if let data = try? JSONEncoder().encode(automations) {
            userDefaults.set(data, forKey: automationsKey)
        }
    }
    
    // MARK: - Notifications
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            print("Notification permission: \(granted)")
        }
    }
    
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Test Function
    
    /// Create a test automation that runs immediately
    func createTestAutomation() -> Automation {
        let config = ExportConfiguration(
            name: "Daily Health Export",
            exportAllAvailableTypes: true,
            format: .json,
            dateRange: .yesterday,
            destinations: [
                ExportDestination(type: .iCloudDrive, configuration: .init(folderPath: "OpenHealth/DailyExports"))
            ]
        )
        
        let schedule = AutomationSchedule(
            frequency: .daily,
            hour: 2,
            minute: 0
        )
        
        return Automation(
            name: "Daily Export",
            exportConfiguration: config,
            schedule: schedule,
            iCloudFolderPath: "OpenHealth/DailyExports"
        )
    }
}
