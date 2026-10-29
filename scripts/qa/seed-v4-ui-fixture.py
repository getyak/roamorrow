#!/usr/bin/env python3
"""Seed public UI history only in this CI runner's installed Simulator app."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import uuid

MARKER = "v4-ci-public-ui-fixture-v1"
DRAFT = "V4 fixture draft"
SOURCE_ID = "40000000-0000-0000-0000-000000000005"
PLACE_ID = "exp_cmi_bookstore_work"


def seed(container: Path, receipt: Path) -> None:
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise ValueError("Refusing fixture writes outside GitHub Actions")
    runner_temp = Path(os.environ["RUNNER_TEMP"]).resolve(strict=True)
    container = container.resolve(strict=True)
    receipt = receipt.resolve()
    if not receipt.is_relative_to(runner_temp):
        raise ValueError("Receipt and backup must stay in this runner's temporary directory")
    pattern = r"/CoreSimulator/Devices/([0-9A-Fa-f-]{36})/data/Containers/Data/Application/([0-9A-Fa-f-]{36})$"
    match = re.search(pattern, str(container))
    if not match or container.stat().st_uid != os.getuid():
        raise ValueError("Expected an owned Simulator application data container")
    for value in match.groups():
        uuid.UUID(value)
    metadata = container / ".com.apple.mobile_container_manager.metadata.plist"
    with metadata.open("rb") as stream:
        if plistlib.load(stream).get("MCMMetadataIdentifier") != "com.solocompass.app":
            raise ValueError("Container does not belong to the expected app")
    target = container / "Library/Application Support/Roamorrow/CompanionHome/v1.json"
    for parent in [target, *target.parents]:
        if parent == container:
            break
        if parent.is_symlink():
            raise ValueError("Refusing a redirected snapshot path")
    catalogue_path = Path(__file__).resolve().parents[2] / "apps/ios/SoloCompass/Resources/JSON/seed_experiences.json"
    catalogue = json.loads(catalogue_path.read_text())
    if PLACE_ID not in {item["id"] for item in catalogue}:
        raise ValueError("Fixture place must be a real bundled Experience ID")
    original = target.read_bytes() if target.exists() else None
    if original is not None:
        old = json.loads(original)
        empty_fields = ["entries", "composerDraft", "people", "selectedPeopleIDs", "invites", "commitments",
                        "toolJournals", "draftAttachments", "draftQuote", "nextTurnPlace", "nextTurnArea", "mapSource"]
        if old.get("version") != 1 or any(old.get(key) for key in empty_fields):
            raise ValueError("Refusing to replace a nonempty conversation snapshot")
        receipt.parent.mkdir(parents=True, exist_ok=True)
        (receipt.parent / "pre-fixture-empty-snapshot.json").write_bytes(original)
    entries = []
    for index in range(16):
        source = index == 4
        entries.append({
            "id": str(uuid.UUID(int=int(uuid.UUID("40000000-0000-0000-0000-000000000001")) + index)).upper(),
            "role": "companion" if index % 2 == 0 else "user",
            "status": "delivered",
            "createdAt": 815000000 + index * 300,
            "text": ("[UI fixture] 这家书店来自 App 公开种子资料。可以在地图查看，营业时间和安静程度仍需核实。"
                     if source else f"[UI fixture {index + 1:02d}] 保留这条旅行笔记。切换地图后，仍回到正在阅读的这一处。\n这是一段明确标记的本地界面验收资料，不是模型搜索回复。"),
            "sourceTitles": ["CI UI fixture — public bundled data"],
            "placeIDs": [PLACE_ID] if source else [],
        })
    assert entries[4]["id"] == SOURCE_ID
    snapshot = {"version": 1, "entries": entries, "composerDraft": DRAFT, "people": [],
                "selectedPeopleIDs": [], "invites": [], "conversationID": MARKER,
                "readingState": {"anchorID": "message:" + SOURCE_ID, "followsLatest": False, "hasUnread": False}}
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(".fixture.tmp")
    data = (json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n").encode()
    temporary.write_bytes(data)
    temporary.replace(target)
    receipt.parent.mkdir(parents=True, exist_ok=True)
    receipt.write_text(json.dumps({"scope": "CI-only local UI fixture; no model or provider calls",
        "conversation_id": MARKER, "source_id": SOURCE_ID, "public_place_id": PLACE_ID,
        "snapshot_sha256": hashlib.sha256(data).hexdigest(), "prior_empty_snapshot_backed_up": original is not None,
        "catalogue_sha256": hashlib.sha256(catalogue_path.read_bytes()).hexdigest()}, indent=2) + "\n")
    print("Seeded explicitly marked public-place UI history in the CI app container")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--container", type=Path, required=True)
    parser.add_argument("--receipt", type=Path, required=True)
    arguments = parser.parse_args()
    try:
        seed(arguments.container, arguments.receipt)
    except (ValueError, KeyError, OSError) as error:
        parser.exit(1, f"Fixture refused: {error}\n")
