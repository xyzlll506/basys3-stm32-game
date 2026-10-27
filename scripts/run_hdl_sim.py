#!/usr/bin/env python3
"""Run the existing serial-UART testbench with Icarus Verilog."""

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
    output_dir = root / ".build/iverilog"
    output_dir.mkdir(parents=True, exist_ok=True)
    output = output_dir / "board_link.vvp"
    sources = sorted((root / "fpga/rtl").glob("*.v"))
    sources.append(root / "fpga/sim/tb_board_link.sv")
    try:
        subprocess.run([compiler, "-g2012", "-s", "tb_board_link", "-o", str(output),
                        *map(str, sources)], cwd=root, check=True, timeout=60)
        result = subprocess.run([runtime, str(output)], cwd=root, check=True,
                                capture_output=True, text=True, timeout=90)
        print(result.stdout, end="")
        if result.stderr:
            print(result.stderr, end="", file=sys.stderr)
        if "PASS: UART framing" not in result.stdout:
            print("UART simulation did not reach its PASS checkpoint.", file=sys.stderr)
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
