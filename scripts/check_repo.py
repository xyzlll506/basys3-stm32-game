#!/usr/bin/env python3
"""Check portable project references, documentation and published firmware.

Uses only the Python 3.9+ standard library. This does not compile firmware
or replace FPGA timing analysis and physical board testing.
"""

import hashlib
from pathlib import Path, PureWindowsPath
import re
import sys
from urllib.parse import unquote, urlsplit
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def inside_repo(path):
    resolved = path.resolve()
    require(resolved.is_relative_to(ROOT), "Path leaves repository: " + str(path))
    return resolved


def project_path(project_dir, value):
    require(not PureWindowsPath(value).is_absolute(), "Absolute project path: " + value)
    return inside_repo(project_dir / value.replace("\\", "/"))


def check_keil():
    project = ROOT / "stm32/MDK-ARM/nucleo_f413zh_uart.uvprojx"
    tree = ET.parse(project)
    refs = tree.findall(".//FilePath")
    require(bool(refs), "Keil project has no sources")
    for element in refs:
        value = (element.text or "").strip()
        require(bool(value), "Empty Keil source reference")
        require(project_path(project.parent, value).is_file(), "Missing Keil source: " + value)
    for element in tree.findall(".//IncludePath"):
        for value in (element.text or "").split(";"):
            if value.strip():
                require(project_path(project.parent, value.strip()).is_dir(),
                        "Missing include directory: " + value)
    scatter = tree.findtext(".//ScatterFile", "")
    require(bool(scatter), "Keil scatter file was not specified")
    require(project_path(project.parent, scatter).is_file(), "Scatter file is missing")
    target = tree.findtext(".//TargetName")
    for element in tree.findall(".//targetInfo"):
        require(element.get("name") == target, "RTE target name does not match Keil target")
    print("PASS: Keil relative references (%d source files)" % len(refs))


def check_firmware():
    manifest = ROOT / "SHA256SUMS.txt"
    expected_paths = {"fpga/prebuilt/board_link_top.bit", "stm32/firmware/nucleo_f413zh_uart.hex"}
    seen = set()
    for line in manifest.read_text(encoding="utf-8-sig").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        digest, name = line.split(None, 1)
        name = name.strip().lstrip("*")
        require(name in expected_paths and name not in seen, "Unexpected/duplicate firmware: " + name)
        require(bool(re.fullmatch(r"[0-9a-fA-F]{64}", digest)), "Invalid SHA256 entry")
        data = inside_repo(ROOT / name).read_bytes()
        require(hashlib.sha256(data).hexdigest() == digest.lower(), "Firmware SHA256 mismatch: " + name)
        seen.add(name)
    require(seen == expected_paths, "Firmware checksum entries are missing")

    firmware = ROOT / "stm32/firmware/nucleo_f413zh_uart.hex"
    eof = False
    data_records = 0
    for line_no, line in enumerate(firmware.read_text(encoding="ascii").splitlines(), 1):
        require(not eof, "Intel HEX has data after EOF")
        require(line.startswith(":"), "Invalid Intel HEX at line %d" % line_no)
        record = bytes.fromhex(line[1:])
        require(len(record) >= 5 and len(record) == record[0] + 5,
                "Intel HEX byte count mismatch at line %d" % line_no)
        require(sum(record) % 256 == 0, "Intel HEX checksum failed at line %d" % line_no)
        if record[3] == 0:
            data_records += 1
        if record[3] == 1:
            require(record[:4] == bytes((0, 0, 0, 1)), "Malformed Intel HEX EOF")
            eof = True
    require(eof and data_records > 0, "Intel HEX data/EOF missing")
    print("PASS: BIT/HEX SHA256 and Intel HEX records")


def check_docs():
    documents = list((ROOT / "docs").rglob("*.md"))
    documents += list(ROOT.glob("*.md"))
    documents += [ROOT / "fpga/README.md", ROOT / "stm32/README_STM32.md"]
    count = 0
    for document in documents:
        content = document.read_text(encoding="utf-8-sig")
        # Authored documents use inline links without spaces or nested parentheses.
        for match in re.finditer(r"!?\[[^\]\n]*\]\(([^\s)]+)\)", content):
            address = match.group(1)
            parts = urlsplit(address)
            if parts.scheme or address.startswith("#") or address.startswith("//"):
                continue
            relative = unquote(parts.path)
            if relative:
                require(inside_repo(document.parent / relative).exists(),
                        "Broken local link in %s: %s" % (document.relative_to(ROOT), address))
                count += 1
    ET.parse(ROOT / "docs/images/wiring.svg")
    print("PASS: authored Markdown local links (%d) and SVG XML" % count)


def check_licenses():
    for name in (
        "LICENSE_STATUS.md",
        "THIRD_PARTY_NOTICES.md",
        "fpga/constraints/Digilent-LICENSE.txt",
        "stm32/Package_license.md",
        "stm32/LICENSE_ST_TEMPLATE.txt",
        "stm32/Drivers/CMSIS/LICENSE.txt",
        "stm32/Drivers/CMSIS/Device/ST/STM32F4xx/LICENSE.txt",
        "stm32/Drivers/STM32F4xx_HAL_Driver/LICENSE.txt",
    ):
        require((ROOT / name).is_file(), "Missing license/provenance file: " + name)
    print("PASS: third-party license files retained")


def main():
    try:
        check_keil()
        check_firmware()
        check_docs()
        check_licenses()
    except (ValueError, OSError, ET.ParseError) as exc:
        print("FAIL: " + str(exc), file=sys.stderr)
        return 1
    print("PASS: repository checks; no compilation or hardware test performed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
