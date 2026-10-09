"""Launcher contracts; no desktop locking or password authentication."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location("launch", Path(__file__).with_name("launch.py"))
launch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launch)


class LauncherTests(unittest.TestCase):
    def test_check_refuses_compositor_without_lock_protocol(self):
        result = subprocess.CompletedProcess([], 0, "SHOJI_LOCK_CHECK_OK", "")
        with patch.object(launch.subprocess, "run", return_value=result):
            with self.assertRaisesRegex(RuntimeError, "протокол"):
                launch.check({})

    def test_check_refuses_failed_qml_even_if_protocol_present(self):
        result = subprocess.CompletedProcess([], 255, "", "ext_session_lock_manager_v1")
        with patch.object(launch.subprocess, "run", return_value=result):
            with self.assertRaisesRegex(RuntimeError, "компоненты"):
                launch.check({})

    def test_existing_secure_lock_is_not_restarted(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(launch, "status", return_value={"secure": True}), \
                    patch.object(launch.subprocess, "Popen") as spawn:
                launch.start({}, Path(directory))
                spawn.assert_not_called()

    def test_launcher_waits_for_secure_ack_and_detaches(self):
        process = Mock()
        process.poll.return_value = None
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(launch, "status", side_effect=[None, {"secure": False}, {"secure": True}]), \
                    patch.object(launch, "check"), \
                    patch.object(launch.subprocess, "Popen", return_value=process) as spawn, \
                    patch.object(launch.time, "sleep"):
                launch.start({}, Path(directory))
                self.assertTrue(spawn.call_args.kwargs["start_new_session"])
                self.assertTrue(spawn.call_args.kwargs["close_fds"])
                process.terminate.assert_not_called()
                process.kill.assert_not_called()

    def test_early_locker_exit_is_reported_as_failure(self):
        process = Mock()
        process.poll.return_value = 255
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(launch, "status", return_value=None), \
                    patch.object(launch, "check"), \
                    patch.object(launch.subprocess, "Popen", return_value=process):
                with self.assertRaisesRegex(RuntimeError, "завершился"):
                    launch.start({}, Path(directory))

    def test_missing_pam_does_not_fall_back_to_login(self):
        with tempfile.TemporaryDirectory() as directory:
            policy = Path(directory) / "policy"
            policy.mkdir()
            (policy / "login").write_text("auth sufficient pam_permit.so\n")
            with patch.object(launch, "PAM_DIRECTORY", policy):
                with self.assertRaisesRegex(RuntimeError, "PAM"):
                    launch.pam_configuration(Path(directory))

    def test_arch_fallback_preserves_transitive_system_includes(self):
        with tempfile.TemporaryDirectory() as directory:
            policy = Path(directory) / "policy"
            policy.mkdir()
            for name in ("system-auth", "system-local-login", "system-login"):
                (policy / name).write_text("# installed policy\n")
            with patch.object(launch, "PAM_DIRECTORY", policy):
                pam_dir, service = launch.pam_configuration(Path(directory))
                self.assertEqual(service, "shoji-lock")
                self.assertEqual((Path(pam_dir) / "system-login").resolve(), policy / "system-login")
                self.assertIn("system-auth", (Path(pam_dir) / service).read_text())
                self.assertEqual((Path(pam_dir) / service).stat().st_mode & 0o777, 0o600)
                # Running the setup again must preserve the distro links.
                self.assertEqual(launch.pam_configuration(Path(directory)), (pam_dir, service))


if __name__ == "__main__":
    unittest.main()
