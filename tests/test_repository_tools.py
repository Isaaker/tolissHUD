import sys
import tempfile
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import build_release  # noqa: E402
import todo_to_issues  # noqa: E402


class TodoParserTests(unittest.TestCase):
    def test_repository_validation_handles_valid_and_malformed_values(self):
        self.assertTrue(todo_to_issues.is_valid_repo("Isaaker/tolissHUD"))
        self.assertTrue(todo_to_issues.is_valid_repo("owner!/repo!"))
        for value in ("owner", "/repo", "owner/", "owner/repo/extra", "owner/repo name"):
            with self.subTest(value=value):
                self.assertFalse(todo_to_issues.is_valid_repo(value))
        self.assertFalse(todo_to_issues.is_valid_repo("!" * 100_000))
    def test_github_api_rejects_invalid_repository_path_segments(self):
        for owner, repo in [
            ("owner/other", "repo"),
            ("owner", "../other"),
            ("owner", "repo?state=all"),
            ("..", "repo"),
        ]:
            with self.subTest(owner=owner, repo=repo):
                with self.assertRaises(ValueError):
                    todo_to_issues.GitHubAPI(owner, repo, "token")

    def test_github_api_builds_fixed_github_endpoint(self):
        api = todo_to_issues.GitHubAPI("valid-owner", "valid_repo.name", "token")
        self.assertEqual(api.base, "https://api.github.com/repos/valid-owner/valid_repo.name")

    def test_real_roadmap_groups_checklists_by_subsection(self):
        groups = todo_to_issues.parse_todo(ROOT / "TODO.md")
        self.assertGreaterEqual(len(groups), 40)
        self.assertGreater(sum(group.task_count for group in groups), 400)
        dataref = next(group for group in groups if group.title.startswith("2.1 "))
        self.assertIn("formal dataref catalogue", dataref.title)
        self.assertGreater(dataref.task_count, 0)
        self.assertEqual(dataref.key, "xphud-todo-2-1")

    def test_issue_body_contains_stable_marker_and_checkboxes(self):
        groups = todo_to_issues.parse_todo(ROOT / "TODO.md")
        group = next(group for group in groups if group.title.startswith("5.5 "))
        body = todo_to_issues.issue_body(group)
        self.assertIn(f"<!-- xphud-todo-section: {group.key} -->", body)
        self.assertIn("[ ]", body)
        self.assertIn("Checklist progress", body)

    def test_completed_untracked_sections_are_not_created(self):
        groups = todo_to_issues.parse_todo(ROOT / "TODO.md")
        completed = next(group for group in groups if group.complete)
        stats = todo_to_issues.sync([completed], todo_to_issues.GitHubAPI("dry", "run", ""), apply=False)
        self.assertEqual(stats["create"], 0)
        self.assertEqual(stats["completed_skipped"], 1)

    def test_dry_run_requires_no_token(self):
        groups = todo_to_issues.parse_todo(ROOT / "TODO.md")
        stats = todo_to_issues.sync(groups[:2], todo_to_issues.GitHubAPI("dry", "run", ""), apply=False)
        self.assertEqual(stats["create"], 1)
        self.assertEqual(stats["completed_skipped"], 1)


class ReleaseBuilderTests(unittest.TestCase):
    def test_validate_repo_accepts_github_repository_names(self):
        self.assertEqual(build_release.validate_repo("owner-name/repo.name_1"), ("owner-name", "repo.name_1"))

    def test_validate_repo_rejects_malformed_names(self):
        for repo in ("owner", "/repo", "owner/", "owner/repo/extra", "owner/repo-name!", "öwner/repo"):
            with self.subTest(repo=repo), self.assertRaises(SystemExit):
                build_release.validate_repo(repo)

    def test_version_is_consistent(self):
        self.assertEqual(build_release.read_version(), (ROOT / "VERSION").read_text().strip())

    def test_license_keeps_upstream_and_derivative_attribution(self):
        license_text = (ROOT / "LICENSE").read_text(encoding="utf-8")
        self.assertIn("Copyright (c) 2026 xbard", license_text)
        self.assertIn("Copyright (c) 2026 Control_TWR", license_text)
        self.assertIn("Permission is hereby granted", license_text)

    def test_changelog_converter_uses_skunkcrafts_version_first_format(self):
        markdown = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
        output = build_release.updater_changelog(markdown, build_release.read_version())
        self.assertTrue(output.startswith(build_release.read_version() + "\n"))
        self.assertRegex(output, r"\n- .+\n")

    def test_builds_manual_zip_and_static_depot(self):
        with tempfile.TemporaryDirectory() as temporary:
            out = Path(temporary) / "dist"
            out.mkdir()
            sentinel = out / "keep.txt"
            sentinel.write_text("preserve existing output")
            result = build_release.build(
                build_release.read_version(),
                "control-twr/xphud-toliss-a32x",
                out,
            )
            self.assertEqual(sentinel.read_text(), "preserve existing output")
            self.assertTrue(result["archive"].is_file())
            self.assertTrue((result["site"] / "skunkcrafts/main/skunkcrafts_updater.cfg").is_file())
            self.assertTrue((result["site"] / "skunkcrafts/main/skunkcrafts_updater_whitelist.txt").is_file())
            self.assertTrue((result["site"] / "skunkcrafts/main/skunkcrafts_updater_sizeslist.txt").is_file())
            self.assertTrue((result["site"] / "index.html").is_file())
            self.assertTrue((result["site"] / ".nojekyll").is_file())
            site_root = result["site"] / "skunkcrafts" / "main"
            whitelist = (site_root / "skunkcrafts_updater_whitelist.txt").read_text().splitlines()
            sizes = (site_root / "skunkcrafts_updater_sizeslist.txt").read_text().splitlines()
            whitelist_map = {line.rsplit("|", 1)[0]: int(line.rsplit("|", 1)[1]) for line in whitelist}
            sizes_map = {line.rsplit("|", 1)[0]: int(line.rsplit("|", 1)[1]) for line in sizes}
            self.assertEqual(set(whitelist_map), set(sizes_map))
            for relative_path, expected_crc in whitelist_map.items():
                payload = (site_root / relative_path).read_bytes()
                self.assertEqual(zlib.crc32(payload) & 0xFFFFFFFF, expected_crc)
                self.assertEqual(len(payload), sizes_map[relative_path])
            self.assertNotIn("skunkcrafts_updater.cfg", whitelist_map)
            config = (result["product"] / "skunkcrafts_updater.cfg").read_text()
            self.assertIn("module|https://control-twr.github.io/xphud-toliss-a32x/skunkcrafts/main", config)
            import zipfile
            with zipfile.ZipFile(result["archive"]) as archive:
                names = archive.namelist()
                self.assertTrue(any(name.endswith("/xphud_toliss_a32x.lua") for name in names))
                self.assertTrue(any(name.endswith("/skunkcrafts_updater.cfg") for name in names))
                self.assertFalse(any("TODO.md" in name for name in names))


if __name__ == "__main__":
    unittest.main()
