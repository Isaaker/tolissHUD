# GitHub repository setup checklist

This document covers the one-time setup after uploading the repository starter pack. The automation is intentionally scoped: read-only CI and security scans, issue write access only for TODO synchronisation, and release / Pages permissions only for the release workflow.

## 1. Create and initialise the repository

1. Create a **public** GitHub repository (recommended for a public X-Plane add-on and public SkunkCrafts depot).
2. Use `main` as the default branch, or change the branch names in the workflows.
3. Upload the contents of this starter pack to the repository root. Do not upload the outer ZIP file itself as a repository file.
4. Check that `LICENSE`, `AUTHORS.md`, `NOTICE.md`, `UPSTREAM_README.md` and the attribution in the Lua header are present.

GitHub Pages is publicly accessible. Do not put private data, credentials, private aircraft files, proprietary manuals, or personal simulator logs in the published repository / Pages artifact.

## 2. Enable Actions and Pages

1. Open **Settings → Actions → General** and ensure GitHub Actions are enabled for the repository.
2. Leave the default `GITHUB_TOKEN` permission restrictive (read-only is fine); individual workflows declare their own minimum permissions.
3. Open **Settings → Pages** and set **Build and deployment → Source** to **GitHub Actions**.
4. The release workflow creates / uses the `github-pages` environment. Add a deployment protection rule so only the default branch / trusted release process can deploy if your repository policy supports it.
5. No personal access token, external API key, or custom secret is required for the workflows included here.

The release workflow needs the explicit `contents: write` permission to publish the GitHub Release. The Pages deploy job uses `pages: write` and `id-token: write`. The TODO workflow uses `issues: write` and nothing broader. GitHub lets repository writers declare scoped job permissions in workflow YAML.

## 3. Review TODO-to-Issues synchronisation

The TODO workflow runs when `TODO.md` or its synchroniser changes on `main`. It creates / updates **one Issue per numbered TODO subsection**, retaining the checkboxes in the Issue body. It does not create one Issue per checkbox, does not create new Issues for sections already fully checked, and does not delete Issues if a TODO section is later removed.

The current roadmap dry-run reports **48 Issues to create** and skips one already-completed section. The first push to `main` that includes the workflow and `TODO.md` will apply that sync automatically. Review the dry-run locally first if you want to inspect the exact Issue titles and bodies:

```bash
python3 tools/todo_to_issues.py --file TODO.md
```

To preview from GitHub, open **Actions → TODO to GitHub Issues → Run workflow** and set `apply` to `false`. A push to `main` is an apply run. The workflow uses the repository-provided `GITHUB_TOKEN`; no PAT should be stored.

When an already-tracked section has every checkbox checked, its Issue closes. If a checkbox is later unchecked, the next sync reopens it. Editing the Issue directly is not authoritative; the next sync rewrites its body from `TODO.md`. Treat TODO as the source of truth.

These are GitHub Issues used as trackable tasks. They can be added to a GitHub Project board, but this starter does not automatically create or configure a Projects v2 board.

## 4. Configure SkunkCrafts Updater

Follow [`SKUNKCRAFTS_UPDATER.md`](SKUNKCRAFTS_UPDATER.md). In short: the production depot is hosted on GitHub Pages, the release workflow generates the updater config / CRC32 whitelist / sizes file, and the product must be installed as a dedicated FlyWithLua child folder. SkunkCrafts Updater 4.2.7 or newer is required for per-folder FlyWithLua script management.

Optional: define the repository Actions variable `XPHUD_PAGES_BASE_URL` if using a custom Pages URL. Otherwise the build script derives the standard `https://OWNER.github.io/REPOSITORY` address from `GITHUB_REPOSITORY`.

## 5. Create the first release

Before tagging, make sure `VERSION`, the Lua script header, and the first `CHANGELOG.md` section all agree. Then: 

```bash
git add .
git commit -m "Prepare XPHUD ToLiss A32X v2.2.0"
git tag v2.2.0
git push origin main --tags
```

The current version already says `2.2.0`; use `v2.2.0` only if that is the version you intend to publish as the first public release. If you make any pre-release changes, update all three version locations and the changelog before tagging. The workflow checks exact `vMAJOR.MINOR.PATCH` syntax and rejects a tag that does not match `VERSION`.

After the run succeeds, verify:

- The GitHub Release exists and contains `XPHUD_ToLiss_A32X_vX.Y.Z.zip`.
- The Pages deployment completed successfully.
- The production depot's `skunkcrafts_updater.cfg` has the expected HTTPS `module` URL and version.
- The whitelist and sizes list are present and match the actual files.
- The manual ZIP contains `Resources/plugins/FlyWithLua/Scripts/XPHUD_ToLiss_A32X/`.
- A test installation updates correctly in a disposable X-Plane profile before you announce the release.

## 6. Optional repository protections

For a public community project, consider enabling:

- **Branch protection / ruleset for `main`:** require pull requests and successful CI / Security checks before merging.
- **Dependabot alerts and security updates:** review GitHub Actions dependency update PRs. The included Dependabot config checks the GitHub Actions ecosystem weekly.
- **Secret scanning and push protection:** enable them in repository Security settings when available on your plan. Gitleaks also scans repository history from the workflow.
- **Private vulnerability reporting:** enable it under Security settings so reports can be submitted without a public issue.

Do not make the release job available to untrusted pull-request code. Create stable release tags only from reviewed commits.
