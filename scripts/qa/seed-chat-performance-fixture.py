#!/usr/bin/env python3
"""Seed owned CI Simulator fixtures only, with no production app test hook."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import time
import uuid

MARKER = "get-338-ci-chat-fixture"
OLD_MARKER = "v4-ci-public-ui-fixture-v1"
LONG_NAME = "一个带着很长昵称慢慢旅行的人 · 界面演示"


def seed(container: Path, receipt: Path, populated: bool = False) -> None:
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise ValueError("Fixture writes require an owned GitHub Actions runner")
    runner = Path(os.environ["RUNNER_TEMP"]).resolve(strict=True)
    container = container.resolve(strict=True)
    receipt = receipt.resolve()
    if not receipt.is_relative_to(runner):
        raise ValueError("Evidence must stay in runner temporary storage")
    match = re.search(r"/CoreSimulator/Devices/([\dA-Fa-f-]{36})/data/Containers/Data/Application/([\dA-Fa-f-]{36})$", str(container))
    if not match or container.stat().st_uid != os.getuid():
        raise ValueError("Expected an owned Simulator application container")
    for value in match.groups():
        uuid.UUID(value)
    with (container / ".com.apple.mobile_container_manager.metadata.plist").open("rb") as stream:
        if plistlib.load(stream).get("MCMMetadataIdentifier") != "com.solocompass.app":
            raise ValueError("Wrong application container")
    target = container / "Library/Application Support/Roamorrow/CompanionHome/v1.json"
    preferences = container / "Library/Preferences/com.solocompass.app.plist"
    for candidate in (target, preferences):
        for parent in (candidate, *candidate.parents):
            if parent == container:
                break
            if parent.is_symlink():
                raise ValueError("Refusing redirected fixture paths")
    old_bytes = target.read_bytes()
    old = json.loads(old_bytes)
    if old.get("version") != 1 or old.get("conversationID") not in (OLD_MARKER, MARKER):
        raise ValueError("Refusing to replace non-fixture history")
    draft_target = target.with_name(target.name + ".draft.json")
    if draft_target.is_symlink():
        raise ValueError("Refusing a redirected draft")
    if draft_target.exists():
        draft = json.loads(draft_target.read_bytes())
        if draft.get("version") != 1 or draft.get("conversationID") not in (OLD_MARKER, MARKER):
            raise ValueError("Refusing to replace a non-fixture draft")

    profile_bytes = preferences.read_bytes()
    profile = plistlib.loads(profile_bytes)
    storage_key = "com.solocompass.userPreferences.v1"
    raw = profile.get(storage_key)
    if not isinstance(raw, bytes):
        raise ValueError("Expected the app's existing preference snapshot")
    settings = json.loads(raw)
    if settings.get("aiApiKey"):
        raise ValueError("Refusing credentialed preferences")
    catalogue_file = Path(__file__).resolve().parents[2] / "apps/ios/SoloCompass/Resources/JSON/seed_experiences.json"
    catalogue = json.loads(catalogue_file.read_bytes())
    ids = [item["id"] for item in catalogue[:2]]
    if len(ids) < 2:
        raise ValueError("Expected real bundled experiences")
    settings["displayHandle"] = LONG_NAME if populated else ""
    settings["favoritedExperiences"] = ids if populated else []
    settings["completedExperiences"] = ids[:1] if populated else []
    settings["favoritedAt"] = {}
    profile[storage_key] = json.dumps(settings, ensure_ascii=False).encode()

    entries = []
    base = int(uuid.UUID("61000000-0000-0000-0000-000000000001"))
    # Swift Date Codable uses seconds since 2001, not Unix seconds. Keep the
    # whole history in the past so a new send really is the chronological tail.
    first_time = int(time.time()) - 978307200 - 5000 * 30 - 600
    for index in range(5_000):
        text = f"[性能验收 {index + 1}] " + ("一段合成的旅行对话，用于检查滚动与输入，不代表真实行程。" * (35 if index % 31 == 0 else 1))
        entry = {"id": str(uuid.UUID(int=base + index)).upper(),
                 "role": "user" if index % 2 == 0 else "companion", "status": "delivered",
                 "createdAt": first_time + index * 30, "text": text,
                 "sourceTitles": ["CI synthetic scroll fixture"]}
        if index % 2:
            entry["replyToID"] = str(uuid.UUID(int=base + index - 1)).upper()
        if index % 97 == 0:
            entry["attachments"] = [{"id": str(uuid.UUID(int=base + 10000 + index)).upper(),
                "kind": "file", "name": "CI note.txt", "mimeType": "text/plain", "data": "ZGVtbw=="}]
        entries.append(entry)
    session = "62000000-0000-0000-0000-000000000001"
    snapshot = {"version": 1, "entries": entries, "composerDraft": "", "people": [],
                "selectedPeopleIDs": [], "invites": [], "conversationID": MARKER, "agentSessionID": session,
                "draftRevision": 0,
                "readingState": {"anchorID": "stream-bottom", "followsLatest": True, "hasUnread": False}}
    data = json.dumps(snapshot, ensure_ascii=False).encode()
    sidecar = json.dumps({"version": 1, "conversationID": MARKER, "agentSessionID": session,
                          "revision": 0, "text": ""}).encode()
    replacements = ((target, data), (draft_target, sidecar), (preferences, plistlib.dumps(profile)))
    for path, _ in replacements:
        temp = path.with_name(path.name + ".get-338.tmp")
        if temp.is_symlink():
            raise ValueError("Refusing a redirected temporary path")
    receipt.parent.mkdir(parents=True, exist_ok=True)
    (receipt.parent / "prior-fixture-snapshot.json").write_bytes(old_bytes)
    # Preferences are backed up only after credential rejection, inside this CI fixture scope.
    (receipt.parent / "prior-fixture-preferences.plist").write_bytes(profile_bytes)
    for path, content in replacements:
        temp = path.with_name(path.name + ".get-338.tmp")
        temp.write_bytes(content)
    for path, _ in replacements:
        temp = path.with_name(path.name + ".get-338.tmp")
        temp.replace(path)
    receipt.write_text(json.dumps({"scope": "CI Simulator only; synthetic local data; no live-model acceptance",
        "messages": 5000, "conversation_id": MARKER, "last_message_id": entries[-1]["id"],
        "snapshot_bytes": len(data), "snapshot_sha256": hashlib.sha256(data).hexdigest(),
        "profile": "long-name/populated" if populated else "default/empty",
        "saved_count": len(settings["favoritedExperiences"]), "explored_count": len(settings["completedExperiences"]),
        "checkout_sha": os.environ.get("GITHUB_SHA"), "pr_head_sha": os.environ.get("CHAT_PR_HEAD_SHA")}, indent=2) + "\n")
    print("Prepared 5000-message CI fixture and owned local profile")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--container", type=Path, required=True)
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--populated", action="store_true")
    args = parser.parse_args()
    try:
        seed(args.container, args.receipt, args.populated)
    except (ValueError, KeyError, OSError) as error:
        parser.exit(1, f"Fixture refused: {error}\n")
