import importlib.util
from pathlib import Path
import signal
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, call, patch

path = Path(__file__).with_name("capture-chat-hang.py")
spec = importlib.util.spec_from_file_location("chat_hang", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ChatHangCaptureTests(unittest.TestCase):
    def test_selects_only_the_running_app_not_its_widget(self):
        listing = "22 0 UIKitApplication:com.solocompass.app.widgets[abc]\n31 0 UIKitApplication:com.solocompass.app[def]\n"
        self.assertEqual(module.app_pid(listing), 31)

    def test_ignores_stopped_and_unrelated_processes(self):
        self.assertIsNone(module.app_pid("- 0 UIKitApplication:com.solocompass.app[abc]\n12 0 other\n"))

    def test_requires_an_actual_idle_timeout_signal(self):
        self.assertFalse(module.idle_timeout("Wait for com.solocompass.app to idle"))
        self.assertTrue(module.idle_timeout("App event loop idle notification not received, will attempt to continue."))

    def test_rejects_local_execution_before_touching_files_or_processes(self):
        with patch.dict(module.os.environ, {"GITHUB_ACTIONS": "false"}):
            with self.assertRaises(ValueError):
                module.watch("not-a-device", Path("missing"), Path("missing"))

    def run_watcher(self, command, sample, terminate=False):
        device = "02B4F0C1-A92F-469D-9DCC-5ED13F119507"
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            log = root / "test.log"
            log.write_text("App event loop idle notification not received")
            handlers = {}
            if terminate:
                def wait(**kwargs):
                    if kwargs.get("timeout") == 15:
                        handlers[signal.SIGTERM]()
                    return 0

                sample.wait.side_effect = wait
            with patch.dict(module.os.environ, {"GITHUB_ACTIONS": "true", "RUNNER_TEMP": str(root),
                                               "GITHUB_WORKSPACE": str(root)}), \
                    patch.object(module.signal, "signal", side_effect=lambda signum, fn: handlers.update({signum: fn})), \
                    patch.object(module.subprocess, "run", side_effect=[
                        Mock(stdout="31 0 UIKitApplication:com.solocompass.app[abc]"), Mock(stdout=command)]), \
                    patch.object(module.subprocess, "Popen", return_value=sample) as popen, \
                    patch.object(module.os, "killpg") as killpg, \
                    patch.object(module.time, "sleep", side_effect=SystemExit), \
                    patch.object(module.time, "monotonic", side_effect=[0, 1]):
                try:
                    module.watch(device, log, root / "diagnostics")
                except (SystemExit, ValueError) as error:
                    return popen, killpg, error
        self.fail("Watcher did not exit")

    def test_rejects_wrong_device_or_executable_before_sampling(self):
        for command in [
            "/CoreSimulator/Devices/other/data/SoloCompass.app/SoloCompass",
            "/CoreSimulator/Devices/02B4F0C1-A92F-469D-9DCC-5ED13F119507/data/Other.app/Other",
        ]:
            with self.subTest(command=command):
                popen, killpg, error = self.run_watcher(command, Mock())
                self.assertIsInstance(error, ValueError)
                popen.assert_not_called()
                killpg.assert_not_called()

    def test_sample_timeout_kills_and_reaps_only_owned_group(self):
        sample = Mock(pid=81)
        sample.wait.side_effect = [subprocess.TimeoutExpired("sample", 15), 0]
        popen, killpg, error = self.run_watcher(
            "/CoreSimulator/Devices/02B4F0C1-A92F-469D-9DCC-5ED13F119507/data/SoloCompass.app/SoloCompass", sample)
        self.assertIsInstance(error, SystemExit)
        self.assertTrue(popen.call_args.kwargs["start_new_session"])
        killpg.assert_called_once_with(81, signal.SIGKILL)
        self.assertEqual(sample.wait.call_args_list, [call(timeout=15), call()])

    def test_parent_termination_stops_and_reaps_owned_sample(self):
        sample = Mock(pid=81)
        sample.poll.return_value = None
        _, killpg, error = self.run_watcher(
            "/CoreSimulator/Devices/02B4F0C1-A92F-469D-9DCC-5ED13F119507/data/SoloCompass.app/SoloCompass",
            sample, terminate=True)
        self.assertIsInstance(error, SystemExit)
        killpg.assert_called_once_with(81, signal.SIGTERM)
        self.assertEqual(sample.wait.call_args_list, [call(timeout=15), call(timeout=3)])


if __name__ == "__main__":
    unittest.main()
