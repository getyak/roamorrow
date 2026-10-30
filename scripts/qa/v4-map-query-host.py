#!/usr/bin/env python3
"""Run real V4 map caller functions in a lightweight macOS Swift harness.

No simulator, network, SwiftPM, or production-source mutation. The complete
caller functions are copied verbatim; only their owning view and boundaries
are replaced. --scenario selects query replacement or source reveal behavior.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "apps/ios/SoloCompass/Views/CompanionHome/CompanionNearbyView.swift"


def extract_function(source: str, name: str = "performSearch") -> tuple[str, int, int]:
    marker = f"    private func {name}() {{"
    start = source.index(marker)
    opening = source.index("{", start)
    depth = 0
    for offset in range(opening, len(source)):
        if source[offset] == "{":
            depth += 1
        elif source[offset] == "}":
            depth -= 1
            if depth == 0:
                end = offset + 1
                return source[start:end], source.count("\n", 0, start) + 1, source.count("\n", 0, end) + 1
    raise ValueError(f"{name} function is unbalanced")


PREAMBLE = r'''import Foundation

// The extracted caller's UIKit keyboard-dismiss side effect is a no-op on host.
@MainActor final class UIResponder: NSObject {
    @objc func resignFirstResponder() {}
}
@MainActor final class UIApplication {
    static let shared = UIApplication()
    func sendAction(_ action: Selector, to: Any?, from: Any?, for: Any?) {}
}
struct HostCoordinate { let latitude: Double; let longitude: Double }
struct HostOrigin { let coordinate: HostCoordinate }
struct HostExperience { let id: String }
enum HostPanelPage: Equatable { case browse, place, route }
enum HostPanelLevel: Equatable { case collapsed, expanded }

// Stub boundary: MapViewModel, coordinate types, and cancellable search transport.
// Its guard, isSearchingWeb/defer lifecycle, and cancellation check match the
// production contract. This harness tests caller orchestration, not model logic.
@MainActor final class HostModel {
    var agentSearchOrigin: HostOrigin? = HostOrigin(coordinate: HostCoordinate(latitude: 35, longitude: 139))
    var isSearchingWeb = false
    var lastResult: String?
    var selectedExperience: HostExperience?
    var lastWebSearchResult: String?
    var events: [String] = []
    func searchThisArea() { events.append("searchThisArea") }
    func webSearchPOIs(query: String, near: HostCoordinate, constrainWorkspaceResults: Bool) async {
        guard !query.isEmpty, !isSearchingWeb else { events.append("model-rejected:\(query)"); return }
        isSearchingWeb = true
        events.append("start:\(query)")
        defer { isSearchingWeb = false; events.append("cleanup:\(query)") }
        do {
            try await Task.sleep(for: query == "first" ? .milliseconds(700) : .milliseconds(15))
            try Task.checkCancellation()
        } catch is CancellationError {
            events.append("cancel:\(query)")
            return
        } catch {
            events.append("error:\(query)")
            return
        }
        lastResult = query
        events.append("result:\(query)")
    }
}

@MainActor final class HostCaller {
    let model = HostModel()
    var searchQuery = ""
    var searchTask: Task<Void, Never>?
    var isActive = false
    var messageRevealToken = 0
    var consumedMessageRevealToken = 0
    var showsSearch = false
    var selectedPlaceID: String?
    var page: HostPanelPage = .browse
    var level: HostPanelLevel = .collapsed
    var expansionCount = 0
    func expand() { level = .expanded; expansionCount += 1 }
    // REVEAL_WRAPPER
    func submit(_ query: String) { searchQuery = query; performSearch() }
'''

POSTAMBLE = r'''
}

@main struct QueryRaceHarness {
    @MainActor static func main() async {
        let caller = HostCaller()
        caller.submit("first")
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !caller.model.isSearchingWeb && ContinuousClock.now < deadline {
            await Task.yield()
        }
        let firstWasInFlight = caller.model.isSearchingWeb && caller.model.events.contains("start:first")
        caller.model.events.append("submit:second whileBusy=\(caller.model.isSearchingWeb)")
        caller.submit("second")
        await caller.searchTask?.value
        let events = caller.model.events
        let cleanupIndex = events.firstIndex(of: "cleanup:first")
        let secondIndex = events.firstIndex(of: "start:second")
        let checks: [(String, Bool)] = [
            ("first request was suspended with isSearchingWeb true before second submission", firstWasInFlight),
            ("first request was cancelled", events.contains("cancel:first")),
            ("first cleanup completed before second request started", cleanupIndex != nil && secondIndex != nil && cleanupIndex! < secondIndex!),
            ("second request started", secondIndex != nil),
            ("second query owns the final result", caller.model.lastResult == "second"),
            ("no stale first result was applied", !events.contains("result:first")),
            ("searching state cleaned up", !caller.model.isSearchingWeb),
        ]
        for event in events { print("EVENT \(event)") }
        for (name, passed) in checks { print("\(passed ? "PASS" : "FAIL") \(name)") }
        print("FINAL_RESULT \(caller.model.lastResult ?? "nil")")
        if checks.contains(where: { !$0.1 }) { exit(1) }
    }
}
'''


MESSAGE_POSTAMBLE = r'''
}

@main struct MessageRevealHarness {
    @MainActor static func main() async {
        let caller = HostCaller()
        var checks: [(String, Bool)] = []
        caller.messageRevealToken = 1
        caller.model.selectedExperience = HostExperience(id: "book")
        caller.searchQuery = "old query"
        caller.showsSearch = true
        caller.model.lastWebSearchResult = "old result"
        caller.consumeReveal()
        checks.append(("inactive reveal remains unconsumed", caller.consumedMessageRevealToken == 0 && caller.expansionCount == 0 && caller.selectedPlaceID == nil))
        checks.append(("inactive reveal preserves search UI", caller.searchQuery == "old query" && caller.showsSearch && caller.model.lastWebSearchResult == "old result"))
        caller.isActive = true
        caller.consumeReveal()
        checks.append(("activation consumes pending new token", caller.consumedMessageRevealToken == 1))
        checks.append(("activation selects book and place page", caller.selectedPlaceID == "book" && caller.page == .place))
        checks.append(("activation expands exactly once", caller.level == .expanded && caller.expansionCount == 1))
        checks.append(("consumed reveal clears search UI", caller.searchQuery.isEmpty && !caller.showsSearch && caller.model.lastWebSearchResult == nil))
        caller.level = .collapsed
        caller.consumeReveal()
        checks.append(("same token preserves manual collapse", caller.level == .collapsed && caller.expansionCount == 1))
        caller.isActive = false
        caller.consumeReveal()
        caller.isActive = true
        caller.consumeReveal()
        checks.append(("ordinary revisit does not expand consumed token", caller.level == .collapsed && caller.expansionCount == 1 && caller.selectedPlaceID == "book"))
        caller.messageRevealToken = 2
        caller.model.selectedExperience = HostExperience(id: "cafe")
        caller.consumeReveal()
        checks.append(("new token selects new place and expands once", caller.selectedPlaceID == "cafe" && caller.page == .place && caller.level == .expanded && caller.expansionCount == 2 && caller.consumedMessageRevealToken == 2))
        caller.messageRevealToken = 3
        caller.model.selectedExperience = nil
        caller.consumeReveal()
        checks.append(("missing selected place uses browse page", caller.selectedPlaceID == nil && caller.page == .browse && caller.expansionCount == 3 && caller.consumedMessageRevealToken == 3))
        caller.isActive = false
        caller.messageRevealToken = 4
        caller.model.selectedExperience = HostExperience(id: "book")
        caller.consumeReveal()
        checks.append(("new inactive token stays pending", caller.consumedMessageRevealToken == 3 && caller.expansionCount == 3))
        caller.isActive = true
        caller.consumeReveal()
        checks.append(("pending newer token is consumed on activation", caller.consumedMessageRevealToken == 4 && caller.selectedPlaceID == "book" && caller.expansionCount == 4))
        for (name, passed) in checks { print("\(passed ? "PASS" : "FAIL") \(name)") }
        print("FINAL_REVEAL token=\(caller.consumedMessageRevealToken) selected=\(caller.selectedPlaceID ?? "nil") expansions=\(caller.expansionCount)")
        if checks.contains(where: { !$0.1 }) { exit(1) }
    }
}
'''


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact-dir", type=Path, required=True, help="Existing dev-storage-guard new-artifact directory")
    parser.add_argument("--source", type=Path, default=SOURCE)
    parser.add_argument("--scenario", choices=["query-race", "message-reveal"], default="query-race")
    parser.add_argument("--run-label", default="query-race", help="Evidence subdirectory (preserves previous runs)")
    args = parser.parse_args()
    if not args.artifact_dir.is_dir():
        parser.error("--artifact-dir must already exist; create it with dev-storage-guard new-artifact")
    output = args.artifact_dir / args.run_label
    output.mkdir(exist_ok=False)
    raw = args.source.read_bytes()
    source = raw.decode()
    function, start_line, end_line = extract_function(source)
    swift = output / "QueryRaceHarness.swift"
    functions = [("performSearch", function, start_line, end_line)]
    if args.scenario == "message-reveal":
        reveal, reveal_start, reveal_end = extract_function(source, "consumeMessageReveal")
        functions.append(("consumeMessageReveal", reveal, reveal_start, reveal_end))
        (output / "consumeMessageReveal.swift").write_text(reveal + "\n")
    preamble = PREAMBLE.replace("// REVEAL_WRAPPER", "func consumeReveal() { consumeMessageReveal() }" if args.scenario == "message-reveal" else "")
    postamble = MESSAGE_POSTAMBLE if args.scenario == "message-reveal" else POSTAMBLE
    swift.write_text(preamble + "\n".join(item[1] for item in functions) + postamble)
    (output / "performSearch.swift").write_text(function + "\n")
    primary_name, primary_function, primary_start, primary_end = functions[-1]
    metadata = {
        "source": str(args.source.resolve()),
        "source_sha256": hashlib.sha256(raw).hexdigest(),
        "caller": f"CompanionNearbyMap.{primary_name}()",
        "caller_lines": [primary_start, primary_end],
        "caller_sha256": hashlib.sha256(primary_function.encode()).hexdigest(),
        "scenario": args.scenario,
        "functions": [{"name": name, "lines": [first, last], "sha256": hashlib.sha256(body.encode()).hexdigest()} for name, body, first, last in functions],
        "extraction": "Caller functions copied verbatim; no production function edits",
        "boundaries": ["SwiftUI owner replaced with @MainActor HostCaller", "UIKit resignFirstResponder no-op", "MapViewModel state/searchThisArea/search transport stub", "coordinate/origin value types stub", "panel state and expand side effect stub"],
        "scope": "Host caller cancellation/serialization or reveal state transitions only; callback invocation is explicit and does not establish SwiftUI lifecycle callback delivery, iOS, real MapViewModel, persistence, or network acceptance",
    }
    print(json.dumps(metadata, ensure_ascii=False, indent=2), flush=True)
    command = ["swiftc", "-swift-version", "6", "-strict-concurrency=complete", "-warnings-as-errors", "-parse-as-library", str(swift), "-o", str(output / "query-race")]
    metadata["compile_command"] = command
    compile_result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=45)
    (output / "compile.log").write_text(compile_result.stdout)
    metadata["compile_exit"] = compile_result.returncode
    if compile_result.returncode:
        print(compile_result.stdout, end="")
        (output / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
        return compile_result.returncode
    run = subprocess.run([str(output / "query-race")], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=10)
    (output / "run.log").write_text(run.stdout)
    print(run.stdout, end="")
    metadata["test_exit"] = run.returncode
    (output / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(f"EVIDENCE {output}")
    return run.returncode


if __name__ == "__main__":
    sys.exit(main())
