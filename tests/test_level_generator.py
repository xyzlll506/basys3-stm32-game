"""Tests for invalid-level rejection and generated-file freshness."""

from contextlib import redirect_stderr, redirect_stdout
import copy
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("generate_level", ROOT / "scripts/generate_level.py")
GENERATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GENERATOR)


class LevelGeneratorTests(unittest.TestCase):
    def setUp(self):
        self.level = json.loads((ROOT / "game/level.json").read_text(encoding="utf-8"))

    def run_cli(self, *arguments):
        with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            return GENERATOR.main(list(arguments))

    def test_checked_in_outputs_are_current(self):
        self.assertEqual(self.run_cli("--check"), 0)

    def test_generate_then_detect_stale_or_missing_output(self):
        with tempfile.TemporaryDirectory(prefix="basys_level_test_") as folder:
            output = Path(folder) / "generated"
            args = ("--output-dir", str(output))
            self.assertEqual(self.run_cli(*args), 0)
            self.assertEqual(self.run_cli(*args, "--check"), 0)
            original_c = (output / "level.h").read_bytes()
            (output / "level.h").write_bytes(original_c + b"// stale\n")
            self.assertEqual(self.run_cli(*args, "--check"), 1)
            self.assertEqual(self.run_cli(*args), 0)
            self.assertEqual((output / "level.h").read_bytes(), original_c)
            (output / "level.vh").unlink()
            self.assertEqual(self.run_cli(*args, "--check"), 1)

    def test_reject_boolean_and_fractional_coordinates(self):
        for invalid in (True, 1.5, "40"):
            with self.subTest(value=invalid):
                value = copy.deepcopy(self.level)
                value["spawn"]["x"] = invalid
                with self.assertRaises(ValueError):
                    GENERATOR.validate(value)

    def test_reject_invalid_sizes_and_outside_rectangles(self):
        for field, invalid in (("w", 0), ("h", -1), ("x", -1), ("w", 641), ("y", 480)):
            with self.subTest(field=field, value=invalid):
                value = copy.deepcopy(self.level)
                value["platforms"][0][field] = invalid
                with self.assertRaises(ValueError):
                    GENERATOR.validate(value)

    def test_reject_unimplemented_world_player_and_slot_counts(self):
        cases = [copy.deepcopy(self.level) for _ in range(4)]
        cases[0]["world"]["w"] = 800
        cases[1]["player"]["h"] = 20
        cases[2]["platforms"].pop()
        cases[3]["hazards"].append(dict(cases[3]["hazards"][0]))
        for value in cases:
            with self.subTest(level=value), self.assertRaises(ValueError):
                GENERATOR.validate(value)

    def test_reject_spawn_inside_platform_or_hazard(self):
        for x, y in ((40, 430), (245, 410)):
            value = copy.deepcopy(self.level)
            value["spawn"] = {"x": x, "y": y}
            with self.subTest(x=x, y=y), self.assertRaises(ValueError):
                GENERATOR.validate(value)

    def test_reject_goal_without_clear_supported_standing_space(self):
        unsupported = copy.deepcopy(self.level)
        unsupported["goal"]["x"] = 20
        blocked = copy.deepcopy(self.level)
        blocked["platforms"][1] = {"x": 510, "y": 112, "w": 120, "h": 33}
        for value in (unsupported, blocked):
            with self.subTest(level=value), self.assertRaises(ValueError):
                GENERATOR.validate(value)

    def test_invalid_source_does_not_create_output(self):
        with tempfile.TemporaryDirectory(prefix="basys_level_invalid_") as folder:
            source = Path(folder) / "bad.json"
            output = Path(folder) / "generated"
            invalid = copy.deepcopy(self.level)
            invalid["goal"]["w"] = 0
            source.write_text(json.dumps(invalid), encoding="utf-8")
            self.assertEqual(self.run_cli("--input", str(source), "--output-dir", str(output)), 1)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
