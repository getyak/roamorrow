#!/usr/bin/env python3
"""Tests for the unified Solo Compass local-simulator policy.

These are real subprocess tests. Every simulator command is a fake binary on
``PATH`` (or a fixture file), so no test ever invokes ``xcrun``, boots a
simulator, or runs ``xcodebuild``.

Covered:
  * booted iPhone SE / iPad never override the declared primary iPhone
  * explicit IOS_SIMULATOR_ID is honored and validated (fail closed)
  * SIMULATOR_UDID is validated through the live inventory and must agree
  * frozen primary|compact|ipad profile API (plus daily alias) and family match
  * newest numbered iPhone / SE-last fallback
  * ipad profile requires an explicit ID in the portable fallback
  * helper reexec preserves entrypoint args and runs before simulator use
  * CI=true and CI=1 skip the helper and use the deterministic fallback
  * invalid journey never reaches the helper or the simulator
  * explicitly invalid DEV_IOS_SESSION_BIN fails closed
  * two-device harness requires SIM_B and DEV_IOS_REASON before any mutation
  * two-device harness takes the shared shlock, fails busy, and only cleans up
    its own lock and the devices it started
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
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SELECTOR = REPO_ROOT / "scripts" / "ios" / "select-simulator.py"
SESSION_LIB = REPO_ROOT / "scripts" / "ios" / "session.sh"
EVALUATOR = REPO_ROOT / "scripts" / "sc-evaluator" / "run.sh"
RUBRIC = REPO_ROOT / "scripts" / "user-story-rubric" / "run.sh"
EXECUTOR = REPO_ROOT / "scripts" / "sc-executor" / "run.sh"
TWO_SIM = REPO_ROOT / "scripts" / "qa" / "two-sim-friend-loop.sh"

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
if [[ "${1:-}" == "simctl" && "${2:-}" == "list" && "${3:-}" == "devices" \\
      && "${4:-}" == "available" ]]; then
  case "${5:-}" in
    --json|-j)
      if [[ -n "${FAKE_SIMCTL_JSON:-}" && -f "${FAKE_SIMCTL_JSON}" ]]; then
        cat "${FAKE_SIMCTL_JSON}"
      fi
      exit 0
      ;;
  esac
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
        self.simctl_json_file = self.tmp / "simctl.json"
        self.allowlist_file = self.tmp / "simulator-allowlist.tsv"
        self.lock_file = self.tmp / "ios-automation.xcodebuild.lock"

        self._write_exec(self.bin_dir / "xcrun", FAKE_XCRUN)
        self._write_exec(self.bin_dir / "open", FAKE_OPEN)
        self._write_exec(self.bin_dir / "sleep", FAKE_SLEEP)
        self.helper = self.bin_dir / "dev-ios-session"
        self._write_exec(self.helper, FAKE_HELPER)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    @staticmethod
    def _write_exec(path: Path, body: str):
        path.write_text(body, encoding="utf-8")
        path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    def base_env(self, **overrides):
        env = os.environ.copy()
        env["PATH"] = f"{self.bin_dir}{os.pathsep}" + env.get("PATH", "")
        env["REPO_ROOT"] = str(REPO_ROOT)
        env["HOME"] = str(self.home_dir)
        env["FAKE_XCRUN_LOG"] = str(self.xcrun_log)
        env["FAKE_OPEN_LOG"] = str(self.open_log)
        env["FAKE_HELPER_LOG"] = str(self.helper_log)
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
            "DEV_IOS_REASON",
            "DEV_IOS_ALLOWLIST",
            "IOS_AUTOMATION_LOCK_FILE",
            "IOS_AUTOMATION_LOCK_HELD",
            "SIM_B",
            "SIM_A",
            "FLAG",
            "ARTIFACTS",
        ):
            env.pop(key, None)
        env.update(overrides)
        return env

    def _run(self, args, env, stdin=""):
        return subprocess.run(
            [str(a) for a in args],
            cwd=str(REPO_ROOT),
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

    def test_two_sim_fails_busy_when_the_shared_lock_is_held(self):
        self._write_simctl(
            [device("iPhone 17 Pro", PRO_UDID), device("iPhone 16", IP16_UDID)]
        )
        self._write_allowlist([PRO_UDID, IP16_UDID])
        # A live process (this test) already holds the shared shlock.
        subprocess.run(
            ["shlock", "-f", str(self.lock_file), "-p", str(os.getpid())], check=True
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

    def _run_two_sim(self, env):
        """Run the two-device harness and report whether it created artifacts."""
        base = REPO_ROOT / "artifacts" / "two-sim-friend-loop"
        before = set(base.iterdir()) if base.exists() else set()
        proc = self._run([TWO_SIM], env)
        after = set(base.iterdir()) if base.exists() else set()
        return proc, (after != before)


if __name__ == "__main__":
    unittest.main()
