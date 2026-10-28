"""Launch-path regression checks. Run explicitly with python3; no engine is started."""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / "config/shoji-shell/live-wallpaper.py"
spec = importlib.util.spec_from_file_location("live_wallpaper", SOURCE)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class WallpaperLaunchTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.engine = self.root / "shoji-shell/wallpaper-engine"
        self.layer = dict(outputs=["TEST-1"], path="/scene", crop=dict(x=0.5, y=0, zoom=1))
        environment = patch.dict(os.environ, XDG_DATA_HOME=str(self.root))
        environment.start()
        self.addCleanup(environment.stop)

    def private_runtime(self):
        for name in ("runtime/linux-wallpaperengine", "runtime/liblinux-wallpaperengine-lib.so",
                     "runtime/libcef.so", "lib/libmpv.so.2"):
            file = self.engine / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.touch()

    def test_private_executable_bypasses_system_wrapper(self):
        self.private_runtime()
        with patch.object(helper.shutil, "which", return_value="/system/wrapper"), \
                patch.object(helper.subprocess, "Popen") as launch:
            helper.launch(self.layer, "/assets", self.root)
        args, kwargs = launch.call_args
        self.assertEqual(args[0][4], str(self.engine / "runtime/linux-wallpaperengine"))
        self.assertEqual(kwargs["cwd"], self.engine / "runtime")
        self.assertEqual(kwargs["env"]["LD_LIBRARY_PATH"].split(os.pathsep)[:2],
                         [str(self.engine / "lib"), str(self.engine / "runtime")])

    def test_partial_private_runtime_does_not_silently_use_stock_engine(self):
        self.private_runtime()
        (self.engine / "lib/libmpv.so.2").unlink()
        with patch.object(helper.subprocess, "Popen") as launch:
            with self.assertRaises(ValueError):
                helper.launch(self.layer, "/assets", self.root)
            launch.assert_not_called()

    def test_stock_engine_remains_available_without_private_install(self):
        with patch.object(helper.shutil, "which", return_value="/system/wrapper"), \
                patch.object(helper.subprocess, "Popen") as launch:
            helper.launch(self.layer, "/assets", self.root)
        self.assertEqual(launch.call_args.args[0][4], "/system/wrapper")
        self.assertIsNone(launch.call_args.kwargs["cwd"])

    def test_missing_engine_reports_setup_requirement(self):
        with patch.object(helper.shutil, "which", return_value=None), \
                patch.object(helper.subprocess, "Popen") as launch:
            with self.assertRaisesRegex(ValueError, "build-wallpaper-engine"):
                helper.launch(self.layer, "/assets", self.root)
            launch.assert_not_called()


if __name__ == "__main__":
    unittest.main()
