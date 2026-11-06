# SkunkCrafts Updater publishing

This repository builds a static SkunkCrafts Updater depot and deploys it to GitHub Pages. The depot is generated from the tagged source; do not hand-edit files under `dist/`.

## Supported installation layout

The product is installed as its own folder:

```text
<X-Plane>/Resources/plugins/FlyWithLua/Scripts/XPHUD_ToLiss_A32X/
    xphud_toliss_a32x.lua
    skunkcrafts_updater.cfg
    ...
```

Per-folder management of FlyWithLua scripts requires SkunkCrafts Updater **4.2.7 or newer**. The product root is `XPHUD_ToLiss_A32X`, not the shared `FlyWithLua/Scripts` directory. The release builder puts the full install path in the manual ZIP and the product folder contents in the updater depot.

## One-time GitHub Pages setup

1. Push this repository to GitHub and enable GitHub Actions.
2. Open **Settings → Pages**.
3. Set the build and deployment source to **GitHub Actions**.
4. Confirm the repository's default branch is `main`, or adjust the workflow triggers.
5. Optionally define the repository Actions variable `XPHUD_PAGES_BASE_URL` if using a custom domain or a non-standard Pages URL. Otherwise the builder uses `https://OWNER.github.io/REPOSITORY`.

A successful tagged release deploys the static production depot to:

```text
https://OWNER.github.io/REPOSITORY/skunkcrafts/main
```

The product's generated `skunkcrafts_updater.cfg` points to that production depot. For a `OWNER.github.io` repository, the base URL is adjusted automatically.

## Release flow

1. Update `VERSION`, the Lua header and the top `CHANGELOG.md` section to the same version.
2. Commit and push the release-ready source.
3. Create and push a stable tag such as `v2.3.0`.
4. `.github/workflows/release.yml` validates the tag, builds the manual-install ZIP and depot, creates / updates the GitHub Release, then deploys `dist/site` to Pages.
5. Verify the GitHub Release asset and open the generated `skunkcrafts_updater.cfg` URL in a browser. Test an update in a disposable X-Plane profile before announcing it.

The depot includes `skunkcrafts_updater_whitelist.txt` (relative file path plus unsigned decimal CRC32) and `skunkcrafts_updater_sizeslist.txt` (relative file path plus byte size). These are generated deterministically from the release payload. The config file itself is excluded from the file whitelist, as required by the depot format.

## Production and beta separation

The production `skunkcrafts_updater.cfg` must always point at the production depot. Do not point the config distributed to all users at a beta URL. A private beta may use a separate tester-only config (see `config/skunkcrafts_updater_beta.cfg.example`) distributed only to invited testers, with a separately hosted beta depot. Never include the tester config in a stable release.

If using public updater channels, configure and test the channel naming and updater client behaviour separately before advertising them. Do not assume that an arbitrary `beta` string creates a channel.

## Important constraints

- Publish only files you own or are licensed to redistribute. Never include ToLiss aircraft binaries, Airbus manuals, navigation data, or other proprietary content.
- Version must change for every published update; the updater uses the configured version to detect whether the product needs updating.
- Keep the stable depot path persistent. Do not delete old depot files while users may be updating from them.
- The generated `README.txt` and `changelog.txt` are updater-facing text versions derived from the repository Markdown files.
- The source template is in `config/skunkcrafts_updater_config.template`; the actual config is generated at release time.

## Official references

- [SkunkCrafts Updater — Publishing guide](https://updater.skunkcrafts.com/PUBLISHING.html) — depot format, configuration keys, CRC32 / sizes lists, beta configuration and FlyWithLua folder support.
- [SkunkCrafts Updater 4 — X-Plane.org release thread](https://forums.x-plane.org/forums/topic/352063-skunkcrafts-updater-4-latest-4212-20261103/) — client release information.
