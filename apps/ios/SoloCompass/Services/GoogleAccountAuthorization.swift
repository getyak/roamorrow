import AuthenticationServices
import UIKit

/// Keeps provider credentials in the system browser and the server, never in a view.
/// Source: https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession
@MainActor
final class GoogleAccountAuthorization: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    private var continuation: CheckedContinuation<Void, Error>?
    private var anchor: ASPresentationAnchor?

    func authorize(_ url: URL) async throws {
        guard session == nil,
              let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .filter({ $0.activationState == .foregroundActive }).flatMap(\.windows).first(where: \.isKeyWindow)
        else { throw TravelerHarnessClient.Failure.unavailable }
        anchor = window
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "solocompass") { [weak self] callback, error in
                    Task { @MainActor in
                        guard let self else { return }
                        if let error { self.finish(.failure(error)); return }
                        guard let callback, callback.scheme == "solocompass", callback.host == "google-connected",
                              URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems?
                                .first(where: { $0.name == "status" })?.value == "connected"
                        else { self.finish(.failure(TravelerHarnessClient.Failure.rejected)); return }
                        self.finish(.success(()))
                    }
                }
                self.session = session
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = true
                if !session.start() { finish(.failure(TravelerHarnessClient.Failure.unavailable)) }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.session?.cancel()
                self?.finish(.failure(CancellationError()))
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor ?? ASPresentationAnchor()
    }

    private func finish(_ result: Result<Void, Error>) {
        let continuation = continuation
        self.continuation = nil
        session = nil
        anchor = nil
        continuation?.resume(with: result)
    }
}
