#!/usr/bin/env python3
"""Compile/run the production pure-C game engine and protocol with a host C compiler."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cc", help="Host GCC/Clang executable (or set CC)")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    compiler = args.cc or os.environ.get("CC") or shutil.which("clang") or shutil.which("gcc")
    if not compiler:
        print("A host Clang/GCC compiler is required; pass --cc or set CC.", file=sys.stderr)
        return 2
    output_dir = root / ".build/game-tests"
    output_dir.mkdir(parents=True, exist_ok=True)
    executable = output_dir / ("test_game.exe" if os.name == "nt" else "test_game")
    command = [compiler, "-std=c99", "-Wall", "-Wextra", "-Werror", "-pedantic", "-O2",
               "-I", str(root / "stm32/Game/Inc"), "-I", str(root / "game/generated"),
               str(root / "stm32/Game/Src/game_engine.c"),
               str(root / "stm32/Game/Src/game_protocol.c"),
               str(root / "stm32/Game/tests/test_game.c"), "-o", str(executable)]
    try:
        subprocess.run(command, cwd=root, check=True, timeout=60)
        subprocess.run([str(executable)], cwd=root, check=True, timeout=15)
    except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
