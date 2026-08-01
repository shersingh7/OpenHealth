import Foundation

/// Rejects HTTPS→HTTP downgrades and cross-origin redirects when credentials are attached.
/// Never logs headers, bodies, or full URLs.
final class RedirectPolicyDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        let original = task.originalRequest?.url
        let credentialsAttached =
            RedirectOriginPolicy.requestCarriesCredentials(task.originalRequest)
            || RedirectOriginPolicy.requestCarriesCredentials(task.currentRequest)
            || RedirectOriginPolicy.requestCarriesCredentials(request)

        let allowed = RedirectOriginPolicy.shouldAllowRedirect(
            originalURL: original,
            redirectURL: request.url,
            credentialsAttached: credentialsAttached
        )
        if !allowed {
            AppLogger.export.error("Rejected unsafe redirect (scheme/origin policy)")
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}
