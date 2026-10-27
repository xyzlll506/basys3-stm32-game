#!/usr/bin/env python3
"""Generate C and Verilog level constants from game/level.json (stdlib only)."""

import argparse
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]


def exact_fields(value, fields, label):
    if not isinstance(value, dict) or set(value) != set(fields):
        raise ValueError(label + " must contain exactly: " + ", ".join(fields))


def integer(value, label, minimum=0):
    if type(value) is not int or value < minimum:
        raise ValueError(label + " must be an integer >= " + str(minimum))
    return value


def rect(value, label, world_w, world_h):
    exact_fields(value, ("x", "y", "w", "h"), label)
    for field in ("x", "y", "w", "h"):
        integer(value[field], label + "." + field, 1 if field in ("w", "h") else 0)
    if value["x"] + value["w"] > world_w or value["y"] + value["h"] > world_h:
        raise ValueError(label + " is outside the visible world")
    return value


def overlaps(a, b):
    return (a["x"] < b["x"] + b["w"] and a["x"] + a["w"] > b["x"]
            and a["y"] < b["y"] + b["h"] and a["y"] + a["h"] > b["y"])


def validate(level):
    exact_fields(level, ("world", "player", "spawn", "platforms", "hazards", "goal"), "level")
    exact_fields(level["world"], ("w", "h"), "world")
    world_w = integer(level["world"]["w"], "world.w", 1)
    world_h = integer(level["world"]["h"], "world.h", 1)
    if (world_w, world_h) != (640, 480):
        raise ValueError("This VGA prototype requires a 640 x 480 world")
    exact_fields(level["player"], ("w", "h"), "player")
    player_w = integer(level["player"]["w"], "player.w", 1)
    player_h = integer(level["player"]["h"], "player.h", 1)
    if (player_w, player_h) != (16, 24):
        raise ValueError("This sprite and collision prototype requires a 16 x 24 player")
    exact_fields(level["spawn"], ("x", "y"), "spawn")
    spawn = dict(level["spawn"], w=player_w, h=player_h)
    rect(spawn, "spawn player", world_w, world_h)

    # The current FPGA renderer has five platform slots and one hazard slot.
    # Reject unsupported counts rather than silently omitting geometry on one board.
    for key, count in (("platforms", 5), ("hazards", 1)):
        if not isinstance(level[key], list) or len(level[key]) != count:
            raise ValueError("This prototype requires exactly %d %s" % (count, key))
        for index, value in enumerate(level[key]):
            rect(value, "%s[%d]" % (key, index), world_w, world_h)
    rect(level["goal"], "goal", world_w, world_h)
    for item in level["platforms"] + level["hazards"] + [level["goal"]]:
        if overlaps(spawn, item):
            raise ValueError("Spawn player overlaps a platform, hazard or goal")

    goal = level["goal"]
    supported_goal = False
    for platform in level["platforms"]:
        if platform["y"] != goal["y"] + goal["h"]:
            continue
        lower = max(platform["x"], goal["x"] - player_w + 1, 0)
        upper = min(platform["x"] + platform["w"] - player_w,
                    goal["x"] + goal["w"] - 1, world_w - player_w)
        if platform["y"] < player_h:
            continue
        for x in range(lower, upper + 1):
            standing = {"x": x, "y": platform["y"] - player_h,
                        "w": player_w, "h": player_h}
            if overlaps(standing, goal) and not any(
                    overlaps(standing, obstacle)
                    for obstacle in level["platforms"] + level["hazards"]):
                supported_goal = True
                break
        if supported_goal:
            break
    if not supported_goal:
        raise ValueError("Goal must have a supporting platform and clear standing space for the player")
    return level


def scalar_constants(level):
    constants = []
    for prefix, fields in (("WORLD", ("w", "h")), ("PLAYER", ("w", "h")),
                           ("SPAWN", ("x", "y")), ("GOAL", ("x", "y", "w", "h"))):
        for field in fields:
            constants.append(("LEVEL_" + prefix + "_" + field.upper(), level[prefix.lower()][field]))
    return constants


def render_c(level):
    lines = ["/* Generated from game/level.json; edit JSON and run scripts/generate_level.py. */",
             "#ifndef LEVEL_GENERATED_H", "#define LEVEL_GENERATED_H", ""]
    lines += ["#define %s %d" % pair for pair in scalar_constants(level)]
    for key, singular in (("platforms", "PLATFORM"), ("hazards", "HAZARD")):
        lines += ["", "#define LEVEL_%s_COUNT %d" % (singular, len(level[key]))]
        records = ["{%d, %d, %d, %d}" % tuple(item[field] for field in ("x", "y", "w", "h"))
                   for item in level[key]]
        lines += ["#define LEVEL_%s {%s}" % (key.upper(), ", ".join(records))]
    return "\n".join(lines + ["", "#endif", ""])


def render_verilog(level):
    lines = ["// Generated from game/level.json; edit JSON and run scripts/generate_level.py.",
             "`ifndef LEVEL_GENERATED_VH", "`define LEVEL_GENERATED_VH", ""]
    lines += ["`define %s %d" % pair for pair in scalar_constants(level)]
    for key, singular in (("platforms", "PLATFORM"), ("hazards", "HAZARD")):
        lines += ["", "`define LEVEL_%s_COUNT %d" % (singular, len(level[key]))]
        for index, item in enumerate(level[key]):
            lines += ["`define LEVEL_%s_%d_%s %d" % (singular, index, field.upper(), item[field])
                      for field in ("x", "y", "w", "h")]
    return "\n".join(lines + ["", "`endif", ""])


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail if generated files are absent or stale")
    parser.add_argument("--input", type=Path, default=ROOT / "game/level.json")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "game/generated")
    args = parser.parse_args(argv)
    try:
        level = validate(json.loads(args.input.read_text(encoding="utf-8-sig")))
        outputs = {"level.h": render_c(level), "level.vh": render_verilog(level)}
        if args.check:
            for name, content in outputs.items():
                target = args.output_dir / name
                if not target.is_file() or target.read_text(encoding="utf-8") != content:
                    raise ValueError("Generated file is missing or stale: " + str(target))
            print("PASS: shared C/Verilog level files match validated JSON")
        else:
            args.output_dir.mkdir(parents=True, exist_ok=True)
            for name, content in outputs.items():
                with (args.output_dir / name).open("w", encoding="utf-8", newline="\n") as stream:
                    stream.write(content)
            print("Generated level.h and level.vh from validated JSON")
    except (OSError, ValueError) as exc:
        print("FAIL: " + str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
