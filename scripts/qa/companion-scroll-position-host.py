"""Check the shipping destination adapter with real SwiftUI position values."""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import re
import subprocess
import textwrap

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
repo = Path(__file__).resolve().parents[2]
source = (repo / "apps/ios/SoloCompass/Views/CompanionHome/CompanionScrollObservation.swift").read_text()
owner = source.index("private struct CompanionModernScrollExecution")
initializer = re.search(r"@State private var position = ([^\n]+)", source[owner:]).group(1)
invocation = re.search(r"await execution\.perform(?:\([^\n]*\))? \{ target in", source[owner:]).group()
start = source.index(invocation, owner) + len(invocation)
end = source.index("\n                }", start)
adapter = textwrap.dedent(source[start:end]).strip()
context = source[source.index("private struct CompanionScrollExecutionKey"):source.index("@available(iOS 18.0, *)\n@MainActor\nprivate struct CompanionModernScrollExecution")]
models = (repo / "apps/ios/SoloCompass/Views/CompanionHome/CompanionHomeModels.swift").read_text()
reading_start = models.index("struct CompanionConversationReadingState:")
reading = models[reading_start:models.index("\n}", reading_start) + 2]
args.output.mkdir(parents=True, exist_ok=True)
fixture = args.output / "PositionContract.swift"
fixture.write_text("import SwiftUI\n" + reading + "\n" + context
                  + "\n@MainActor func apply(_ target: String, to position: inout ScrollPosition) {\n"
                  + adapter + "\n}\n"
                  + "@MainActor func initialPosition() -> ScrollPosition { " + initializer + " }\n"
                  + "@MainActor private func runModern(_ execution: CompanionScrollExecutionContext, position: inout ScrollPosition) async -> Int {\nvar moves = 0\n"
                  + invocation + "\nmoves += 1\n" + adapter + "\n}\nreturn moves\n}\n" + r'''
@main @MainActor
struct PositionContract {
    static var failures = 0
    static var checks = 0
    static func expect(_ value: Bool, _ label: String) {
        checks += 1
        if !value { failures += 1; print("FAIL: \(label)") }
    }
    static func main() async {
        expect(initialPosition() == ScrollPosition(),
               "semantic command binding does not also request automatic row-ID readback")
        var position = initialPosition()
        apply("message:source", to: &position)
        expect(position.edge == nil, "history does not retain an endpoint")
        expect(position.viewID(type: String.self) == "message:source", "history retains the requested stable row")
        apply("stream-bottom", to: &position)
        expect(position.edge == nil, "latest resolves a concrete layout target rather than an estimated edge")
        expect(position.viewID(type: String.self) == "stream-bottom", "latest replaces history with the stable footer target")
        apply("message:other-source", to: &position)
        expect(position.edge == nil, "history retains ID-based positioning")
        expect(position.viewID(type: String.self) == "message:other-source", "history switches to the new source row")
        apply("stream-bottom", to: &position)
        apply("stream-bottom", to: &position)
        expect(position.edge == nil && position.viewID(type: String.self) == "stream-bottom",
               "latest retains the stable footer after repeated semantic actions")
        apply("message:stream-bottom", to: &position)
        expect(position.viewID(type: String.self) == "message:stream-bottom" && position.edge == nil,
               "a similarly named message remains a distinct history target")

        func context(_ state: CompanionScrollState, active: Bool = true) -> CompanionScrollExecutionContext {
            .init(scrolling: state, isActive: active, reduceMotion: true, trace: { _ in })
        }
        let initial = CompanionScrollState(reading: .init())
        var latestPosition = initialPosition()
        let initialMoves = await runModern(context(initial), position: &latestPosition)
        expect(initialMoves == 1 && latestPosition.viewID(type: String.self) == "stream-bottom",
               "initial latest executes the stable footer without a send or latest tap")
        expect(initial.request.target == nil, "initial endpoint command is consumed")
        let repeatedMoves = await runModern(context(initial), position: &latestPosition)
        expect(repeatedMoves == 0, "consumed initial command is not replayed")

        let legacyInitial = CompanionScrollState(reading: .init())
        var legacyMoves = 0
        await context(legacyInitial).perform { _ in legacyMoves += 1 }
        expect(legacyMoves == 0 && legacyInitial.request.revision == 0,
               "legacy initial offset retains its original non-command behavior")

        let history = CompanionScrollState(reading: .init(anchorID: "message:saved", followsLatest: false))
        var historyPosition = initialPosition()
        let historyMoves = await runModern(context(history), position: &historyPosition)
        expect(historyMoves == 1 && historyPosition.viewID(type: String.self) == "message:saved" && historyPosition.edge == nil,
               "saved history retains its own target instead of the latest footer")
        let missing = CompanionScrollState(reading: .init(anchorID: nil, followsLatest: false))
        var missingPosition = initialPosition()
        let missingMoves = await runModern(context(missing), position: &missingPosition)
        expect(missingMoves == 0 && missingPosition.edge == nil,
               "history without a saved anchor is not promoted to latest")

        let hidden = CompanionScrollState(reading: .init())
        var hiddenPosition = initialPosition()
        let hiddenMoves = await runModern(context(hidden, active: false), position: &hiddenPosition)
        expect(hiddenMoves == 0 && hidden.request.target != nil,
               "hidden initial latest neither moves nor consumes its command")
        let revealedMoves = await runModern(context(hidden), position: &hiddenPosition)
        expect(revealedMoves == 1 && hiddenPosition.viewID(type: String.self) == "stream-bottom",
               "initial latest can execute when the page becomes active")

        let gesture = CompanionScrollState(reading: .init())
        let captured = context(gesture)
        gesture.setInteraction(true)
        var gesturePosition = initialPosition()
        let gestureMoves = await runModern(captured, position: &gesturePosition)
        expect(gestureMoves == 0 && gesturePosition.edge == nil,
               "a gesture cancels initial latest before deferred execution")

        let cancelled = CompanionScrollState(reading: .init())
        let cancelledTask = Task { @MainActor in
            var cancelledPosition = initialPosition()
            return await runModern(context(cancelled), position: &cancelledPosition)
        }
        cancelledTask.cancel()
        let cancelledMoves = await cancelledTask.value
        expect(cancelledMoves == 0 && cancelled.request.target != nil,
               "task cancellation prevents deferred initial positioning")
        print("Native ScrollPosition value contract: \(checks) checks, \(failures) failures; no rendered lazy layout acceptance")
        if failures > 0 { exit(1) }
    }
}
''')
binary = args.output / "position-contract"
subprocess.run(["swiftc", "-parse-as-library", "-swift-version", "5", "-strict-concurrency=complete",
                "-warnings-as-errors", "-target", f"{platform.machine()}-apple-macos15.0",
                str(repo / "apps/ios/SoloCompass/Views/CompanionHome/CompanionScrollIntent.swift"),
                str(fixture), "-o", str(binary)], check=True)
result = subprocess.run([str(binary)], capture_output=True, text=True)
(args.output / "results.log").write_text(result.stdout + result.stderr)
(args.output / "provenance.json").write_text(json.dumps({
    "source": "Shipping execution context, modern invocation, destination closure, reading model and ScrollIntent; copied without control-flow edits",
    "adapter_sha256": hashlib.sha256(adapter.encode()).hexdigest(),
    "execution_context_sha256": hashlib.sha256(context.encode()).hexdigest(),
    "modern_invocation": invocation,
    "position_initializer": initializer,
    "scope": "Real SwiftUI ScrollPosition value semantics; not a native keyboard or frame-rate test",
    "exit_code": result.returncode,
}, indent=2) + "\n")
print(result.stdout, end="")
if result.stderr:
    print(result.stderr, end="")
raise SystemExit(result.returncode)
