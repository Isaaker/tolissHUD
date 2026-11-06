# Contributing to XPHUD ToLiss A32X

Thanks for helping improve the project. The aim is a technically honest, well-tested HUD simulation for X-Plane and supported ToLiss aircraft—not a claim of Airbus certification or real-world operational suitability.

## Before opening an issue

- Check existing issues and the relevant section in [`TODO.md`](TODO.md).
- For a bug, include X-Plane version, FlyWithLua NG+ version, ToLiss aircraft / engine variant, plugin version, selected data sources, and a minimal reproduction.
- Attach screenshots or diagnostic output only after removing personal paths, account names, and other private information.
- Never post proprietary aircraft files, manuals, navigational databases, or copyrighted material you do not have permission to redistribute.

## Development setup

Requirements for the automated checks:

- Python 3.10 or newer (standard library only for repository tooling).
- Lua 5.4 compiler (`luac5.4`) for syntax validation.
- X-Plane 12, FlyWithLua NG+, and an applicable ToLiss aircraft for simulator integration testing.

Run the checks locally:

```bash
python3 -m unittest discover -s tests -v
python3 tools/todo_to_issues.py --file TODO.md
python3 tools/build_release.py --repo OWNER/REPOSITORY --output-dir dist
luac5.4 -p xphud_toliss_a32x.lua
```

The TODO synchroniser is dry-run by default. Do not use `--apply` against a repository unless you are authorised to create and update its issues.

## Dataref and flight-display changes

- Record the exact dataref name, type, unit, coordinate / magnetic reference, aircraft applicability, update behaviour, and evidence source.
- Keep availability, validity, freshness, and operational meaning separate. A value that is non-zero is not automatically valid.
- Do not infer units or semantics from a dataref name alone. Mark unverified assumptions in code comments and documentation.
- Keep ToLiss-specific and stock X-Plane sources separately observable in diagnostics.
- Never add a symbol that suggests a certified Airbus function unless its behaviour and inputs are understood and its non-certified status is clearly documented.
- Simulator testing is required for changes to symbology, navigation, guidance, or autopilot-related cues. Static tests are not a substitute.

## Pull requests

1. Keep each PR focused and describe the user-visible change.
2. Update `CHANGELOG.md` under the current development version when behaviour changes.
3. Update `TODO.md` when a roadmap item is implemented, deferred, or found to be inaccurate.
4. Add or update tests for parsing, data transforms, geometry, and release tooling where feasible.
5. Include simulator version / aircraft variant and test evidence for flight-display changes.
6. Do not bundle simulator logs containing personal data or copyrighted / proprietary resources.

## Versioning and releases

`VERSION` is the canonical version and must match the Lua header and release tag. Use `MAJOR.MINOR.PATCH` and tag stable releases as `vMAJOR.MINOR.PATCH`. The release workflow creates the installation ZIP, GitHub Release and production SkunkCrafts static depot. Do not manually edit generated files under `dist/`.

## Roadmap issue synchronisation

`TODO.md` is the single source of truth. The workflow creates or updates one GitHub Issue per numbered `###` subsection that contains checkboxes; it does not create one Issue per checkbox. Stable HTML markers prevent duplicates. Sections already complete on the first sync are skipped. Completing all checkboxes in a previously tracked section closes its issue; unchecking a task reopens it on the next sync. The sync does not delete orphaned issues.
