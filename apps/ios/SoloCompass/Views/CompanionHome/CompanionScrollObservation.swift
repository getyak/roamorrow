import SwiftUI
import UIKit

/// Modern visibility is an observation, never a two-way positioning command.
/// iOS 17 retains the existing compatible binding path.
struct CompanionReadingPositionObserver: ViewModifier {
    @Binding var legacyID: String?
    let isActive: Bool
    let onVisibleIDs: ([String]) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollTargetVisibilityChange(idType: String.self, threshold: 0.001) { ids in
                if isActive { onVisibleIDs(ids) }
            }
        } else {
            content.scrollPosition(id: $legacyID, anchor: .bottom)
        }
    }
}

/// Native sizing follows the bottom only for an active, idle latest intention.
/// This also handles lazy height corrections after a keyboard command finishes.
@MainActor
struct CompanionScrollAnchors: ViewModifier {
    let scrolling: CompanionScrollState
    let isActive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.defaultScrollAnchor(.bottom, for: .initialOffset)
                .defaultScrollAnchor(.bottom, for: .alignment)
                .defaultScrollAnchor(isActive && scrolling.pinsLatestDuringLayout ? .bottom : nil, for: .sizeChanges)
        } else {
            content.defaultScrollAnchor(.bottom)
        }
    }
}

/// Native phases include deceleration; only boundary changes enter SwiftUI state.
struct CompanionScrollInteractionObserver: ViewModifier {
    let isActive: Bool
    let onVisibility: (Bool) -> Void
    let action: (Bool) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    CompanionScrollVisibility.isNearLatest(contentHeight: geometry.contentSize.height, visibleRect: geometry.visibleRect)
                } action: { _, near in
                    if isActive { onVisibility(near) }
                }
                .onScrollPhaseChange { _, phase, context in
                    guard isActive else { return }
                    onVisibility(CompanionScrollVisibility.isNearLatest(contentHeight: context.geometry.contentSize.height,
                        visibleRect: context.geometry.visibleRect))
                    action(phase == .tracking || phase == .interacting || phase == .decelerating)
                }
        } else { content }
    }
}

/// iOS 17 observes its existing scroll view, without replacing the delegate,
/// gesture recognizer or scroll container. The display link exists only during
/// a native pan/deceleration and emits booleans only when their values change.
struct CompanionLegacyScrollProbe: UIViewRepresentable {
    let isActive: Bool
    let onVisibility: (Bool) -> Void
    let onInteraction: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        return view
    }
    func updateUIView(_ view: Probe, context: Context) {
        context.coordinator.active = isActive
        context.coordinator.onVisibility = onVisibility
        context.coordinator.onInteraction = onInteraction
        view.resolveScrollView()
        if !isActive { context.coordinator.stop() }
    }
    static func dismantleUIView(_ view: Probe, coordinator: Coordinator) { coordinator.detach() }

    final class Probe: UIView {
        weak var coordinator: Coordinator?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil { coordinator?.detach() } else { resolveScrollView() }
        }
        override func didMoveToSuperview() { super.didMoveToSuperview(); resolveScrollView() }
        func resolveScrollView() {
            var ancestor = superview
            while let view = ancestor {
                if let scroll = view as? UIScrollView { coordinator?.attach(scroll); return }
                ancestor = view.superview
            }
        }
    }

    @MainActor final class Coordinator: NSObject {
        var active = false
        var onVisibility: ((Bool) -> Void)?
        var onInteraction: ((Bool) -> Void)?
        private weak var scrollView: UIScrollView?
        private var link: CADisplayLink?
        private var lastInteraction: Bool?
        private var lastNear: Bool?

        func attach(_ scroll: UIScrollView) {
            if scrollView !== scroll {
                detach()
                scrollView = scroll
                scroll.panGestureRecognizer.addTarget(self, action: #selector(panChanged))
            }
        }
        func detach() {
            stop()
            scrollView?.panGestureRecognizer.removeTarget(self, action: #selector(panChanged))
            scrollView = nil
            lastInteraction = nil
            lastNear = nil
        }
        @objc private func panChanged() {
            guard active, link == nil else { return }
            lastInteraction = true
            onInteraction?(true)
            let displayLink = CADisplayLink(target: self, selector: #selector(tick))
            displayLink.add(to: .main, forMode: .common)
            link = displayLink
        }
        @objc private func tick() {
            guard active, let scroll = scrollView else { stop(); return }
            let near = scroll.contentOffset.y + scroll.bounds.height >= scroll.contentSize.height + scroll.adjustedContentInset.bottom - 24
            if near != lastNear { lastNear = near; onVisibility?(near) }
            let interacting = scroll.isTracking || scroll.isDragging || scroll.isDecelerating
            if interacting != lastInteraction { lastInteraction = interacting; onInteraction?(interacting) }
            if !interacting { stop() }
        }
        func stop() { link?.invalidate(); link = nil }
    }
}

/// Position-state changes update this modifier, retaining its existing content
/// node instead of re-running a factory for the entire lazy conversation.
@MainActor
struct CompanionScrollExecution: ViewModifier {
    let scrolling: CompanionScrollState
    let isActive: Bool
    let reduceMotion: Bool
    let trace: (String) -> Void

    func body(content: Content) -> some View {
        let execution = CompanionScrollExecutionContext(scrolling: scrolling,
            isActive: isActive, reduceMotion: reduceMotion, trace: trace)
        if #available(iOS 18.0, *) {
            content.modifier(CompanionModernScrollExecution(execution: execution))
        } else {
            ScrollViewReader { proxy in
                content.task(id: execution.key) {
                    await execution.perform { target in proxy.scrollTo(target, anchor: .bottom) }
                }
            }
        }
    }
}

private struct CompanionScrollExecutionKey: Hashable {
    let revision: Int
    let isActive: Bool
}

@MainActor
private struct CompanionScrollExecutionContext {
    let scrolling: CompanionScrollState
    let isActive: Bool
    let reduceMotion: Bool
    let trace: (String) -> Void
    var key: CompanionScrollExecutionKey { .init(revision: scrolling.request.revision, isActive: isActive) }

    func perform(_ move: @MainActor (String) -> Void) async {
        let captured = scrolling.request
        guard captured.revision > 0 else { return }
        await Task.yield()
        guard !Task.isCancelled, isActive, let target = captured.target,
              scrolling.intent.permitsScroll(captured, current: scrolling.request) else {
            trace("request-skipped"); return
        }
        trace("perform-\(captured.kind)")
        withAnimation(captured.animated && !reduceMotion ? .easeOut(duration: 0.2) : nil) { move(target) }
        scrolling.consume(revision: captured.revision)
    }
}

@available(iOS 18.0, *)
@MainActor
private struct CompanionModernScrollExecution: ViewModifier {
    let execution: CompanionScrollExecutionContext
    @State private var position = ScrollPosition(idType: String.self)

    func body(content: Content) -> some View {
        content.scrollPosition($position)
            .task(id: execution.key) {
                await execution.perform { target in
                    if target == "stream-bottom" {
                        position.scrollTo(edge: .bottom)
                    } else {
                        position.scrollTo(id: target, anchor: .bottom)
                    }
                }
            }
    }
}
