import Foundation

public struct BackgroundTaskRequest: Sendable, Equatable {
    public let identifier: String
    public let earliestBeginDate: Date?

    public init(identifier: String, earliestBeginDate: Date?) {
        self.identifier = identifier
        self.earliestBeginDate = earliestBeginDate
    }
}

public protocol BackgroundTaskScheduling: Sendable {
    func submit(_ request: BackgroundTaskRequest) throws
    func cancel(identifier: String)
    func cancelAll()
}
