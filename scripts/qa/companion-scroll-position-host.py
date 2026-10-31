"""Check the shipping destination adapter with real SwiftUI position values."""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import textwrap

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
repo = Path(__file__).resolve().parents[2]
source = (repo / "apps/ios/SoloCompass/Views/CompanionHome/CompanionScrollObservation.swift").read_text()
owner = source.index("private struct CompanionModernScrollExecution")
start = source.index("await execution.perform { target in", owner) + len("await execution.perform { target in")
end = source.index("\n                }", start)
adapter = textwrap.dedent(source[start:end]).strip()
args.output.mkdir(parents=True, exist_ok=True)
fixture = args.output / "PositionContract.swift"
fixture.write_text("import SwiftUI\n@MainActor func apply(_ target: String, to position: inout ScrollPosition) {\n"
                   + adapter + "\n}\n" + r'''
@main @MainActor
struct PositionContract {
    static var failures = 0
    static var checks = 0
    static func expect(_ value: Bool, _ label: String) {
        checks += 1
        if !value { failures += 1; print("FAIL: \(label)") }
    }
    static func main() {
        var position = ScrollPosition(idType: String.self)
        apply("message:source", to: &position)
        expect(position.edge == nil, "history does not retain an endpoint")
        expect(position.viewID(type: String.self) == "message:source", "history retains the requested stable row")
        apply("stream-bottom", to: &position)
        expect(position.edge == .bottom, "latest is a native bottom-edge position")
        expect(position.viewID == nil, "latest must not retain a virtual footer view identity")
        apply("message:other-source", to: &position)
        expect(position.edge == nil, "history releases the previous latest edge")
        expect(position.viewID(type: String.self) == "message:other-source", "history switches to the new source row")
        apply("stream-bottom", to: &position)
        apply("stream-bottom", to: &position)
        expect(position.edge == .bottom && position.viewID == nil, "latest remains an endpoint after repeated semantic actions")
        apply("message:stream-bottom", to: &position)
        expect(position.viewID(type: String.self) == "message:stream-bottom" && position.edge == nil,
               "only the exact endpoint marker selects edge positioning")
        print("Native ScrollPosition value contract: \(checks) checks, \(failures) failures; no rendered lazy layout acceptance")
        if failures > 0 { exit(1) }
    }
}
''')
binary = args.output / "position-contract"
subprocess.run(["swiftc", "-parse-as-library", "-swift-version", "5", "-strict-concurrency=complete",
                "-warnings-as-errors", "-target", f"{platform.machine()}-apple-macos15.0",
                str(fixture), "-o", str(binary)], check=True)
result = subprocess.run([str(binary)], capture_output=True, text=True)
(args.output / "results.log").write_text(result.stdout + result.stderr)
(args.output / "provenance.json").write_text(json.dumps({
    "source": "CompanionModernScrollExecution destination closure, copied without control-flow edits",
    "adapter_sha256": hashlib.sha256(adapter.encode()).hexdigest(),
    "scope": "Real SwiftUI ScrollPosition value semantics; not a native keyboard or frame-rate test",
    "exit_code": result.returncode,
}, indent=2) + "\n")
print(result.stdout, end="")
if result.stderr:
    print(result.stderr, end="")
raise SystemExit(result.returncode)
