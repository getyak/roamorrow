import importlib.util
import json
import os
from pathlib import Path
import plistlib
import tempfile
import time
import unittest
from unittest.mock import patch
import uuid

MODULE_PATH = Path(__file__).with_name("seed-chat-performance-fixture.py")
SPEC = importlib.util.spec_from_file_location("chat_fixture", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ChatFixtureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="get338-fixture-tests-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.container = self.root / "CoreSimulator/Devices" / str(uuid.uuid4()) / "data/Containers/Data/Application" / str(uuid.uuid4())
        self.container.mkdir(parents=True)
        (self.container / ".com.apple.mobile_container_manager.metadata.plist").write_bytes(
            plistlib.dumps({"MCMMetadataIdentifier": "com.solocompass.app"}))
        self.snapshot = self.container / "Library/Application Support/Roamorrow/CompanionHome/v1.json"
        self.snapshot.parent.mkdir(parents=True)
        self.original = json.dumps({"version": 1, "conversationID": MODULE.OLD_MARKER, "entries": []}).encode()
        self.snapshot.write_bytes(self.original)
        self.preferences = self.container / "Library/Preferences/com.solocompass.app.plist"
        self.preferences.parent.mkdir(parents=True)
        self.preferences.write_bytes(plistlib.dumps({"com.solocompass.userPreferences.v1": json.dumps({"aiApiKey": ""}).encode()}))
        self.receipt = self.root / "evidence/fixture.json"
        self.env = patch.dict(os.environ, {"GITHUB_ACTIONS": "true", "RUNNER_TEMP": str(self.root)})
        self.env.start()
        self.addCleanup(self.env.stop)

    def testRefusesLocalMachineBeforeWriting(self):
        with patch.dict(os.environ, {"GITHUB_ACTIONS": "false"}):
            with self.assertRaises(ValueError):
                MODULE.seed(self.container, self.receipt)
        self.assertEqual(self.snapshot.read_bytes(), self.original)

    def testRefusesUnmarkedHistory(self):
        data = b'{"version":1,"conversationID":"real-history","entries":[{"text":"retain"}]}'
        self.snapshot.write_bytes(data)
        with self.assertRaises(ValueError):
            MODULE.seed(self.container, self.receipt)
        self.assertEqual(self.snapshot.read_bytes(), data)

    def testRefusesCredentialedPreferences(self):
        self.preferences.write_bytes(plistlib.dumps({"com.solocompass.userPreferences.v1": b'{"aiApiKey":"not-a-real-key"}'}))
        with self.assertRaises(ValueError):
            MODULE.seed(self.container, self.receipt)
        self.assertEqual(self.snapshot.read_bytes(), self.original)

    def testRedirectedTemporaryPathCannotPartiallyReplaceHistory(self):
        sibling = self.root / "untouched.txt"
        sibling.write_bytes(b"retain")
        temporary = self.snapshot.with_name(self.snapshot.name + ".draft.json.get-338.tmp")
        temporary.symlink_to(sibling)
        with self.assertRaises(ValueError):
            MODULE.seed(self.container, self.receipt)
        self.assertEqual(self.snapshot.read_bytes(), self.original)
        self.assertEqual(sibling.read_bytes(), b"retain")

    def testRejectsWrongAppContainer(self):
        (self.container / ".com.apple.mobile_container_manager.metadata.plist").write_bytes(
            plistlib.dumps({"MCMMetadataIdentifier": "another.app"}))
        with self.assertRaises(ValueError):
            MODULE.seed(self.container, self.receipt)
        self.assertEqual(self.snapshot.read_bytes(), self.original)

    def testSeedsBoundedRealIDsAndFiveThousandSyntheticMessages(self):
        MODULE.seed(self.container, self.receipt, populated=True)
        snapshot = json.loads(self.snapshot.read_bytes())
        self.assertEqual(len(snapshot["entries"]), 5000)
        self.assertEqual(len({item["id"] for item in snapshot["entries"]}), 5000)
        self.assertLess(max(item["createdAt"] for item in snapshot["entries"]) + 978307200, time.time())
        self.assertEqual(snapshot["conversationID"], MODULE.MARKER)
        self.assertTrue(snapshot["readingState"]["followsLatest"])
        profile = plistlib.loads(self.preferences.read_bytes())
        settings = json.loads(profile["com.solocompass.userPreferences.v1"])
        self.assertEqual(settings["displayHandle"], MODULE.LONG_NAME)
        self.assertEqual(len(settings["favoritedExperiences"]), 2)
        self.assertEqual(len(settings["completedExperiences"]), 1)
        self.assertEqual(json.loads(self.receipt.read_bytes())["messages"], 5000)


if __name__ == "__main__":
    unittest.main()
