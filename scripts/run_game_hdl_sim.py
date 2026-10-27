#!/usr/bin/env python3
"""Run VGA timing, packet recovery and frame-update tests with Icarus."""

from pathlib import Path
import shutil
import subprocess
import sys


def main():
    root = Path(__file__).resolve().parents[1]
    compiler = shutil.which("iverilog")
    runtime = shutil.which("vvp")
    if not compiler or not runtime:
        print("Icarus Verilog is required: put iverilog and vvp on PATH.", file=sys.stderr)
        return 2
    output_dir = root / ".build/iverilog-game"
    output_dir.mkdir(parents=True, exist_ok=True)
    output = output_dir / "game.vvp"
    # The top-level MMCM wrapper is hardware-specific; the testbench exercises
    # the real game modules directly with the specified pixel-clock period.
    sources = [file for file in sorted((root / "fpga/game/rtl").glob("*.v"))
               if file.name != "game_top.v"]
    sources += [root / "fpga/rtl/uart_rx.v", root / "fpga/rtl/uart_tx.v",
                root / "fpga/game/sim/tb_game.sv"]
    try:
        subprocess.run([compiler, "-g2012", "-I", str(root / "game/generated"),
                        "-s", "tb_game", "-o", str(output), *map(str, sources)],
                       cwd=output_dir, check=True, timeout=60)
        result = subprocess.run([runtime, str(output)], cwd=output_dir,
                                check=True, capture_output=True, text=True, timeout=120)
        print(result.stdout, end="")
        if result.stderr:
            print(result.stderr, end="", file=sys.stderr)
        if "PASS: game protocol" not in result.stdout:
            print("Game HDL simulation did not reach its PASS checkpoint.", file=sys.stderr)
            return 1
    except subprocess.CalledProcessError as exc:
        if exc.stdout:
            print(exc.stdout, end="")
        if exc.stderr:
            print(exc.stderr, end="", file=sys.stderr)
        return 1
    except (OSError, subprocess.TimeoutExpired) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
