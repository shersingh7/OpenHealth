import Foundation
import OSLog

/// Centralized logging. Never log health values, secrets, or destination URLs with credentials.
public enum AppLogger {
    public static let general = Logger(subsystem: "com.shersingh7.openhealth", category: "general")
    public static let health = Logger(subsystem: "com.shersingh7.openhealth", category: "health")
    public static let export = Logger(subsystem: "com.shersingh7.openhealth", category: "export")
    public static let automation = Logger(subsystem: "com.shersingh7.openhealth", category: "automation")
    public static let persistence = Logger(subsystem: "com.shersingh7.openhealth", category: "persistence")
}
