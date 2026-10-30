import Foundation

enum AgentToolRecoveryPolicy: Equatable, Sendable {
    case retryRead
    case neverReplayStarted
}

/// Recovery is opt-in. Even an idempotent write must not be silently repeated
/// after a crash between dispatch and its durable receipt.
enum AgentToolPolicy {
    static let registry: [String: AgentToolRecoveryPolicy] = [
        "explore_nearby": .neverReplayStarted,
        "web_search": .retryRead,
        "filter_by_category": .neverReplayStarted,
        "show_details": .retryRead,
        "save_to_favorites": .neverReplayStarted,
        "dismiss_recommendation": .neverReplayStarted,
        "search_places": .neverReplayStarted,
        "navigate_to": .neverReplayStarted,
        "filter_visible": .neverReplayStarted,
        "expand_radius": .neverReplayStarted,
        "build_route": .neverReplayStarted,
        "compile_workday_route": .neverReplayStarted,
        "suggest_now_action": .retryRead,
        "open_blindbox": .neverReplayStarted,
        "bury_capsule": .neverReplayStarted,
        "recall_pattern": .retryRead,
        "sos_plan": .neverReplayStarted,
        "unwalked_path": .neverReplayStarted,
        "recall_local_scene": .retryRead,
        "recall_memory": .retryRead,
        "get_city_kit": .retryRead,
        "find_local_events": .retryRead,
        "manage_follow_up": .neverReplayStarted,
    ]

    static func recovery(for name: String) -> AgentToolRecoveryPolicy {
        registry[name] ?? .neverReplayStarted
    }

    static var knownTools: Set<String> { Set(registry.keys) }
}
