"""Compiler failures must fail the supported build command."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class CompileCommand(unittest.TestCase):
    def test_invalid_scenarios_fail_compile(self):
        with tempfile.TemporaryDirectory(prefix="ebox-playground-compile-") as directory:
            workspace = Path(directory)
            checkout = workspace / ROOT.name
            shutil.copytree(ROOT, checkout,
                            ignore=shutil.ignore_patterns(".git", "*.elc", "__pycache__"))
            for provider in ("ecss", "ebox"):
                (workspace / provider).symlink_to(ROOT.parent / provider, target_is_directory=True)
            scenarios = checkout / "benchmarks/performance-scenarios.el"
            scenarios.write_text(";;; -*- lexical-binding: t; -*-\n(invalid-build-function)\n")
            result = subprocess.run(
                ["make", "compile", f"EMACS={os.environ.get('EMACS', 'emacs')}"],
                cwd=checkout, capture_output=True, text=True, timeout=30)
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("Scenario compilation failed", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
