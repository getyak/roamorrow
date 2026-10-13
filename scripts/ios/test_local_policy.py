#!/usr/bin/env python3
"""Tests for the unified Solo Compass local-simulator policy.

These are real subprocess tests. Every simulator command is a fake binary on
``PATH`` (or a fixture file), so no test ever invokes ``xcrun``, boots a
simulator, or runs ``xcodebuild``.

Covered:
  * booted iPhone SE / iPad never override the declared primary iPhone
  * auto-selection ignores non-iOS runtimes (watchOS/tvOS never win)
  * explicit IOS_SIMULATOR_ID is honored and validated (fail closed)
  * SIMULATOR_UDID is validated through the live inventory and must agree
  * frozen primary|compact|ipad profile API (plus daily alias) and family match
  * newest numbered iPhone / SE-last fallback
  * compact/ipad profiles require an explicit ID in the portable fallback
  * compact/ipad require a nonempty DEV_IOS_REASON outside CI when the
    host helper is absent (the helper enforces it when present)
  * explicit IOS_DERIVED_DATA_PATH never falls back to the global DerivedData
  * relative IOS_DERIVED_DATA_PATH resolves against the entry cwd and is
    shared by the build and the app lookup
  * the reexec path speaks dev-ios-session's strict contract: daily alias
    normalized, explicit names canonicalized to UDIDs (read-only), mismatched
    or bogus IDs fail before the helper is invoked, empty selection keeps the
    helper's authoritative allowlist choice (strict fake-helper double)
  * boot/bootstatus failures fail the run instead of being hidden
  * helper reexec preserves entrypoint args and runs before simulator use
  * CI=true and CI=1 skip the helper and use the deterministic fallback
  * invalid journey never reaches the helper or the simulator
  * explicitly invalid DEV_IOS_SESSION_BIN fails closed
  * two-device harness requires SIM_B and DEV_IOS_REASON before any mutation
  * two-device harness fails closed on a missing or empty allowlist
  * two-device harness takes the shared shlock, fails busy, and only cleans up
    its own lock and the devices it started

macOS-only tests (helper reexec, /usr/bin/shlock reservation) carry a
``skipUnless`` with the exact requirement. Skipped tests are never counted as
passed: CI runs the portable subset on Linux and the full suite with skips
*disallowed* on the macOS job (see .github/workflows/ios-ci.yml).
"""

from __future__ import annotations

import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from os.path import dirname
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SELECTOR = REPO_ROOT / "scripts" / "ios" / "select-simulator.py"
SESSION_LIB = REPO_ROOT / "scripts" / "ios" / "session.sh"
EVALUATOR = REPO_ROOT / "scripts" / "sc-evaluator" / "run.sh"
RUBRIC = REPO_ROOT / "scripts" / "user-story-rubric" / "run.sh"
EXECUTOR = REPO_ROOT / "scripts" / "sc-executor" / "run.sh"
TWO_SIM = REPO_ROOT / "scripts" / "qa" / "two-sim-friend-loop.sh"

# Lock-reservation tests need the real machine-wide shlock the harness (and
# dev-ios-session) uses. They are macOS-only and must keep an exact reason.
requires_shlock = unittest.skipUnless(
    sys.platform == "darwin" and Path("/usr/bin/shlock").exists(),
    "requires macOS /usr/bin/shlock (machine-wide two-device reservation)",
)

RT = "com.apple.CoreSimulator.SimRuntime.iOS-26-4"
PRO_UDID = "11111111-1111-1111-1111-111111111111"
SE_UDID = "22222222-2222-2222-2222-222222222222"
IPAD_UDID = "33333333-3333-3333-3333-333333333333"
IP16_UDID = "44444444-4444-4444-4444-444444444444"
IP15_UDID = "55555555-5555-5555-5555-555555555555"
BOGUS_UDID = "99999999-9999-9999-9999-999999999999"
WATCH_UDID = "66666666-6666-6666-6666-666666666666"

FAKE_XCRUN = """#!/usr/bin/env bash
printf '%s\\n' "$*" >> "${FAKE_XCRUN_LOG:-/dev/null}"
if [[ "${1:-}" == "simctl" && "${2:-}" == "list" && "${3:-}" == "devices" ]]; then
  for _arg in "${4:-}" "${5:-}"; do
    case "$_arg" in
      --json|-j)
        if [[ -n "${FAKE_SIMCTL_JSON:-}" && -f "${FAKE_SIMCTL_JSON}" ]]; then
          cat "${FAKE_SIMCTL_JSON}"
        fi
        exit 0
        ;;
    esac
  done
fi
if [[ "${1:-}" == "simctl" && "${2:-}" == "boot" ]]; then
  exit "${FAKE_SIMCTL_BOOT_EXIT:-0}"
fi
if [[ "${1:-}" == "simctl" && "${2:-}" == "bootstatus" ]]; then
  exit "${FAKE_SIMCTL_BOOTSTATUS_EXIT:-0}"
fi
exit 0
"""

FAKE_SLEEP = """#!/usr/bin/env bash
exit 0
"""

FAKE_OPEN = """#!/usr/bin/env bash
printf 'open %s\\n' "$*" >> "${FAKE_OPEN_LOG:-/dev/null}"
exit 0
"""

FAKE_HELPER = """#!/usr/bin/env bash
case "${1:-}" in
  is-owner)
    # Mirrors dev-ios-session: ownership requires the exported held marker.
    if [[ "${FAKE_IS_OWNER:-0}" == "1" && "${IOS_AUTOMATION_LOCK_HELD:-}" == "true" ]]; then
      exit 0
    fi
    exit 1
    ;;
  run)
    printf '%s\\n' "$*" >> "${FAKE_HELPER_LOG:-/dev/null}"
    if [[ "${FAKE_HELPER_EXEC:-0}" == "1" ]]; then
      shift 2
      export IOS_AUTOMATION_LOCK_HELD="true"
      export DEV_IOS_SESSION_PID="$$"
      export IOS_SIMULATOR_ID="${FAKE_HELPER_UDID:-${IOS_SIMULATOR_ID:-}}"
      export SIMULATOR_UDID="${FAKE_HELPER_UDID:-${SIMULATOR_UDID:-}}"
      export DEV_IOS_PROFILE="${FAKE_HELPER_PROFILE:-primary}"
      exec "$@"
    fi
    exit "${FAKE_RUN_EXIT:-0}"
    ;;
esac
exit 1
"""

# Interface-faithful double of dev-ios-session's strict resolve_selection:
# only primary|compact|ipad profiles, explicit IOS_SIMULATOR_ID must equal the
# allowlisted UDID (device names are never accepted), compact|ipad need a
# nonempty DEV_IOS_REASON. It rejects exactly what the real helper rejects so
# these tests can never rely on weakening its protocol. Read-only evidence:
# ~/.local/bin/dev-ios-session resolve_selection / command_run.
FAKE_STRICT_HELPER = """#!/usr/bin/env bash
printf '%s\\n' "$*" >> "${FAKE_HELPER_LOG:-/dev/null}"
case "${1:-}" in
  is-owner)
    if [[ "${FAKE_IS_OWNER:-0}" == "1" && "${IOS_AUTOMATION_LOCK_HELD:-}" == "true" ]]; then
      exit 0
    fi
    exit 1
    ;;
  run)
    printf 'run profile=%s udid=%s sim_udid=%s reason=%s\\n' \\
      "${DEV_IOS_PROFILE:-}" "${IOS_SIMULATOR_ID:-}" "${SIMULATOR_UDID:-}" "${DEV_IOS_REASON:-}" \\
      >> "${FAKE_HELPER_ENV_LOG:-/dev/null}"
    profile="${DEV_IOS_PROFILE:-primary}"
    case "$profile" in
      primary | compact | ipad) ;;
      *)
        printf 'Unknown iOS session profile %s\\n' "$profile" >&2
        exit 2
        ;;
    esac
    configured="${FAKE_HELPER_ALLOWLIST_UDID:-11111111-1111-1111-1111-111111111111}"
    explicit="${IOS_SIMULATOR_ID:-}"
    if [[ -n "$explicit" && "$explicit" != "$configured" ]]; then
      printf 'Unexpected device mismatch: profile %s selects allowlisted %s but IOS_SIMULATOR_ID requested %s\\n' \\
        "$profile" "$configured" "$explicit" >&2
      exit 2
    fi
    if [[ "$profile" != "primary" && -z "${DEV_IOS_REASON:-}" ]]; then
      printf 'Profile %s selects a secondary simulator and requires a nonempty --reason or DEV_IOS_REASON\\n' "$profile" >&2
      exit 2
    fi
    shift 2
    export IOS_AUTOMATION_LOCK_HELD="true"
    export DEV_IOS_SESSION_PID="$$"
    export IOS_SIMULATOR_ID="$configured"
    export SIMULATOR_UDID="$configured"
    export DEV_IOS_PROFILE="$profile"
    exec "$@"
    ;;
esac
exit 1
"""

# Fake xcodebuild: faithful to the real tool's -derivedDataPath semantics — a
# relative path resolves against the PROCESS cwd (the evaluator builds inside
# apps/ios). Creates the products dir so app.locate can find it.
FAKE_XCODEBUILD = """#!/usr/bin/env bash
printf '%s\\n' "$*" >> "${FAKE_XCODEBUILD_LOG:-/dev/null}"
dd=""
prev=""
for arg in "$@"; do
  if [[ "$prev" == "-derivedDataPath" ]]; then dd="$arg"; fi
  prev="$arg"
done
[[ -z "$dd" ]] && dd="DerivedData"
case "$dd" in
  /*) ;;
  *) dd="$PWD/$dd" ;;
esac
mkdir -p "$dd/Build/Products/Debug-iphonesimulator/SoloCompass.app"
exit 0
"""


def device(name, udid, state="Shutdown", runtime=RT, available=True):
    return {
        "name": name,
        "udid": udid,
        "state": state,
        "isAvailable": available,
        "runtime": runtime,
    }


def simctl_json(devices):
    runtimes = {}
    for entry in devices:
        item = dict(entry)
        runtime = item.pop("runtime", RT)
        runtimes.setdefault(runtime, []).append(item)
    return json.dumps({"devices": runtimes})


def run_selector(devices, *args, stdin_payload=None):
    payload = stdin_payload if stdin_payload is not None else simctl_json(devices)
    return subprocess.run(
        [sys.executable, str(SELECTOR), *args],
        input=payload,
        capture_output=True,
        text=True,
    )


class SelectorTests(unittest.TestCase):
    def test_booted_se_and_ipad_are_ignored(self):
        proc = run_selector(
            [
                device("iPhone SE (3rd generation)", SE_UDID, state="Booted"),
                device("iPad Pro 11-inch (M4)", IPAD_UDID, state="Booted"),
                device("iPhone 17 Pro", PRO_UDID),
                device("iPhone 16", IP16_UDID),
            ]
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(json.loads(proc.stdout)["udid"], PRO_UDID)

    def test_booted_se_never_overrides_missing_preference(self):
        proc = run_selector(
            [
                device("iPhone SE (3rd generation)", SE_UDID, state="Booted"),
                device("iPhone 16", IP16_UDID),
            ]
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(json.loads(proc.stdout)["udid"], IP16_UDID)

    def test_explicit_ipad_id_is_honored(self):
        proc = run_selector(
            [
                device("iPhone SE (3rd generation)", SE_UDID, state="Booted"),
                device("iPhone 17 Pro", PRO_UDID),
                device("iPad Pro 11-inch (M4)", IPAD_UDID),
            ],
            "--explicit",
            IPAD_UDID,
            "--profile",
            "ipad",
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        payload = json.loads(proc.stdout)
        self.assertEqual(payload["udid"], IPAD_UDID)
        self.assertEqual(payload["source"], "explicit")

    def test_profile_primary_is_accepted_and_is_default(self):
        devices = [device("iPhone 17 Pro", PRO_UDID)]
        for args in ((), ("--profile", "primary")):
            proc = run_selector(devices, *args)
            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertEqual(json.loads(proc.stdout)["udid"], PRO_UDID)

    def test_profile_daily_alias_maps_to_primary(self):
        proc = run_selector([device("iPhone 17 Pro", PRO_UDID)], "--profile", "daily")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(json.loads(proc.stdout)["family"], "iphone")

    def test_resolve_mode_canonicalizes_name_to_udid(self):
        proc = run_selector(
            [device("iPhone 17 Pro", PRO_UDID), device("iPhone 16", IP16_UDID)],
            "--resolve",
            "iPhone 17 Pro",
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout.strip(), PRO_UDID)

    def test_resolve_mode_accepts_udid_passthrough(self):
        proc = run_selector([device("iPhone 17 Pro", PRO_UDID)], "--resolve", PRO_UDID)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout.strip(), PRO_UDID)

    def test_resolve_mode_rejects_bogus_ident(self):
        proc = run_selector(
            [device("iPhone 17 Pro", PRO_UDID)], "--resolve", "iPhone 99 Ultra"
        )
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("refusing to substitute", proc.stderr)
        self.assertEqual(proc.stdout.strip(), "")

    def test_resolve_mode_rejects_non_ios_runtime(self):
        proc = run_selector(
            [
                device(
                    "iPhone 17 Pro",
                    PRO_UDID,
                    runtime="com.apple.CoreSimulator.SimRuntime.watchOS-26-0",
                )
            ],
            "--resolve",
            "iPhone 17 Pro",
        )
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("not available on an iOS runtime", proc.stderr)

    def test_compact_profile_requires_explicit_id(self):
        proc = run_selector(
            [device("iPhone 17 Pro", PRO_UDID), device("iPhone SE (3rd generation)", SE_UDID)],
            "--profile", "compact",
        )
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("requires an explicit IOS_SIMULATOR_ID", proc.stderr)

    def test_compact_profile_honors_explicit_device(self):
        proc = run_selector(
            [device("iPhone 17 Pro", PRO_UDID), device("iPhone SE (3rd generation)", SE_UDID)],
            "--profile", "compact", "--explicit", SE_UDID,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(json.loads(proc.stdout)["udid"], SE_UDID)

    def test_profile_primary_rejects_explicit_ipad(self):
        proc = run_selector(
            [device("iPad Pro 11-inch (M4)", IPAD_UDID)],
            "--explicit",
            IPAD_UDID,
        )
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("expects a iphone device", proc.stderr)

    def test_profile_ipad_rejects_explicit_iphone(self):
        proc = run_selector(
            [device("iPhone 17 Pro", PRO_UDID)],
            "--explicit",
            PRO_UDID,
            "--profile",
            "ipad",
        )
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("expects a ipad device", proc.stderr)

    def test_owner_udid_is_validated_and_must_agree(self):
        devices = [device("iPhone 17 Pro", PRO_UDID), device("iPhone 16", IP16_UDID)]
        ok = run_selector(devices, "--owner-udid", PRO_UDID)
        self.assertEqual(ok.returncode, 0, ok.stderr)
        self.assertEqual(json.loads(ok.stdout)["udid"], PRO_UDID)
        clash = run_selector(devices, "--explicit", PRO_UDID, "--owner-udid", IP16_UDID)
        self.assertNotEqual(clash.returncode, 0)
        self.assertIn("disagree", clash.stderr)

    def test_unknown_owner_udid_fails_closed(self):
        proc = run_selector([device("iPhone 17 Pro", PRO_UDID)], "--owner-udid", BOGUS_UDID)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("refusing to substitute", proc.stderr)

    def test_watch_device_is_rejected(self):
        proc = run_selector(
            [device("Apple Watch Series 10 (46mm)", WATCH_UDID)],
            "--explicit",
            WATCH_UDID,
        )
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("unsupported", proc.stderr)

    def test_auto_selection_ignores_non_ios_runtimes(self):
        # An iPhone-named entry under a watchOS runtime must never win over a
        # real iOS device (regression: auto selection filtered by name only).
        proc = run_selector(
            [
                device(
                    "iPhone 17 Pro",
                    BOGUS_UDID,
                    runtime="com.apple.CoreSimulator.SimRuntime.watchOS-26-0",
                ),
                device("iPhone 16", IP16_UDID),
            ]
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        payload = json.loads(proc.stdout)
        self.assertEqual(payload["udid"], IP16_UDID)
        self.assertEqual(payload["ios_version"], "26.4")

    def test_auto_selection_fails_when_only_non_ios_runtimes(self):
        proc = run_selector(
            [
                device(
                    "iPhone 17 Pro",
                    PRO_UDID,
                    runtime="com.apple.CoreSimulator.SimRuntime.tvOS-26-0",
                ),
                device(
                    "Apple Watch Series 10 (46mm)",
                    WATCH_UDID,
                    runtime="com.apple.CoreSimulator.SimRuntime.watchOS-26-0",
                ),
            ]
        )
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("iOS runtime", proc.stderr)

    def test_explicit_non_ios_runtime_iphone_is_rejected(self):
        proc = run_selector(
            [
                device(
                    "iPhone 16",
                    IP16_UDID,
                    runtime="com.apple.CoreSimulator.SimRuntime.watchOS-26-0",
                )
            ],
            "--explicit",
            IP16_UDID,
        )
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("not available on an iOS runtime", proc.stderr)

    def test_unknown_explicit_id_fails_closed(self):
        proc = run_selector(
            [device("iPhone 17 Pro", PRO_UDID), device("iPhone 16", IP16_UDID)],
            "--explicit",
            BOGUS_UDID,
        )
        self.assertNotEqual(proc.returncode, 0)
        self.assertEqual(proc.stdout.strip(), "")
        self.assertIn("refusing to substitute", proc.stderr)

    def test_newest_numbered_iphone_wins_when_preferred_absent(self):
        proc = run_selector(
            [
                device("iPhone 15", IP15_UDID),
                device("iPhone 16", IP16_UDID),
                device("iPhone SE (3rd generation)", SE_UDID),
            ]
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(json.loads(proc.stdout)["udid"], IP16_UDID)

    def test_se_is_last_resort(self):
        proc = run_selector([device("iPhone SE (3rd generation)", SE_UDID)])
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(json.loads(proc.stdout)["udid"], SE_UDID)

    def test_unavailable_devices_are_ignored(self):
        proc = run_selector(
            [
                device("iPhone 17 Pro", PRO_UDID, available=False),
                device("iPhone 16", IP16_UDID),
            ]
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(json.loads(proc.stdout)["udid"], IP16_UDID)

    def test_ipad_profile_requires_explicit_id(self):
        proc = run_selector([device("iPad Pro 11-inch (M4)", IPAD_UDID)], "--profile", "ipad")
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("requires an explicit", proc.stderr)

    def test_only_ipad_available_fails(self):
        proc = run_selector([device("iPad Pro 11-inch (M4)", IPAD_UDID)])
        self.assertNotEqual(proc.returncode, 0)


class ScriptPolicyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="ios-policy-"))
        self.bin_dir = self.tmp / "bin"
        self.home_dir = self.tmp / "home"
        self.findings_dir = self.tmp / "findings"
        self.screenshots_dir = self.tmp / "screenshots"
        self.journeys_dir = self.tmp / "journeys"
        for path in (
            self.bin_dir,
            self.home_dir,
            self.findings_dir,
            self.screenshots_dir,
            self.journeys_dir,
        ):
            path.mkdir(parents=True, exist_ok=True)
        # Minimal shell journey: avoids any YAML dependency while still
        # exercising the real entrypoint wiring.
        (self.journeys_dir / "tiny.sh").write_text("#!/usr/bin/env bash\n", encoding="utf-8")

        self.xcrun_log = self.tmp / "xcrun.log"
        self.open_log = self.tmp / "open.log"
        self.helper_log = self.tmp / "helper.log"
        self.helper_env_log = self.tmp / "helper-env.log"
        self.xcodebuild_log = self.tmp / "xcodebuild.log"
        self.simctl_json_file = self.tmp / "simctl.json"
        self.allowlist_file = self.tmp / "simulator-allowlist.tsv"
        self.lock_file = self.tmp / "ios-automation.xcodebuild.lock"

        self._write_exec(self.bin_dir / "xcrun", FAKE_XCRUN)
        self._write_exec(self.bin_dir / "open", FAKE_OPEN)
        self._write_exec(self.bin_dir / "sleep", FAKE_SLEEP)
        self._write_exec(self.bin_dir / "xcodebuild", FAKE_XCODEBUILD)
        self.helper = self.bin_dir / "dev-ios-session"
        self._write_exec(self.helper, FAKE_HELPER)
        self.strict_helper = self.bin_dir / "dev-ios-session-strict"
        self._write_exec(self.strict_helper, FAKE_STRICT_HELPER)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    @staticmethod
    def _write_exec(path: Path, body: str):
        path.write_text(body, encoding="utf-8")
        path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    def base_env(self, **overrides):
        env = os.environ.copy()
        # Hermetic PATH: fakes first, then only fixed system locations plus the
        # running interpreter's dir. The host's ~/.local/bin (real
        # dev-ios-session) must never leak into these tests.
        system_path = [
            dirname(os.path.realpath(sys.executable)),
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ]
        env["PATH"] = os.pathsep.join([str(self.bin_dir), *system_path])
        env["REPO_ROOT"] = str(REPO_ROOT)
        env["HOME"] = str(self.home_dir)
        env["FAKE_XCRUN_LOG"] = str(self.xcrun_log)
        env["FAKE_OPEN_LOG"] = str(self.open_log)
        env["FAKE_HELPER_LOG"] = str(self.helper_log)
        env["FAKE_HELPER_ENV_LOG"] = str(self.helper_env_log)
        env["FAKE_XCODEBUILD_LOG"] = str(self.xcodebuild_log)
        env["FAKE_SIMCTL_JSON"] = str(self.simctl_json_file)
        env["SC_EVALUATOR_FINDINGS_DIR"] = str(self.findings_dir)
        env["SC_EVALUATOR_SCREENSHOTS_DIR"] = str(self.screenshots_dir)
        env["SC_EVALUATOR_JOURNEYS_DIR"] = str(self.journeys_dir)
        for key in (
            "CI",
            "IOS_SIMULATOR_ID",
            "SIMULATOR_UDID",
            "DEV_IOS_PROFILE",
            "DEV_IOS_SESSION_BIN",
            "DEV_IOS_SESSION_HELPER",
            "DEV_IOS_SESSION_ID",
            "DEV_IOS_BORROWED",
            "DEV_IOS_REASON",
            "DEV_IOS_ALLOWLIST",
            "IOS_AUTOMATION_LOCK_FILE",
            "IOS_AUTOMATION_LOCK_HELD",
            "IOS_DERIVED_DATA_PATH",
            "IOS_ARTIFACT_DIR",
            "SC_EVALUATOR_KEEP_SCREENSHOTS",
            "FAKE_IS_OWNER",
            "FAKE_HELPER_EXEC",
            "FAKE_HELPER_UDID",
            "FAKE_HELPER_PROFILE",
            "FAKE_HELPER_ALLOWLIST_UDID",
            "FAKE_RUN_EXIT",
            "FAKE_SIMCTL_BOOT_EXIT",
            "FAKE_SIMCTL_BOOTSTATUS_EXIT",
            "SIM_B",
            "SIM_A",
            "FLAG",
            "ARTIFACTS",
        ):
            env.pop(key, None)
        env.update(overrides)
        return env

    def _run(self, args, env, stdin="", cwd=None):
        return subprocess.run(
            [str(a) for a in args],
            cwd=str(cwd or REPO_ROOT),
            env=env,
            input=stdin,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )

    def _log(self, path: Path) -> str:
        return path.read_text(encoding="utf-8") if path.exists() else ""

    def _write_simctl(self, devices):
        self.simctl_json_file.write_text(simctl_json(devices), encoding="utf-8")

    def _write_allowlist(self, udids):
        labels = ["Primary iPhone", "Compact iPhone", "iPad"]
        lines = [
            f"{udid}\t{labels[i] if i < len(labels) else f'Device {i}'}"
            for i, udid in enumerate(udids)
        ]
        self.allowlist_file.write_text("\n".join(lines) + "\n", encoding="utf-8")

    def _two_sim_env(self, **overrides):
        env = self.base_env(
            SIM_B="iPhone 16",
            DEV_IOS_REASON="unit test reservation",
            FLAG="off",
            DEV_IOS_ALLOWLIST=str(self.allowlist_file),
            IOS_AUTOMATION_LOCK_FILE=str(self.lock_file),
            ARTIFACTS=str(self.tmp / "two-sim-artifacts"),
        )
        env.update(overrides)
        return env

    # ------------------------------------------------------------------
    # helper reexec / arg preservation
    # ------------------------------------------------------------------
    @unittest.skipUnless(sys.platform == "darwin", "helper reexec is local macOS only")
    def test_evaluator_reexec_preserves_journey_args(self):
        env = self.base_env(DEV_IOS_SESSION_BIN=str(self.helper))
        proc = self._run([EVALUATOR, "tiny", "--no-build"], env)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(
            self._log(self.helper_log).strip(),
            f"run -- {EVALUATOR} tiny --no-build",
        )
        # No simulator interaction happened before the helper took over.
        self.assertEqual(self._log(self.xcrun_log), "")
        self.assertEqual(list(self.findings_dir.iterdir()), [])

    @unittest.skipUnless(sys.platform == "darwin", "helper reexec is local macOS only")
    def test_rubric_reexec_preserves_entrypoint(self):
        env = self.base_env(DEV_IOS_SESSION_BIN=str(self.helper))
        proc = self._run([RUBRIC], env)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(self._log(self.helper_log).strip(), f"run -- {RUBRIC}")
        self.assertEqual(self._log(self.xcrun_log), "")

    @unittest.skipUnless(sys.platform == "darwin", "helper reexec is local macOS only")
    def test_executor_apply_reexecs_before_mutation(self):
        env = self.base_env(DEV_IOS_SESSION_BIN=str(self.helper))
        before = subprocess.run(
            ["git", "status", "--porcelain"], cwd=str(REPO_ROOT), capture_output=True, text=True
        ).stdout
        proc = self._run([EXECUTOR, "--apply"], env)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(self._log(self.helper_log).strip(), f"run -- {EXECUTOR} --apply")
        self.assertEqual(self._log(self.xcrun_log), "")
        after = subprocess.run(
            ["git", "status", "--porcelain"], cwd=str(REPO_ROOT), capture_output=True, text=True
        ).stdout
        self.assertEqual(before, after)

    @unittest.skipUnless(sys.platform == "darwin", "helper reexec is local macOS only")
    def test_helper_interface_primary_profile_and_both_udids(self):
        # Simulates the real dev-ios-session interface: `run` execs the
        # entrypoint with DEV_IOS_PROFILE=primary, IOS_SIMULATOR_ID and
        # SIMULATOR_UDID exported. The selector must accept `primary` and
        # validate both UDIDs instead of failing on an unknown profile.
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self.base_env(
            DEV_IOS_SESSION_BIN=str(self.helper),
            FAKE_IS_OWNER="1",
            FAKE_HELPER_EXEC="1",
            FAKE_HELPER_UDID=PRO_UDID,
            FAKE_HELPER_PROFILE="primary",
        )
        proc = self._run([EVALUATOR, "tiny", "--no-build"], env)
        self.assertNotIn("unknown profile", proc.stderr)
        self.assertEqual(proc.returncode, 2, proc.stderr + proc.stdout)
        report = sorted(self.findings_dir.glob("*.md"))[0].read_text(encoding="utf-8")
        self.assertIn(f"udid={PRO_UDID}", report)
        self.assertIn("source=explicit", report)

    # ------------------------------------------------------------------
    # CI fallback / fail-closed
    # ------------------------------------------------------------------
    def test_ci_skips_helper_and_uses_deterministic_fallback(self):
        self._write_simctl(
            [
                device("iPhone SE (3rd generation)", SE_UDID, state="Booted"),
                device("iPad Pro 11-inch (M4)", IPAD_UDID, state="Booted"),
                device("iPhone 17 Pro", PRO_UDID),
            ]
        )
        env = self.base_env(CI="true", DEV_IOS_SESSION_BIN=str(self.helper))
        proc = self._run([EVALUATOR, "tiny", "--no-build"], env)
        # app.locate fails because HOME points at an empty temp dir.
        self.assertEqual(proc.returncode, 2, proc.stderr + proc.stdout)
        self.assertEqual(self._log(self.helper_log), "")
        xcrun_log = self._log(self.xcrun_log)
        self.assertIn("simctl list devices available --json", xcrun_log)
        self.assertIn(f"simctl boot {PRO_UDID}", xcrun_log)

        reports = sorted(self.findings_dir.glob("*.md"))
        self.assertEqual(len(reports), 1, reports)
        report = reports[0].read_text(encoding="utf-8")
        self.assertIn(f"udid={PRO_UDID}", report)
        self.assertIn("name=iPhone 17 Pro", report)
        self.assertIn("source=auto", report)
        self.assertNotIn(SE_UDID, report)
        self.assertNotIn(IPAD_UDID, report)

        # Full evaluator startup must also emit the JSON shadow (guards against
        # FINDINGS_FILE / FINDINGS_JSON assignment regressions).
        shadows = sorted(self.findings_dir.glob("*.json"))
        self.assertEqual(len(shadows), 1, shadows)
        doc = json.loads(shadows[0].read_text(encoding="utf-8"))
        self.assertEqual(doc["simulator"], "iPhone 17 Pro")
        self.assertEqual(doc["steps"][0]["name"], "simulator.resolve")
        self.assertEqual(doc["steps"][0]["status"], "PASS")
        self.assertEqual(doc["summary"]["result"], "FAIL")

    def test_ci_env_one_skips_helper(self):
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self.base_env(CI="1", DEV_IOS_SESSION_BIN=str(self.helper))
        proc = self._run([EVALUATOR, "tiny", "--no-build"], env)
        self.assertEqual(proc.returncode, 2, proc.stderr + proc.stdout)
        self.assertEqual(self._log(self.helper_log), "")
        self.assertIn("simctl list devices available --json", self._log(self.xcrun_log))

    def test_ci_env_one_ignores_invalid_helper_config(self):
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self.base_env(CI="1", DEV_IOS_SESSION_BIN=str(self.tmp / "missing-helper"))
        proc = self._run([EVALUATOR, "tiny", "--no-build"], env)
        self.assertEqual(proc.returncode, 2, proc.stderr + proc.stdout)
        self.assertNotIn("not executable", proc.stderr)
        self.assertIn("simctl list devices available --json", self._log(self.xcrun_log))

    def test_ci_explicit_ipad_id_is_used(self):
        self._write_simctl(
            [
                device("iPhone 17 Pro", PRO_UDID),
                device("iPad Pro 11-inch (M4)", IPAD_UDID, state="Booted"),
            ]
        )
        env = self.base_env(
            CI="true",
            IOS_SIMULATOR_ID=IPAD_UDID,
            DEV_IOS_PROFILE="ipad",
            DEV_IOS_SESSION_BIN=str(self.helper),
        )
        proc = self._run([EVALUATOR, "tiny", "--no-build"], env)
        self.assertEqual(proc.returncode, 2, proc.stderr + proc.stdout)
        report = sorted(self.findings_dir.glob("*.md"))[0].read_text(encoding="utf-8")
        self.assertIn(f"udid={IPAD_UDID}", report)
        self.assertIn("source=explicit", report)
        self.assertNotIn(f"simctl boot {PRO_UDID}", self._log(self.xcrun_log))

    def test_ci_unknown_explicit_id_fails_closed(self):
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self.base_env(CI="true", IOS_SIMULATOR_ID=BOGUS_UDID)
        proc = self._run([EVALUATOR, "tiny", "--no-build"], env)
        self.assertEqual(proc.returncode, 2)
        self.assertIn("refusing to substitute", proc.stderr)
        self.assertNotIn("simctl boot", self._log(self.xcrun_log))

    def test_invalid_journey_never_reaches_helper_or_simulator(self):
        env = self.base_env(DEV_IOS_SESSION_BIN=str(self.helper))
        proc = self._run([EVALUATOR, "definitely-not-a-journey"], env)
        self.assertEqual(proc.returncode, 2)
        self.assertEqual(self._log(self.helper_log), "")
        self.assertEqual(self._log(self.xcrun_log), "")

    @unittest.skipUnless(sys.platform == "darwin", "helper reexec is local macOS only")
    def test_invalid_dev_ios_session_bin_fails_closed(self):
        env = self.base_env(DEV_IOS_SESSION_BIN=str(self.tmp / "missing-helper"))
        proc = self._run([EVALUATOR, "tiny", "--no-build"], env)
        self.assertEqual(proc.returncode, 2)
        self.assertIn("DEV_IOS_SESSION_BIN is set but not executable", proc.stderr)
        self.assertEqual(self._log(self.xcrun_log), "")

    # ------------------------------------------------------------------
    # auxiliary-profile reason enforcement (portable fallback)
    # ------------------------------------------------------------------
    def test_aux_profile_requires_reason_when_helper_absent(self):
        self.helper.unlink()
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self.base_env(DEV_IOS_PROFILE="compact")
        proc = self._session_bash("ios_select_simulator_json 'iPhone 17 Pro'", env)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("DEV_IOS_REASON", proc.stderr)
        self.assertEqual(self._log(self.xcrun_log), "")

    def test_aux_profile_whitespace_reason_is_rejected(self):
        self.helper.unlink()
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self.base_env(DEV_IOS_PROFILE="ipad", DEV_IOS_REASON="   ")
        proc = self._session_bash("ios_select_simulator_json 'iPhone 17 Pro'", env)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("DEV_IOS_REASON", proc.stderr)
        self.assertEqual(self._log(self.xcrun_log), "")

    def test_aux_profile_with_reason_selects(self):
        self.helper.unlink()
        self._write_simctl([device("iPhone SE (3rd generation)", SE_UDID)])
        env = self.base_env(
            DEV_IOS_PROFILE="compact", DEV_IOS_REASON="keyboard layout check",
            IOS_SIMULATOR_ID=SE_UDID,
        )
        proc = self._session_bash("ios_select_simulator_json 'iPhone 17 Pro'", env)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(json.loads(proc.stdout)["udid"], SE_UDID)

    def test_aux_profile_reason_check_skipped_in_ci(self):
        self.helper.unlink()
        self._write_simctl([device("iPhone SE (3rd generation)", SE_UDID)])
        env = self.base_env(CI="true", DEV_IOS_PROFILE="compact", IOS_SIMULATOR_ID=SE_UDID)
        proc = self._session_bash("ios_select_simulator_json 'iPhone 17 Pro'", env)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(json.loads(proc.stdout)["udid"], SE_UDID)

    def test_daily_alias_never_requires_reason(self):
        self.helper.unlink()
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self.base_env(DEV_IOS_PROFILE="daily")
        proc = self._session_bash("ios_select_simulator_json 'iPhone 17 Pro'", env)
        self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_aux_profile_reason_enforced_by_helper_when_present(self):
        # With the helper resolvable the helper owns enforcement (interface
        # evidence: dev-ios-session resolve_selection dies for compact|ipad
        # without a nonempty --reason/DEV_IOS_REASON). The portable fallback
        # only enforces when the helper is absent.
        self._write_simctl([device("iPhone SE (3rd generation)", SE_UDID)])
        env = self.base_env(DEV_IOS_PROFILE="compact", SIMULATOR_UDID=SE_UDID)
        proc = self._session_bash("ios_select_simulator_json 'iPhone 17 Pro'", env)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(json.loads(proc.stdout)["udid"], SE_UDID)

    def test_evaluator_rejects_aux_profile_without_reason_helper_absent(self):
        self.helper.unlink()
        env = self.base_env(DEV_IOS_PROFILE="compact")
        proc = self._run([EVALUATOR, "tiny", "--no-build"], env)
        self.assertEqual(proc.returncode, 2, proc.stderr + proc.stdout)
        self.assertIn("DEV_IOS_REASON", proc.stderr)
        self.assertEqual(self._log(self.xcrun_log), "")

    # ------------------------------------------------------------------
    # helper selection normalization (portable)
    #
    # Before is-owner/run the reexec path must speak the host helper's strict
    # resolve_selection contract: primary|compact|ipad profiles and UDIDs.
    # ------------------------------------------------------------------
    def _prepare(self, env):
        return self._session_bash(
            'ios_session_prepare_helper_selection'
            ' && printf "profile=%s id=%s owner=%s" "$DEV_IOS_PROFILE"'
            ' "${IOS_SIMULATOR_ID:-}" "${SIMULATOR_UDID:-}"',
            env,
        )

    def test_prepare_normalizes_daily_alias_and_default_selection(self):
        # daily -> primary; with no explicit device nothing is exported, so the
        # helper's allowlist selection stays authoritative (never an auto pick).
        self._write_simctl(
            [device("iPhone 17 Pro", PRO_UDID), device("iPhone 16", IP16_UDID)]
        )
        env = self.base_env(DEV_IOS_PROFILE="Daily")
        proc = self._prepare(env)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout, "profile=primary id= owner=")
        self.assertEqual(self._log(self.xcrun_log), "")

    def test_prepare_canonicalizes_explicit_names_to_udids(self):
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self.base_env(
            IOS_SIMULATOR_ID="iPhone 17 Pro", SIMULATOR_UDID="iPhone 17 Pro"
        )
        proc = self._prepare(env)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout, f"profile=primary id={PRO_UDID} owner={PRO_UDID}")

    def test_prepare_forwards_owner_name_as_explicit_request(self):
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self.base_env(SIMULATOR_UDID="iPhone 17 Pro")
        proc = self._prepare(env)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout, f"profile=primary id={PRO_UDID} owner={PRO_UDID}")

    def test_prepare_rejects_mismatched_ids(self):
        self._write_simctl(
            [device("iPhone 17 Pro", PRO_UDID), device("iPhone 16", IP16_UDID)]
        )
        env = self.base_env(IOS_SIMULATOR_ID=PRO_UDID, SIMULATOR_UDID=IP16_UDID)
        proc = self._prepare(env)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("disagree", proc.stderr)

    def test_prepare_rejects_bogus_explicit_id(self):
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self.base_env(IOS_SIMULATOR_ID=BOGUS_UDID)
        proc = self._prepare(env)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("refusing to substitute", proc.stderr)

    def test_prepare_rejects_unknown_profile(self):
        env = self.base_env(DEV_IOS_PROFILE="banana")
        proc = self._prepare(env)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("unknown profile", proc.stderr)

    def test_prepare_rejects_non_ios_runtime_name(self):
        self._write_simctl(
            [
                device(
                    "iPhone 17 Pro",
                    PRO_UDID,
                    runtime="com.apple.CoreSimulator.SimRuntime.watchOS-26-0",
                )
            ]
        )
        env = self.base_env(IOS_SIMULATOR_ID="iPhone 17 Pro")
        proc = self._prepare(env)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("not available on an iOS runtime", proc.stderr)

    # ------------------------------------------------------------------
    # strict helper interface contract (macOS reexec path)
    # ------------------------------------------------------------------
    def _strict_env(self, **overrides):
        env = self.base_env(DEV_IOS_SESSION_BIN=str(self.strict_helper))
        env.update(overrides)
        return env

    @unittest.skipUnless(sys.platform == "darwin", "helper reexec is local macOS only")
    def test_reexec_daily_alias_normalized_before_strict_helper(self):
        env = self._strict_env(DEV_IOS_PROFILE="Daily")
        proc = self._session_bash("ios_session_reexec_if_needed /usr/bin/true", env)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(
            self._log(self.helper_log).splitlines(),
            ["is-owner", "run -- /usr/bin/true"],
        )
        self.assertIn("run profile=primary udid= sim_udid=", self._log(self.helper_env_log))
        self.assertNotIn("Unknown iOS session profile", proc.stderr)

    @unittest.skipUnless(sys.platform == "darwin", "helper reexec is local macOS only")
    def test_reexec_canonicalizes_explicit_name_before_strict_helper(self):
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self._strict_env(IOS_SIMULATOR_ID="iPhone 17 Pro")
        proc = self._session_bash("ios_session_reexec_if_needed /usr/bin/true", env)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn(
            f"run profile=primary udid={PRO_UDID} sim_udid={PRO_UDID}",
            self._log(self.helper_env_log),
        )
        self.assertNotIn("Unexpected device mismatch", proc.stderr)
        log = self._log(self.xcrun_log)
        self.assertNotIn("simctl boot", log)
        self.assertNotIn("simctl install", log)
        self.assertNotIn("simctl launch", log)

    @unittest.skipUnless(sys.platform == "darwin", "helper reexec is local macOS only")
    def test_reexec_mismatched_ids_fail_before_helper(self):
        self._write_simctl(
            [device("iPhone 17 Pro", PRO_UDID), device("iPhone 16", IP16_UDID)]
        )
        env = self._strict_env(IOS_SIMULATOR_ID=PRO_UDID, SIMULATOR_UDID=IP16_UDID)
        proc = self._session_bash("ios_session_reexec_if_needed /usr/bin/true", env)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("disagree", proc.stderr)
        self.assertEqual(self._log(self.helper_log), "")
        self.assertNotIn("simctl boot", self._log(self.xcrun_log))

    @unittest.skipUnless(sys.platform == "darwin", "helper reexec is local macOS only")
    def test_reexec_bogus_selection_fails_before_helper(self):
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self._strict_env(IOS_SIMULATOR_ID=BOGUS_UDID)
        proc = self._session_bash("ios_session_reexec_if_needed /usr/bin/true", env)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("refusing to substitute", proc.stderr)
        self.assertEqual(self._log(self.helper_log), "")

    @unittest.skipUnless(sys.platform == "darwin", "helper reexec is local macOS only")
    def test_reexec_nested_ownership_normalizes_without_run(self):
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self._strict_env(
            IOS_SIMULATOR_ID="iPhone 17 Pro",
            DEV_IOS_PROFILE="daily",
            FAKE_IS_OWNER="1",
            IOS_AUTOMATION_LOCK_HELD="true",
        )
        proc = self._session_bash(
            'ios_session_reexec_if_needed /usr/bin/true'
            ' && printf "profile=%s id=%s" "$DEV_IOS_PROFILE" "$IOS_SIMULATOR_ID"',
            env,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout, f"profile=primary id={PRO_UDID}")
        self.assertEqual(self._log(self.helper_log).strip(), "is-owner")

    @unittest.skipUnless(sys.platform == "darwin", "helper reexec is local macOS only")
    def test_evaluator_daily_alias_through_strict_helper(self):
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self._strict_env(
            DEV_IOS_PROFILE="daily",
            IOS_SIMULATOR_ID="iPhone 17 Pro",
            FAKE_IS_OWNER="1",
        )
        proc = self._run([EVALUATOR, "tiny", "--no-build"], env)
        self.assertIn(
            f"run profile=primary udid={PRO_UDID} sim_udid={PRO_UDID}",
            self._log(self.helper_env_log),
        )
        self.assertNotIn("Unknown iOS session profile", proc.stderr)
        self.assertNotIn("Unexpected device mismatch", proc.stderr)
        # app.locate fails against the empty temp HOME — that is expected; the
        # contract under test is what reached the strict helper.
        self.assertEqual(proc.returncode, 2, proc.stderr + proc.stdout)
        reports = sorted(self.findings_dir.glob("*.md"))
        self.assertEqual(len(reports), 1, reports)
        self.assertIn(f"udid={PRO_UDID}", reports[0].read_text(encoding="utf-8"))

    # ------------------------------------------------------------------
    # DerivedData resolution (explicit path is authoritative)
    # ------------------------------------------------------------------
    def _write_global_decoy_app(self) -> Path:
        decoy = (
            self.home_dir
            / "Library/Developer/Xcode/DerivedData/Deco"
            / "Build/Products/Debug-iphonesimulator/SoloCompass.app"
        )
        decoy.mkdir(parents=True)
        return decoy

    def test_explicit_derived_data_never_falls_back_to_global(self):
        # A (stale) binary in the global DerivedData must not satisfy a run
        # that explicitly named a different DerivedData root.
        decoy = self._write_global_decoy_app()
        custom = self.tmp / "custom-dd"
        custom.mkdir()
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self.base_env(CI="true", IOS_DERIVED_DATA_PATH=str(custom))
        proc = self._run([EVALUATOR, "tiny", "--no-build"], env)
        self.assertEqual(proc.returncode, 2, proc.stderr + proc.stdout)
        report = sorted(self.findings_dir.glob("*.md"))[0].read_text(encoding="utf-8")
        self.assertIn("app.locate", report)
        self.assertIn("IOS_DERIVED_DATA_PATH", report)
        self.assertNotIn(str(decoy), report)
        self.assertNotIn("simctl install", self._log(self.xcrun_log))

    def test_explicit_derived_data_locates_app_inside_explicit_root(self):
        decoy = self._write_global_decoy_app()
        custom = self.tmp / "custom-dd"
        app = custom / "Build/Products/Debug-iphonesimulator/SoloCompass.app"
        app.mkdir(parents=True)
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self.base_env(CI="true", IOS_DERIVED_DATA_PATH=str(custom))
        proc = self._run([EVALUATOR, "tiny", "--no-build"], env)
        self.assertEqual(proc.returncode, 0, proc.stderr + proc.stdout)
        report = sorted(self.findings_dir.glob("*.md"))[0].read_text(encoding="utf-8")
        self.assertIn(f"**app.locate** — {app}", report)
        self.assertNotIn(str(decoy), report)
        self.assertIn("simctl install", self._log(self.xcrun_log))

    def test_evaluator_relative_derived_data_build_and_locate_agree(self):
        # Regression: xcodebuild resolved a relative -derivedDataPath against
        # apps/ios while the app lookup resolved it from the entry cwd, so a
        # build into a relative DerivedData could never be located. Build and
        # lookup must share one absolute path resolved against the caller's
        # working directory at entry.
        rel_name = f"rel-dd-{os.getpid()}"
        stray = REPO_ROOT / "apps" / "ios" / rel_name
        self.assertFalse(stray.exists(), f"unexpected pre-existing {stray}")
        workdir = self.tmp / "workdir"
        workdir.mkdir()
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self.base_env(CI="true", IOS_DERIVED_DATA_PATH=rel_name)
        proc = self._run([EVALUATOR, "tiny"], env, cwd=str(workdir))
        if stray.exists():
            shutil.rmtree(stray, ignore_errors=True)
            self.fail(
                "relative -derivedDataPath resolved against apps/ios instead of "
                "the entry cwd — build and lookup bases diverge"
            )
        self.assertEqual(proc.returncode, 0, proc.stderr + proc.stdout)
        # find(1) prints the resolved path on macOS (/var/folders -> /private).
        app = (
            Path(os.path.realpath(workdir))
            / rel_name
            / "Build/Products/Debug-iphonesimulator/SoloCompass.app"
        )
        self.assertTrue(app.is_dir(), app)
        report = sorted(self.findings_dir.glob("*.md"))[0].read_text(encoding="utf-8")
        self.assertIn(f"**app.locate** — {app}", report)
        self.assertIn("simctl install", self._log(self.xcrun_log))
        self.assertIn("-derivedDataPath", self._log(self.xcodebuild_log))

    # ------------------------------------------------------------------
    # boot/bootstatus failures are never hidden
    # ------------------------------------------------------------------
    def test_evaluator_boot_failure_fails_the_run(self):
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self.base_env(CI="true", FAKE_SIMCTL_BOOT_EXIT="1")
        proc = self._run([EVALUATOR, "tiny", "--no-build"], env)
        self.assertEqual(proc.returncode, 2, proc.stderr + proc.stdout)
        log = self._log(self.xcrun_log)
        self.assertIn("simctl boot", log)
        self.assertNotIn("simctl install", log)
        report = sorted(self.findings_dir.glob("*.md"))[0].read_text(encoding="utf-8")
        self.assertIn("simulator.boot", report)
        doc = json.loads(
            sorted(self.findings_dir.glob("*.json"))[0].read_text(encoding="utf-8")
        )
        self.assertEqual(doc["summary"]["result"], "FAIL")
        self.assertEqual(doc["summary"]["failure_reason"], "(setup)")

    def test_evaluator_bootstatus_failure_fails_the_run(self):
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self.base_env(CI="true", FAKE_SIMCTL_BOOTSTATUS_EXIT="1")
        proc = self._run([EVALUATOR, "tiny", "--no-build"], env)
        self.assertEqual(proc.returncode, 2, proc.stderr + proc.stdout)
        self.assertIn("not ready", proc.stderr)
        self.assertNotIn("simctl install", self._log(self.xcrun_log))
        report = sorted(self.findings_dir.glob("*.md"))[0].read_text(encoding="utf-8")
        self.assertIn("simulator.boot", report)

    def test_rubric_boot_failure_fails_before_app_use(self):
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self.base_env(CI="true", FAKE_SIMCTL_BOOT_EXIT="1")
        proc = self._run([RUBRIC], env)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("could not boot simulator", proc.stderr)
        log = self._log(self.xcrun_log)
        self.assertNotIn("simctl privacy", log)
        self.assertNotIn("simctl install", log)
        self.assertNotIn("simctl launch", log)

    def test_rubric_never_booted_device_fails_before_app_use(self):
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self.base_env(CI="true")
        proc = self._run([RUBRIC], env)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("never reached Booted", proc.stderr)
        log = self._log(self.xcrun_log)
        self.assertNotIn("simctl privacy", log)
        self.assertNotIn("simctl install", log)
        self.assertNotIn("simctl launch", log)

    # ------------------------------------------------------------------
    # shared session library helpers
    # ------------------------------------------------------------------
    def _session_bash(self, command, env):
        return subprocess.run(
            ["bash", "-c", f'source "{SESSION_LIB}" && {command}'],
            cwd=str(REPO_ROOT),
            env=env,
            capture_output=True,
            text=True,
        )

    def test_xcodebuild_destination_prefers_explicit_id(self):
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self.base_env(IOS_SIMULATOR_ID=PRO_UDID)
        proc = self._session_bash("ios_xcodebuild_destination 'iPhone 17 Pro'", env)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout.strip(), f"id={PRO_UDID}")
        self.assertIn("simctl list devices available --json", self._log(self.xcrun_log))

    def test_xcodebuild_destination_falls_back_to_selector(self):
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self.base_env()
        proc = self._session_bash("ios_xcodebuild_destination 'iPhone 17 Pro'", env)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout.strip(), f"id={PRO_UDID}")

    def test_xcodebuild_destination_validates_owner_udid(self):
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self.base_env(SIMULATOR_UDID=PRO_UDID)
        proc = self._session_bash("ios_xcodebuild_destination 'iPhone 17 Pro'", env)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout.strip(), f"id={PRO_UDID}")

    def test_xcodebuild_destination_rejects_stale_owner_udid(self):
        self._write_simctl([device("iPhone 17 Pro", PRO_UDID)])
        env = self.base_env(SIMULATOR_UDID=BOGUS_UDID)
        proc = self._session_bash("ios_xcodebuild_destination 'iPhone 17 Pro'", env)
        self.assertNotEqual(proc.returncode, 0)
        self.assertEqual(proc.stdout.strip(), "")

    # ------------------------------------------------------------------
    # two-device exception
    # ------------------------------------------------------------------
    def test_two_sim_requires_explicit_sim_b(self):
        env = self.base_env(DEV_IOS_REASON="unit test")
        proc, created = self._run_two_sim(env)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("SIM_B must be set explicitly", proc.stderr)
        self.assertEqual(self._log(self.xcrun_log), "")
        self.assertFalse(created)

    def test_two_sim_requires_reason_before_mutation(self):
        env = self.base_env(SIM_B="iPhone 16")
        proc, created = self._run_two_sim(env)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("DEV_IOS_REASON is required", proc.stderr)
        self.assertEqual(self._log(self.xcrun_log), "")
        self.assertFalse(created)

    def test_two_sim_missing_configured_allowlist_fails_closed(self):
        # Regression: a configured-but-missing allowlist used to warn and
        # silently skip membership validation.
        env = self._two_sim_env(DEV_IOS_ALLOWLIST=str(self.tmp / "missing-allowlist.tsv"))
        proc = self._run([TWO_SIM], env)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("simulator allowlist not found", proc.stderr)
        self.assertIn("missing-allowlist.tsv", proc.stderr)
        self.assertEqual(self._log(self.xcrun_log), "")
        self.assertFalse(self.lock_file.exists())

    def test_two_sim_missing_default_allowlist_fails_closed(self):
        env = self._two_sim_env()
        env.pop("DEV_IOS_ALLOWLIST", None)  # default path under the empty temp HOME
        proc = self._run([TWO_SIM], env)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("simulator allowlist not found", proc.stderr)
        self.assertEqual(self._log(self.xcrun_log), "")
        self.assertFalse(self.lock_file.exists())

    def test_two_sim_empty_allowlist_fails_closed(self):
        self.allowlist_file.write_text("# comments only\n", encoding="utf-8")
        env = self._two_sim_env()
        proc = self._run([TWO_SIM], env)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("allowlist is empty", proc.stderr)
        self.assertEqual(self._log(self.xcrun_log), "")
        self.assertFalse(self.lock_file.exists())

    def test_two_sim_refuses_inside_owned_session(self):
        self._write_simctl(
            [device("iPhone 17 Pro", PRO_UDID), device("iPhone 16", IP16_UDID)]
        )
        self._write_allowlist([PRO_UDID, IP16_UDID])
        env = self._two_sim_env(
            DEV_IOS_SESSION_BIN=str(self.helper),
            FAKE_IS_OWNER="1",
            IOS_AUTOMATION_LOCK_HELD="true",
        )
        proc = self._run([TWO_SIM], env)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("inside an owned dev-ios-session", proc.stderr)
        self.assertNotIn("simctl boot", self._log(self.xcrun_log))

    @requires_shlock
    def test_two_sim_fails_busy_when_the_shared_lock_is_held(self):
        self._write_simctl(
            [device("iPhone 17 Pro", PRO_UDID), device("iPhone 16", IP16_UDID)]
        )
        self._write_allowlist([PRO_UDID, IP16_UDID])
        # A live process (this test) already holds the shared shlock.
        subprocess.run(
            ["/usr/bin/shlock", "-f", str(self.lock_file), "-p", str(os.getpid())],
            check=True,
        )
        env = self._two_sim_env()
        proc = self._run([TWO_SIM], env)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("already holds", proc.stderr)
        log = self._log(self.xcrun_log)
        self.assertNotIn("simctl boot", log)
        self.assertNotIn("simctl shutdown", log)
        # The foreign lock is preserved, not stolen or removed.
        self.assertTrue(self.lock_file.exists())

    @requires_shlock
    def test_two_sim_rejects_foreign_active_device_without_touching_it(self):
        self._write_simctl(
            [
                device("iPhone 17 Pro", PRO_UDID),
                device("iPhone 16", IP16_UDID),
                device("iPad Pro 11-inch (M4)", IPAD_UDID, state="Booted"),
            ]
        )
        self._write_allowlist([PRO_UDID, IP16_UDID])
        env = self._two_sim_env()
        proc = self._run([TWO_SIM], env)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("other simulators are active", proc.stderr)
        log = self._log(self.xcrun_log)
        self.assertNotIn("simctl boot", log)
        self.assertNotIn("simctl shutdown", log)
        # Our own lock (never acquired here) is left clean.
        self.assertFalse(self.lock_file.exists())

    @requires_shlock
    def test_two_sim_cleanup_releases_own_lock_and_only_own_devices(self):
        self._write_simctl(
            [
                device("iPhone 17 Pro", PRO_UDID, state="Booted"),  # borrowed
                device("iPhone 16", IP16_UDID),  # started by this run
            ]
        )
        self._write_allowlist([PRO_UDID, IP16_UDID])
        env = self._two_sim_env()
        proc = self._run([TWO_SIM], env, stdin="\n")
        self.assertEqual(proc.returncode, 0, proc.stderr + proc.stdout)
        log = self._log(self.xcrun_log)
        self.assertIn(f"simctl boot {IP16_UDID}", log)
        self.assertNotIn(f"simctl boot {PRO_UDID}", log)
        self.assertIn(f"simctl shutdown {IP16_UDID}", log)
        self.assertNotIn(f"simctl shutdown {PRO_UDID}", log)
        self.assertFalse(self.lock_file.exists())

    @requires_shlock
    def test_two_sim_rejects_device_outside_allowlist(self):
        self._write_simctl(
            [device("iPhone 17 Pro", PRO_UDID), device("iPhone 16", IP16_UDID)]
        )
        self._write_allowlist([PRO_UDID])  # SIM_B is not allowlisted
        env = self._two_sim_env()
        proc = self._run([TWO_SIM], env)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("not in the allowlist", proc.stderr)
        log = self._log(self.xcrun_log)
        self.assertNotIn("simctl boot", log)
        self.assertNotIn("simctl shutdown", log)
        self.assertFalse(self.lock_file.exists())

    @requires_shlock
    def test_two_sim_bootstatus_failure_aborts_with_cleanup(self):
        self._write_simctl(
            [
                device("iPhone 17 Pro", PRO_UDID, state="Booted"),  # borrowed
                device("iPhone 16", IP16_UDID),  # started by this run
            ]
        )
        self._write_allowlist([PRO_UDID, IP16_UDID])
        env = self._two_sim_env(FAKE_SIMCTL_BOOTSTATUS_EXIT="1")
        proc = self._run([TWO_SIM], env, stdin="\n")
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("bootstatus", proc.stderr)
        log = self._log(self.xcrun_log)
        self.assertNotIn("simctl install", log)
        self.assertNotIn("simctl launch", log)
        # Cleanup still runs: own device down, borrowed device untouched,
        # lock released.
        self.assertIn(f"simctl shutdown {IP16_UDID}", log)
        self.assertNotIn(f"simctl shutdown {PRO_UDID}", log)
        self.assertFalse(self.lock_file.exists())

    def _run_two_sim(self, env):
        """Run the two-device harness and report whether it created artifacts."""
        base = REPO_ROOT / "artifacts" / "two-sim-friend-loop"
        before = set(base.iterdir()) if base.exists() else set()
        proc = self._run([TWO_SIM], env)
        after = set(base.iterdir()) if base.exists() else set()
        return proc, (after != before)


if __name__ == "__main__":
    unittest.main()
