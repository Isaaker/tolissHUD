#!/usr/bin/env python3
"""Build a manual-install ZIP and a static SkunkCrafts Updater depot.

The depot is served as static files by GitHub Pages. It follows the published
SkunkCrafts Updater depot format (CRC32 whitelist + sizes list).
"""
from __future__ import annotations

import argparse
import html
import os
import re
import shutil
import sys
import zipfile
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LUA_FILE = "xphud_toliss_a32x.lua"
PRODUCT_FOLDER = "XPHUD_ToLiss_A32X"
INSTALL_RELATIVE = Path("Resources/plugins/FlyWithLua/Scripts") / PRODUCT_FOLDER
PAYLOAD_FILES = (
    LUA_FILE,
    "README.md",
    "CHANGELOG.md",
    "LICENSE",
    "AUTHORS.md",
    "NOTICE.md",
    "UPSTREAM_README.md",
    "AIRBUS_HUD_NOTES.md",
)


def fail(message: str) -> "NoReturn":
    raise SystemExit(f"build_release: error: {message}")


def read_version() -> str:
    version_file = ROOT / "VERSION"
    if not version_file.is_file():
        fail("VERSION file is missing")
    version = version_file.read_text(encoding="utf-8").strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        fail(f"VERSION must be strict MAJOR.MINOR.PATCH, got {version!r}")
    lua = (ROOT / LUA_FILE).read_text(encoding="utf-8")
    match = re.search(r"^--\s+XPHUD.*?v(\d+\.\d+\.\d+)", lua, re.MULTILINE)
    if not match:
        fail("could not read version from the Lua header")
    if match.group(1) != version:
        fail(f"VERSION ({version}) does not match Lua header ({match.group(1)})")
    return version


def validate_repo(repo: str) -> tuple[str, str]:
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo):
        fail(f"repository must be OWNER/REPOSITORY, got {repo!r}")
    owner, name = repo.split("/", 1)
    return owner, name


def pages_base_url(repo: str, override: str | None) -> str:
    owner, name = validate_repo(repo)
    base = (override or os.environ.get("XPHUD_PAGES_BASE_URL", "")).strip()
    if not base:
        if name.lower() == f"{owner}.github.io".lower():
            base = f"https://{owner}.github.io"
        else:
            base = f"https://{owner}.github.io/{name}"
    base = base.rstrip("/")
    if not base.startswith("https://"):
        fail("GitHub Pages base URL must use HTTPS")
    return base


def updater_config(version: str, depot_url: str) -> str:
    return (
        "name|XPHUD ToLiss A32X\n"
        f"module|{depot_url}\n"
        f"version|{version}\n"
        "locked|false\n"
        "zone|custom\n"
        "changelog|changelog.txt\n"
        "readme|readme.txt\n"
    )


def changelog_sections(text: str) -> list[tuple[str, list[str], str]]:
    """Return (version, bullets, heading) for Markdown ## version sections."""
    sections: list[tuple[str, list[str], str]] = []
    current_version: str | None = None
    current_heading = ""
    current_bullets: list[str] = []
    for line in text.splitlines():
        m = re.match(r"^##\s+(\d+\.\d+\.\d+)(.*)$", line.strip())
        if m:
            if current_version:
                sections.append((current_version, current_bullets, current_heading))
            current_version = m.group(1)
            current_heading = m.group(2).strip(" —-:")
            current_bullets = []
        elif current_version and re.match(r"^\s*[-*]\s+", line):
            current_bullets.append(re.sub(r"^\s*[-*]\s+", "- ", line).strip())
    if current_version:
        sections.append((current_version, current_bullets, current_heading))
    return sections


def updater_changelog(markdown: str, version: str) -> str:
    sections = changelog_sections(markdown)
    if not sections or sections[0][0] != version:
        fail(f"CHANGELOG.md must start with a ## {version} section")
    output: list[str] = []
    for item_version, bullets, _heading in sections:
        output.append(item_version)
        output.extend(bullets or ["- Maintenance and documentation updates."])
        output.append("")
    return "\n".join(output).rstrip() + "\n"


def markdown_to_text(markdown: str) -> str:
    """Small dependency-free Markdown-to-text conversion for the updater tab."""
    out: list[str] = []
    for line in markdown.splitlines():
        line = re.sub(r"^\s{0,3}#{1,6}\s+", "", line)
        line = re.sub(r"!\[([^]]*)\]\([^)]*\)", r"[Image: \1]", line)
        line = re.sub(r"\[([^]]+)\]\((https?://[^)]+)\)", r"\1 <\2>", line)
        line = re.sub(r"`([^`]*)`", r"\1", line)
        line = line.replace("**", "").replace("__", "").replace("*", "").replace("_", "")
        out.append(line)
    return "\n".join(out).strip() + "\n"


def copy_payload(destination: Path, version: str, depot_url: str) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    for filename in PAYLOAD_FILES:
        src = ROOT / filename
        if not src.is_file():
            fail(f"required release file is missing: {filename}")
        shutil.copy2(src, destination / filename)
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    (destination / "readme.txt").write_text(markdown_to_text(readme), encoding="utf-8")
    (destination / "changelog.txt").write_text(updater_changelog(changelog, version), encoding="utf-8")
    (destination / "skunkcrafts_updater.cfg").write_text(
        updater_config(version, depot_url), encoding="utf-8"
    )


def build_depot(product_dir: Path, depot_dir: Path) -> None:
    """Create the static depot index; local config is not put on the whitelist."""
    shutil.copytree(product_dir, depot_dir, dirs_exist_ok=True)

    entries: list[tuple[str, int, int]] = []
    for path in sorted(depot_dir.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(depot_dir).as_posix()
        if rel == "skunkcrafts_updater.cfg":
            continue
        if any(part.startswith(".") for part in Path(rel).parts):
            continue
        payload = path.read_bytes()
        crc = zlib.crc32(payload) & 0xFFFFFFFF
        entries.append((rel, crc, len(payload)))

    whitelist = "".join(f"{path}|{crc}\n" for path, crc, _size in entries)
    sizes = "".join(f"{path}|{size}\n" for path, _crc, size in entries)
    (depot_dir / "skunkcrafts_updater_whitelist.txt").write_text(whitelist, encoding="utf-8")
    (depot_dir / "skunkcrafts_updater_sizeslist.txt").write_text(sizes, encoding="utf-8")


def write_site_index(site_dir: Path, version: str, depot_url: str, zip_name: str, repo: str) -> None:
    site_dir.mkdir(parents=True, exist_ok=True)
    # Prevent GitHub Pages/Jekyll from transforming Markdown files in the depot.
    (site_dir / ".nojekyll").write_text("", encoding="utf-8")
    escaped_url = html.escape(depot_url, quote=True)
    escaped_zip = html.escape(zip_name)
    html_doc = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>XPHUD ToLiss A32X update depot</title>
  <meta name="robots" content="noindex">
  <style>body{{font:16px/1.55 system-ui,sans-serif;max-width:760px;margin:3rem auto;padding:0 1rem;color:#20252b}}code{{overflow-wrap:anywhere}}a{{color:#075eb5}}</style>
</head>
<body>
  <h1>XPHUD ToLiss A32X</h1>
  <p>SkunkCrafts Updater production depot — version {html.escape(version)}.</p>
  <p>Depot endpoint: <code>{escaped_url}</code></p>
  <p>Downloads are published through the <a href="https://github.com/{html.escape(repo)}/releases">GitHub Releases</a> page.</p>
  <p>Manual installer: <code>{escaped_zip}</code></p>
</body>
</html>
"""
    (site_dir / "index.html").write_text(html_doc, encoding="utf-8")


def build(version: str, repo: str, output_dir: Path, pages_override: str | None = None) -> dict[str, Path]:
    actual = read_version()
    if version != actual:
        fail(f"requested version {version} does not match repository version {actual}")
    owner, name = validate_repo(repo)
    base = pages_base_url(repo, pages_override)
    depot_url = f"{base}/skunkcrafts/main"

    output_dir.mkdir(parents=True, exist_ok=True)

    product_dir = output_dir / "product" / PRODUCT_FOLDER
    copy_payload(product_dir, version, depot_url)

    zip_name = f"XPHUD_ToLiss_A32X_v{version}.zip"
    archive_path = output_dir / zip_name
    install_root = Path("Resources/plugins/FlyWithLua/Scripts") / PRODUCT_FOLDER
    with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(product_dir.rglob("*")):
            if path.is_file():
                arcname = (install_root / path.relative_to(product_dir)).as_posix()
                archive.write(path, arcname)

    site_dir = output_dir / "site"
    build_depot(product_dir, site_dir / "skunkcrafts" / "main")
    write_site_index(site_dir, version, depot_url, zip_name, repo)

    changelog_text = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    sections = changelog_sections(changelog_text)
    latest = sections[0]
    release_notes = [f"# XPHUD ToLiss A32X v{version}", ""]
    if latest[2]:
        release_notes += [f"**{latest[2]}**", ""]
    release_notes += latest[1] or ["- Maintenance and documentation updates."]
    release_notes += ["", "## Installation", "", "Extract the ZIP into the X-Plane 12 installation root. The script is installed under `Resources/plugins/FlyWithLua/Scripts/XPHUD_ToLiss_A32X/`.", "", "SkunkCrafts Updater management requires client 4.2.7 or newer for per-folder FlyWithLua scripts."]
    notes_path = output_dir / "RELEASE_NOTES.md"
    notes_path.write_text("\n".join(release_notes) + "\n", encoding="utf-8")

    return {"archive": archive_path, "site": site_dir, "notes": notes_path, "product": product_dir}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY"), help="GitHub OWNER/REPOSITORY")
    parser.add_argument("--version", default=None, help="release version without leading v (default: VERSION file)")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "dist")
    parser.add_argument("--pages-base-url", default=None, help="optional custom Pages base URL")
    args = parser.parse_args()
    if not args.repo:
        fail("--repo OWNER/REPOSITORY is required (or set GITHUB_REPOSITORY)")
    version = args.version or read_version()
    results = build(version, args.repo, args.output_dir, args.pages_base_url)
    for key, path in results.items():
        print(f"{key}: {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
