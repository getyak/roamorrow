#!/usr/bin/env python3
"""Deterministic iOS simulator selection for Solo Compass local runs.

This is the portable fallback used when the shared ``dev-ios-session`` helper
owns the device or when no helper is installed (CI, non-macOS). It replaces the
old "any booted simulator wins" logic, which let an already-booted iPhone SE or
iPad silently override the declared primary iPhone preference.

Frozen profile API (matches ``dev-ios-session``):
  ``primary`` (default), ``compact`` -> iPhone; ``ipad`` -> iPad.
  ``daily`` is accepted as a compatibility alias for ``primary``.

Policy (see ``docs/development/ios-testing.md``):

* An explicit ``IOS_SIMULATOR_ID`` and/or ``SIMULATOR_UDID`` (UDID or exact
  device name) is honored and validated. When either does not match an
  available iOS device of the profile's family, the selector fails closed --
  it never substitutes another device. When both are present they must agree.
* Names are canonicalized to UDIDs; the caller always receives a UDID.
* Auxiliary profiles (``compact`` and ``ipad``) require an explicit ID in
  this portable fallback. iPads are only selected for ``ipad``; watchOS/tvOS
  devices are rejected.
* Auto-selection only considers available iPhones **on iOS runtimes**: the
  preferred name (default ``iPhone 17 Pro``) when present, else the newest
  numbered iPhone, else any other iPhone, with iPhone SE strictly last.
  Boot state is irrelevant.

Input is the JSON produced by ``xcrun simctl list devices available --json``
(read from stdin by default). Output is a single JSON object on stdout.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

DEFAULT_PREFERRED = "iPhone 17 Pro"
DEFAULT_PROFILE = "primary"
PROFILES = ("primary", "compact", "ipad")
PROFILE_ALIASES = {"daily": "primary"}
FAMILY_BY_PROFILE = {"primary": "iphone", "compact": "iphone", "ipad": "ipad"}

_NUMBER_RE = re.compile(r"iPhone\s+(\d{1,3})", re.IGNORECASE)
_SE_RE = re.compile(r"(?<![A-Za-z])SE(?![A-Za-z])")


def _fail(message: str, code: int = 2) -> "None":
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(code)


def normalize_profile(value: str | None) -> str:
    if value is None or not value.strip():
        return DEFAULT_PROFILE
    key = PROFILE_ALIASES.get(value.strip().lower(), value.strip().lower())
    if key not in PROFILES:
        _fail(f"unknown profile '{value}' (expected one of {', '.join(PROFILES)})")
    return key


def runtime_to_ios(runtime: str) -> str:
    """Map ``...SimRuntime.iOS-26-4`` to ``26.4`` (empty when unknown)."""
    tail = runtime.rsplit(".", 1)[-1]
    if tail.lower().startswith("ios-"):
        return tail[4:].replace("-", ".")
    return ""


def ios_version_key(version: str) -> tuple:
    parts: list[int] = []
    for piece in (version or "").split("."):
        parts.append(int(piece) if piece.isdigit() else 0)
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts[:3])


def flatten(data: dict) -> list[dict]:
    devices: list[dict] = []
    for runtime, entries in (data.get("devices") or {}).items():
        for entry in entries or []:
            device = dict(entry)
            device["runtime"] = runtime
            device["ios_version"] = runtime_to_ios(runtime)
            devices.append(device)
    return devices


def device_family(name: str) -> str | None:
    stripped = name.strip()
    if stripped.startswith("iPad"):
        return "ipad"
    if stripped.startswith("iPhone"):
        return "iphone"
    return None


def is_se(name: str) -> bool:
    return bool(_SE_RE.search(name))


def iphone_number(name: str) -> int | None:
    match = _NUMBER_RE.search(name)
    return int(match.group(1)) if match else None


def variant_rank(name: str) -> int:
    lowered = name.lower()
    if "pro max" in lowered:
        return 4
    if "pro" in lowered:
        return 3
    if "plus" in lowered or "air" in lowered:
        return 2
    if "mini" in lowered:
        return 0
    return 1


def auto_key(device: dict, preferred: str) -> tuple:
    """Higher sorts better. Only iPhones are considered by the caller."""
    name = device["name"]
    number = iphone_number(name)
    if name == preferred:
        tier = 4
    elif is_se(name):
        tier = 1
    elif number is not None:
        tier = 3
    else:
        tier = 2
    return (
        tier,
        number if number is not None else 0,
        variant_rank(name),
        ios_version_key(device.get("ios_version", "")),
    )


def match_explicit(devices: list[dict], ident: str) -> dict | None:
    lowered = ident.strip().lower()
    for device in devices:
        if str(device.get("udid", "")).lower() == lowered:
            return device
    named = [d for d in devices if str(d.get("name", "")).lower() == lowered]
    named.sort(key=lambda d: ios_version_key(d.get("ios_version", "")), reverse=True)
    return named[0] if named else None


def emit(device: dict, source: str) -> None:
    print(
        json.dumps(
            {
                "name": device.get("name", ""),
                "udid": device.get("udid", ""),
                "family": device_family(str(device.get("name", ""))) or "",
                "ios_version": device.get("ios_version", ""),
                "runtime": device.get("runtime", ""),
                "state": device.get("state", ""),
                "source": source,
            },
            sort_keys=True,
        )
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--json-file",
        default="-",
        help="Path to simctl JSON, or '-' to read stdin (default).",
    )
    parser.add_argument("--preferred", default=DEFAULT_PREFERRED)
    parser.add_argument(
        "--explicit",
        default=None,
        help="IOS_SIMULATOR_ID: UDID or exact device name.",
    )
    parser.add_argument(
        "--owner-udid",
        default=None,
        help="SIMULATOR_UDID exported by an owned dev-ios-session.",
    )
    parser.add_argument(
        "--resolve",
        default=None,
        metavar="IDENT",
        help=(
            "Canonicalize IDENT (UDID or exact device name) to its UDID and "
            "exit. Used by the helper reexec path so dev-ios-session only ever "
            "sees UDIDs."
        ),
    )
    parser.add_argument("--profile", default=None)
    args = parser.parse_args(argv)

    profile = normalize_profile(args.profile)
    expected_family = FAMILY_BY_PROFILE[profile]

    if args.json_file == "-":
        raw = sys.stdin.read()
    else:
        try:
            raw = Path(args.json_file).read_text(encoding="utf-8")
        except OSError as exc:
            _fail(f"could not read simulator JSON: {exc}")

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        _fail(f"could not parse simulator JSON: {exc}")

    devices = [d for d in flatten(data) if d.get("isAvailable", True)]
    if not devices:
        _fail("no available simulators reported by simctl")

    if args.resolve is not None:
        # Canonicalization mode for the helper reexec path: one ident -> one
        # UDID. No profile policy here; the host helper keeps allowlist,
        # family, and availability validation.
        device = match_explicit(devices, args.resolve)
        if device is None:
            _fail(
                f"'{args.resolve}' (IOS_SIMULATOR_ID/SIMULATOR_UDID) does not match "
                "any available simulator; refusing to substitute another device"
            )
        if not device.get("ios_version"):
            _fail(f"'{device.get('name')}' is not available on an iOS runtime")
        print(str(device.get("udid", "")))
        return 0

    idents = [x.strip() for x in (args.explicit, args.owner_udid) if x and x.strip()]
    resolved: list[dict] = []
    for ident in idents:
        device = match_explicit(devices, ident)
        if device is None:
            _fail(
                f"'{ident}' (IOS_SIMULATOR_ID/SIMULATOR_UDID) does not match any "
                "available simulator; refusing to substitute another device"
            )
        family = device_family(str(device.get("name", "")))
        if family != expected_family:
            _fail(
                f"profile '{profile}' expects a {expected_family} device but "
                f"{device.get('name')!r} is {family or 'unsupported (watchOS/tvOS/other)'}"
            )
        if not device.get("ios_version"):
            _fail(f"'{device.get('name')}' is not available on an iOS runtime")
        resolved.append(device)

    if resolved:
        udids = {d["udid"] for d in resolved}
        if len(udids) > 1:
            _fail(
                "IOS_SIMULATOR_ID and SIMULATOR_UDID disagree; refusing to "
                "substitute a device"
            )
        emit(resolved[0], "explicit")
        return 0

    if profile in ("compact", "ipad"):
        _fail(f"profile '{profile}' requires an explicit IOS_SIMULATOR_ID")

    # iOS runtimes only: an iPhone-named entry under a non-iOS runtime must
    # never be auto-selected (same rule the explicit path enforces).
    iphones = [
        d
        for d in devices
        if device_family(str(d.get("name", ""))) == "iphone" and d.get("ios_version")
    ]
    if not iphones:
        _fail(
            "no available iPhone simulator on an iOS runtime; "
            "SE/iPad/watch/TV and non-iOS runtimes are not auto-selected"
        )

    best = max(iphones, key=lambda d: auto_key(d, args.preferred))
    emit(best, "auto")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
