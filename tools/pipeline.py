"""Single entry point for Neighborhood Life verification and release artifacts.

The production package is always built from NeighborhoodLife only.  The QA mod,
isolated profiles and evidence are deliberately outside that package.
"""
from __future__ import annotations

import argparse
import difflib
import hashlib
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = Path(r"E:\SteamLibrary\steamapps\common\ProjectZomboid")
LUA = Path(r"C:\Program Files (x86)\Lua\5.1\lua.exe")
LUAC = Path(r"C:\Program Files (x86)\Lua\5.1\luac.exe")


def run(label: str, command: list[Path | str], cwd: Path = ROOT, record: list[str] | None = None) -> None:
    command_text = subprocess.list2cmdline([str(x) for x in command])
    result = subprocess.run([str(x) for x in command], cwd=cwd, text=True, capture_output=True)
    if record is not None:
        record.extend([
            f"{label} COMMAND: {command_text}",
            f"{label} INPUT: {cwd}",
            f"{label} OUTPUT: {result.stdout.strip()}",
            f"{label} STDERR: {result.stderr.strip()}",
            f"{label} EXIT: {result.returncode}",
        ])
    if result.returncode:
        sys.stdout.write("\n".join(record or []))
        raise SystemExit(result.returncode)


def files(root: Path) -> dict[str, Path]:
    return {p.relative_to(root).as_posix(): p for p in root.rglob("*") if p.is_file()}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def suites(target: Path, engine: bool, record: list[str]) -> None:
    run("TEST", [LUA, ROOT / "tests/hud.lua", target / "42/media/lua/client/NeighborhoodNeeds.lua", "enabled"], record=record)
    for path in target.rglob("*.lua"):
        run("SYNTAX", [LUAC, "-p", path], record=record)
    suite_names = ["gameplay", "wardrobe", "social", "social-authority"]
    if (target / "42/media/lua/shared/NL/Neighbors.lua").exists():
        suite_names.append("neighbors")
    if (target / "42/media/lua/client/NL/Plumbob.lua").exists():
        suite_names.append("plumbob")
    suite_names += ["interfaces", "wardrobe-panel", "aspirations"]
    for suite in suite_names:
        run("LUA", [LUA, ROOT / f"tests/{suite}.lua", target], record=record)
    if engine:
        run("JAVAC", ["javac", "-cp", GAME / "projectzomboid.jar", "-d", ROOT / "tests/classes", ROOT / "tests/EngineLua.java"], record=record)
        for suite in suite_names:
            run("KAHLUA", ["java", "-cp", str(ROOT / "tests/classes") + ";projectzomboid.jar;.",
                             "EngineLua", target, ROOT / f"tests/{suite}.lua"], cwd=GAME, record=record)


def test(target: Path) -> None:
    record: list[str] = ["Neighborhood Life consolidated verification"]
    suites(target, True, record)
    (ROOT / "evidence" / "latest-tests.log").write_text("\n".join(record) + "\n", encoding="utf-8")
    print("PASS: consolidated Lua 5.1, syntax and installed-game Kahlua suites")


def package(version: str, baseline: Path) -> None:
    target = ROOT / "NeighborhoodLife"
    evidence = ROOT / "evidence" / version
    evidence.mkdir(parents=True, exist_ok=True)
    record = [
        "Changed: consolidated build/test/release entry point; production package excludes QA helpers and test profiles.",
        "QA classification: Lua tests and Kahlua engine-VM tests are not multiplayer or native NPC gameplay evidence.",
    ]
    suites(target, True, record)
    output = evidence / "MODIFIED_FILE.zip"
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("NeighborhoodLife/", "")
        for relative, path in files(target).items():
            archive.write(path, f"NeighborhoodLife/{relative}")
    with zipfile.ZipFile(output) as archive:
        assert archive.testzip() is None
        assert not any(name.startswith("NeighborhoodQA/") for name in archive.namelist())

    old, new = files(baseline), files(target)
    diff: list[str] = []
    for name in sorted(set(old) | set(new)):
        is_text = Path(name).suffix.lower() in {".lua", ".py", ".ps1", ".sh", ".md", ".txt", ".json", ".ini"}
        if is_text:
            before = old[name].read_text(encoding="utf-8").splitlines(True) if name in old else []
            after = new[name].read_text(encoding="utf-8").splitlines(True) if name in new else []
            diff.extend(difflib.unified_diff(before, after, fromfile=f"baseline/{name}", tofile=f"modified/{name}"))
        elif name in old or name in new:
            diff.append(f"BINARY FILE CHANGED: baseline/{name} -> modified/{name}\n")
        if name in new:
            record.append(f"HASH {name} BASELINE {(sha(old[name]) if name in old else 'ABSENT')} MODIFIED {sha(new[name])}")
    (evidence / "DIFF_FILE.patch").write_text("".join(diff), encoding="utf-8")
    (evidence / "VERIFICATION.txt").write_text("\n".join(record + [
        f"ARTIFACT: {output}",
        f"ARTIFACT: {evidence / 'DIFF_FILE.patch'}",
        f"ARTIFACT: {evidence / 'VERIFICATION.txt'}",
        f"ARTIFACT: {evidence / 'ROLLBACK.sh'}",
    ]) + "\n", encoding="utf-8")
    print(f"PASS: release package {output}")


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    test_parser = sub.add_parser("test")
    test_parser.add_argument("--target", type=Path, default=ROOT / "NeighborhoodLife")
    package_parser = sub.add_parser("package")
    package_parser.add_argument("--version", default="v10")
    package_parser.add_argument("--baseline", type=Path, default=ROOT / "evidence" / "v09" / "baseline")
    args = parser.parse_args()
    if args.command == "test":
        test(args.target.resolve())
    else:
        package(args.version, args.baseline.resolve())


if __name__ == "__main__":
    main()
