import SwiftUI
import Observation

/// Standalone, offline preview of the SAME Studio views used by SoloCompassApp.
/// Travel/account dependencies are explicitly unavailable, never simulated.
@main struct StudioPreviewApp: App {
    @State private var notifications = NotificationService()
    var body: some Scene {
        WindowGroup { StudioHomeView().environment(notifications) }
    }
}

@MainActor @Observable final class NotificationService {
    var pendingDeepLink: String?
}

struct CompassMapView: View {
    var body: some View {
        ContentUnavailableView("studio.preview.map", systemImage: "map", description: Text("studio.preview.boundary"))
    }
}

struct MeSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ContentUnavailableView("studio.preview.account", systemImage: "person.crop.circle", description: Text("studio.preview.boundary"))
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("studio.done") { dismiss() } } }
        }
    }
}
