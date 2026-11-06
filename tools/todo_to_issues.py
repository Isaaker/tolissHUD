#!/usr/bin/env python3
"""Synchronise TODO.md checkbox groups into GitHub Issues.

One issue is created per numbered TODO subsection (not one issue per checkbox).
TODO.md remains the source of truth: edits to it update issue bodies, and marking
all checkboxes in a section complete closes its issue. Reopening any checkbox
reopens that issue on the next sync.

Dry-run is the default. Use --apply in a trusted workflow or by explicit choice.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any

MARKER_RE = re.compile(r"<!--\s*xphud-todo-section:\s*([a-z0-9-]+)\s*-->")
HEADING_RE = re.compile(r"^(#{2,3})[ \t]+(.+?)\s*$")
CHECKBOX_RE = re.compile(r"^\s*[-*+]\s+\[([ xX])\]\s+(.+?)\s*$")
API_VERSION = "2022-11-28"


@dataclass
class TodoGroup:
    key: str
    title: str
    parent: str
    body: str
    task_count: int
    checked_count: int

    @property
    def complete(self) -> bool:
        return self.task_count > 0 and self.checked_count == self.task_count


def stable_key(title: str) -> str:
    """Use the numbered heading prefix for stability across wording edits."""
    m = re.match(r"^(\d+(?:\.\d+)*)\b", title.strip())
    if m:
        return "xphud-todo-" + m.group(1).replace(".", "-")
    slug = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")[:48]
    if slug:
        return "xphud-todo-" + slug
    digest = hashlib.sha256(title.encode("utf-8")).hexdigest()[:12]
    return "xphud-todo-" + digest


def parse_todo(path: Path) -> list[TodoGroup]:
    lines = path.read_text(encoding="utf-8").splitlines()
    groups: list[dict[str, Any]] = []
    parent = ""
    active: dict[str, Any] | None = None

    def new_group(title: str, parent_title: str, heading_line: int | None, implicit: bool = False) -> dict[str, Any]:
        group = {
            "title": title,
            "parent": parent_title,
            "start": heading_line if heading_line is not None else 0,
            "lines": [],
            "task_count": 0,
            "checked_count": 0,
            "implicit": implicit,
        }
        groups.append(group)
        return group

    for idx, line in enumerate(lines):
        match = HEADING_RE.match(line)
        if match:
            level = len(match.group(1))
            title = match.group(2).strip()
            if level == 2:
                parent = title
                active = None
            elif level == 3:
                active = new_group(title, parent, idx)
            continue

        checkbox = CHECKBOX_RE.match(line)
        if checkbox:
            if active is None:
                # Rare checklist directly beneath an H2: keep it grouped there.
                active = new_group(parent or "Unsectioned TODO items", parent, None, implicit=True)
            active["task_count"] += 1
            if checkbox.group(1).lower() == "x":
                active["checked_count"] += 1

        if active is not None:
            active["lines"].append(line)

    parsed: list[TodoGroup] = []
    used: set[str] = set()
    for raw in groups:
        if raw["task_count"] == 0:
            continue
        title = raw["title"]
        key = stable_key(title)
        if key in used:
            # Preserve unique identity even if a document accidentally repeats a heading.
            key += "-" + hashlib.sha256((raw["parent"] + title).encode("utf-8")).hexdigest()[:8]
        used.add(key)
        body_lines = list(raw["lines"])
        while body_lines and not body_lines[0].strip():
            body_lines.pop(0)
        while body_lines and not body_lines[-1].strip():
            body_lines.pop()
        parsed.append(TodoGroup(
            key=key,
            title=title,
            parent=raw["parent"],
            body="\n".join(body_lines).strip(),
            task_count=raw["task_count"],
            checked_count=raw["checked_count"],
        ))
    return parsed


def priority_for(group: TodoGroup) -> str:
    match = re.search(r"\[P([0-3])(?:\s*/[^]]*)?\]", group.parent + " " + group.title)
    return f"P{match.group(1)}" if match else "Unprioritised"


def issue_body(group: TodoGroup) -> str:
    marker = f"<!-- xphud-todo-section: {group.key} -->"
    header = [
        marker,
        "> Automatically synchronised from `TODO.md`. Edit the source checklist in `TODO.md`; the next sync will update this issue.",
        "",
        f"**Roadmap section:** {group.parent}",
        f"**Priority:** {priority_for(group)}",
        f"**Checklist progress:** {group.checked_count}/{group.task_count} complete",
        "",
        "---",
        "",
        group.body,
    ]
    return "\n".join(header).strip() + "\n"


class GitHubAPI:
    def __init__(self, owner: str, repo: str, token: str, dry_run: bool = False) -> None:
        self.owner = owner
        self.repo = repo
        self.token = token
        self.dry_run = dry_run
        self.base = f"https://api.github.com/repos/{owner}/{repo}"

    def request(self, method: str, endpoint: str, payload: dict[str, Any] | None = None) -> Any:
        url = self.base + endpoint
        data = json.dumps(payload).encode("utf-8") if payload is not None else None
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Accept", "application/vnd.github+json")
        req.add_header("Authorization", f"Bearer {self.token}")
        req.add_header("X-GitHub-Api-Version", API_VERSION)
        req.add_header("User-Agent", "XPHUD-TODO-Sync/1.0")
        if data is not None:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                content = response.read()
                return json.loads(content.decode("utf-8")) if content else None
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"GitHub API {method} {endpoint} returned {exc.code}: {detail}") from exc
        except urllib.error.URLError as exc:
            raise RuntimeError(f"GitHub API connection failed: {exc.reason}") from exc

    def all_issues(self) -> list[dict[str, Any]]:
        results: list[dict[str, Any]] = []
        page = 1
        while True:
            batch = self.request("GET", f"/issues?state=all&per_page=100&page={page}")
            if not isinstance(batch, list):
                raise RuntimeError("GitHub API returned an unexpected issues response")
            # Pull requests are also returned by the Issues endpoint; skip them.
            results.extend(item for item in batch if "pull_request" not in item)
            if len(batch) < 100:
                break
            page += 1
        return results

    def create_issue(self, title: str, body: str) -> dict[str, Any]:
        return self.request("POST", "/issues", {"title": title, "body": body})

    def update_issue(self, number: int, payload: dict[str, Any]) -> dict[str, Any]:
        return self.request("PATCH", f"/issues/{number}", payload)


def sync(groups: list[TodoGroup], api: GitHubAPI, apply: bool) -> dict[str, int]:
    stats = {"create": 0, "update": 0, "close": 0, "reopen": 0, "unchanged": 0, "completed_skipped": 0}
    existing_by_key: dict[str, dict[str, Any]] = {}
    if apply:
        for issue in api.all_issues():
            marker = MARKER_RE.search(issue.get("body") or "")
            if marker:
                existing_by_key[marker.group(1)] = issue

    for group in groups:
        title = f"[TODO] {group.title}"
        body = issue_body(group)
        target_state = "closed" if group.complete else "open"
        current = existing_by_key.get(group.key)

        if current is None:
            if group.complete:
                stats["completed_skipped"] += 1
                print(f"SKIP completed section {title} ({group.checked_count}/{group.task_count} done)")
                continue
            stats["create"] += 1
            print(f"CREATE {title} ({group.checked_count}/{group.task_count} done)")
            if apply:
                api.create_issue(title, body)
                time.sleep(0.35)
            continue

        patch: dict[str, Any] = {}
        if current.get("title") != title:
            patch["title"] = title
        if (current.get("body") or "") != body:
            patch["body"] = body
        current_state = current.get("state")
        if current_state != target_state:
            patch["state"] = target_state
            if target_state == "closed":
                patch["state_reason"] = "completed"
        if not patch:
            stats["unchanged"] += 1
            continue

        if "state" in patch:
            stats["close" if patch["state"] == "closed" else "reopen"] += 1
        else:
            stats["update"] += 1
        print(f"UPDATE #{current['number']} {title}: {', '.join(patch.keys())}")
        if apply:
            api.update_issue(int(current["number"]), patch)
            time.sleep(0.2)

    return stats


def is_valid_repo(repo: str) -> bool:
    owner, separator, name = repo.partition("/")
    return bool(
        separator
        and owner
        and name
        and "/" not in name
        and not any(character.isspace() for character in repo)
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--file", type=Path, default=Path("TODO.md"))
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY"), help="OWNER/REPOSITORY")
    parser.add_argument("--apply", action="store_true", help="write changes to GitHub (default is dry-run)")
    args = parser.parse_args()

    groups = parse_todo(args.file)
    total_tasks = sum(group.task_count for group in groups)
    print(f"Parsed {len(groups)} roadmap sections and {total_tasks} checkbox tasks from {args.file}.")
    if not groups:
        print("No TODO checkbox groups found; nothing to sync.")
        return 0

    if not args.apply:
        api = GitHubAPI("dry-run", "dry-run", "", dry_run=True)
        stats = sync(groups, api, apply=False)
        print("DRY RUN — no GitHub API writes were made.")
    else:
        if not args.repo or not is_valid_repo(args.repo):
            parser.error("--repo OWNER/REPOSITORY or GITHUB_REPOSITORY is required with --apply")
        token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
        if not token:
            parser.error("GH_TOKEN or GITHUB_TOKEN is required with --apply")
        owner, repo = args.repo.split("/", 1)
        api = GitHubAPI(owner, repo, token)
        stats = sync(groups, api, apply=True)
    print("Sync summary: " + ", ".join(f"{key}={value}" for key, value in stats.items()))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as exc:
        print(f"todo_to_issues: error: {exc}", file=sys.stderr)
        raise SystemExit(1)
