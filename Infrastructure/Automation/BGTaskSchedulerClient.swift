import Foundation
import BackgroundTasks

struct BGTaskSchedulerClient: BackgroundTaskScheduling {
    static let taskIdentifier = "com.shersingh7.openhealth.refresh"

    func submit(_ request: BackgroundTaskRequest) throws {
        let bgRequest = BGAppRefreshTaskRequest(identifier: request.identifier)
        bgRequest.earliestBeginDate = request.earliestBeginDate
        try BGTaskScheduler.shared.submit(bgRequest)
        AppLogger.automation.info("Submitted background request (best effort)")
    }

    func cancel(identifier: String) {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
    }

    func cancelAll() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
    }
}
