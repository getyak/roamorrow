"""Run the shipping audio-session controller against an inert audio boundary."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
repo = Path(__file__).resolve().parents[2]
source = (repo / "apps/ios/SoloCompass/Services/CompanionMediaService.swift").read_text()
start = source.index("@MainActor\n@Observable\nfinal class CompanionAudioSession")
end = source.index("/// Explicit transcription action;", start)
args.output.mkdir(parents=True, exist_ok=True)
controller = args.output / "ShippingAudioSession.swift"
controller.write_text("import Foundation\nimport Observation\nimport OSLog\n" + source[start:end])
binary = args.output / "companion-audio-host"
subprocess.run(["swiftc", "-D", "DEBUG", "-strict-concurrency=complete", "-warnings-as-errors", "-swift-version", "5",
                str(controller), str(Path(__file__).with_suffix(".swift")), "-o", str(binary)], check=True)
result = subprocess.run([str(binary)], capture_output=True, text=True)
(args.output / "results.log").write_text(result.stdout + result.stderr)
(args.output / "provenance.json").write_text(json.dumps({
    "source": "apps/ios/SoloCompass/Services/CompanionMediaService.swift:CompanionAudioSession",
    "controller_sha256": hashlib.sha256(controller.read_bytes()).hexdigest(),
    "boundary": "Inert audio framework; no microphone, playback device, or provider request",
    "configuration": "Debug, Swift 5, complete concurrency checking, warnings as errors",
    "exit_code": result.returncode,
}, indent=2) + "\n")
print(result.stdout, end="")
if result.stderr:
    print(result.stderr, end="")
raise SystemExit(result.returncode)
