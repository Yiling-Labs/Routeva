#!/usr/bin/env python3
"""Inject nested Xcode SystemCapabilities after XcodeGen generation.

XcodeGen 2.45.4 stringifies nested target attributes. This helper keeps
project.yml as the source of truth while emitting the native pbxproj shape
that Xcode automatic signing uses to update App IDs and profiles.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


CAPABILITIES = {
    "Routeva": (
        "com.apple.ApplicationGroups.iOS",
        "com.apple.Keychain",
        "com.apple.NetworkExtensions.iOS",
        "com.apple.iCloud",
    ),
    "RoutevaPacketTunnelSingBox": (
        "com.apple.ApplicationGroups.iOS",
        "com.apple.Keychain",
        "com.apple.NetworkExtensions.iOS",
    ),
}


def matching_brace(text: str, opening: int) -> int:
    depth = 0
    quoted = False
    escaped = False
    for index in range(opening, len(text)):
        character = text[index]
        if quoted:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                quoted = False
            continue
        if character == '"':
            quoted = True
        elif character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth == 0:
                return index
    raise RuntimeError("unbalanced braces in generated pbxproj")


def target_ids(text: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for target_name in CAPABILITIES:
        pattern = re.compile(
            rf"(?m)^\s*([A-F0-9]{{24}}) /\* {re.escape(target_name)} \*/ = \{{\n"
            rf"\s*isa = PBXNativeTarget;"
        )
        match = pattern.search(text)
        if match is None:
            raise RuntimeError(f"PBXNativeTarget not found: {target_name}")
        result[target_name] = match.group(1)
    return result


def capability_block(indent: str, capability_names: tuple[str, ...]) -> str:
    lines = [f"{indent}SystemCapabilities = {{"]
    for capability_name in capability_names:
        lines.extend(
            (
                f"{indent}\t{capability_name} = {{",
                f"{indent}\t\tenabled = 1;",
                f"{indent}\t}};",
            )
        )
    lines.append(f"{indent}}};")
    return "\n".join(lines) + "\n"


def inject(text: str) -> str:
    ids = target_ids(text)
    marker = "TargetAttributes = {"
    marker_index = text.find(marker)
    if marker_index < 0:
        raise RuntimeError("TargetAttributes block not found")
    attributes_open = text.find("{", marker_index)
    attributes_close = matching_brace(text, attributes_open)

    # Process from the bottom upward so earlier offsets remain stable.
    replacements: list[tuple[int, int, str]] = []
    attributes_text = text[attributes_open : attributes_close + 1]
    for target_name, target_id in ids.items():
        entry_match = re.search(
            rf"(?m)^(?P<indent>\s*){target_id} = \{{\s*$", attributes_text
        )
        if entry_match is None:
            raise RuntimeError(f"TargetAttributes entry not found: {target_name}")
        entry_start = attributes_open + entry_match.start()
        entry_open = text.find("{", attributes_open + entry_match.start())
        entry_close = matching_brace(text, entry_open)
        entry = text[entry_start : entry_close + 1]
        if "SystemCapabilities" in entry:
            raise RuntimeError(
                f"unexpected pre-existing SystemCapabilities for {target_name}"
            )
        indent = entry_match.group("indent") + "\t"
        updated_entry = (
            entry[:-1].rstrip()
            + "\n"
            + capability_block(indent, CAPABILITIES[target_name])
            + entry_match.group("indent")
            + entry[-1]
        )
        replacements.append((entry_start, entry_close + 1, updated_entry))

    for start, end, replacement in sorted(replacements, reverse=True):
        text = text[:start] + replacement + text[end:]

    if text.count("SystemCapabilities = {") != len(CAPABILITIES):
        raise RuntimeError("capability injection count mismatch")
    return text


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: apply-signing-capabilities.py <project.pbxproj>", file=sys.stderr)
        return 2
    project_path = Path(sys.argv[1])
    original = project_path.read_text(encoding="utf-8")
    updated = inject(original)
    project_path.write_text(updated, encoding="utf-8")
    print(f"Injected signing capabilities into {project_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
