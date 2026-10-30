import Foundation

/// Browsing the same map never changes a conversation or a confirmed trip.
public enum MapWorkspaceBrowseMode: String, CaseIterable, Identifiable, Sendable {
    case nearby
    case saved

    public var id: String { rawValue }
}

/// Saved places are a collection, not just the pins within the current viewport.
public enum MapWorkspaceFavoriteScope: String, CaseIterable, Identifiable, Sendable {
    case currentCity
    case allSaved

    public var id: String { rawValue }
}
