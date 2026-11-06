# XPHUD — ToLiss A32X Edition

**Version 2.2.0** · Maintained by **Control_TWR**  
An unofficial Airbus-inspired head-up display for **ToLiss A319 / A320 / A321** aircraft in **X-Plane 12**, implemented as a FlyWithLua script.

This edition is derived from **XPHUD for FlyWithLua v2.0.0 by xbard**. It is an independent community modification and is not affiliated with, endorsed by, or supported by xbard, XPConnect, ToLiss, Airbus, or Laminar Research.

## Features

The script draws a single-colour green HUD overlay using FlyWithLua's 2D drawing callback. It reads ToLiss datarefs when available and uses selected stock X-Plane datarefs as fallbacks.

Current symbology includes:

- Flight Mode Annunciator (FMA) text.
- IAS and altitude tapes, selected targets, speed limits, V-speeds and speed trend.
- Pitch ladder, horizon, bank scale, sideslip cue and flight-path vector (FPV / bird).
- Simplified flight-director cue.
- Heading / track scale, selected heading bug and drift reference.
- ILS localizer and glideslope raw-deviation scales, plus an ILS front-course reference on the heading scale.
- Radio altitude, vertical speed, Mach, ground speed and barometric setting.
- Adjustable translucent combiner pane, edge and bevel.
- Optional dataref diagnostics and data-unavailable flags.

The upstream-derived `modern` and `classic` palettes are retained, but the default is the Airbus-style green theme.

## Installation

1. Install **FlyWithLua NG+ for X-Plane 12**.
2. Copy `xphud_toliss_a32x.lua` into:

   `X-Plane 12/Resources/plugins/FlyWithLua/Scripts/`

3. Start X-Plane, or reload Lua scripts from **Plugins → FlyWithLua → Reload all Lua scripts**.
4. Load a supported ToLiss A319, A320 or A321 and open **Plugins → FlyWithLua → Macros → XPHUD A32X: settings window**.

The script does not include ToLiss aircraft files, custom aircraft code, or proprietary aircraft material. A separately installed, licensed copy of the aircraft is required.

## Controls

FlyWithLua macros:

- **XPHUD A32X: toggle HUD** — show or hide the overlay.
- **XPHUD A32X: settings window** — open the configuration panel.

Commands for keyboard / joystick assignment:

| Command | Action |
|---|---|
| `XPHUD_A32X/Toggle` | Show / hide the HUD |
| `XPHUD_A32X/Settings` | Open settings |
| `XPHUD_A32X/Center` | Reset the HUD anchor to the screen centre |

The shared dataref `XPHUD_A32X/Visible` is an integer dataref that can be read or written by other scripts to control HUD visibility.

Settings are saved automatically to `Output/preferences/xphud_toliss_a32x.prefs`.
Loaded preference values are checked against the supported ranges and options; invalid values are reported in the FlyWithLua log and safely reset or clamped.

Scalar datarefs are read using the type reported by X-Plane (`int`, `float` or `double`). FlyWithLua builds that do not expose `XPLMGetDataRefTypes` are reported in the log and will not feed untyped scalar values to the HUD.

## Display and combiner calibration

The HUD is a **screen-space overlay**, not a 3D cockpit object. Its default anchor is the screen centre. Cockpit viewpoint, field of view, monitor aspect ratio, seat position and user eye point differ, so there is no universal pixel offset that is correct for every setup.

Use the settings panel to adjust:

- **HUD size px**, **X offset px** and **Y offset px** to position and scale the overlay.
- **Glass combiner / edge**, **Glass tint opacity** and **Glass edge opacity** to change the pane treatment.
- **Symbology brightness**, **Line width px** and **Text size** to tune the symbols.
- **Readout box shading** to add a dark backing behind labels and numbers.

The combiner is a visual approximation: faint tint, clipped corners, perimeter, bevel and highlight. It does not simulate a physical optical combiner, collimation, parallax, eye tracking, electronic boresighting or the real HUD's optical infinity.

FlyWithLua's bitmap-font drawing functions do not expose glyph alpha like the primitive drawing API. **Symbology brightness** therefore changes font brightness, while glass opacity changes the actual transparency of the pane and edge primitives.

## Heading and track calibration

The heading / track scale is drawn on the artificial horizon by default. In ToLiss TRK mode, the scale is centred on estimated magnetic ground track (`magnetic heading + drift`) rather than magnetic heading. The track / heading reference diamond is retained so the difference is visible.

The selected target can be read from either:

- X-Plane `sim/cockpit2/autopilot/heading_dial_deg_mag_pilot` (preferred by `auto`), or
- ToLiss `AirbusFBW/APHDG_Capt`.

Use **HDG target source** to compare `auto`, `xplane` and `toliss` on your aircraft version. `auto` now prefers the stock X-Plane pilot heading dial because its documented reference is magnetic degrees; ToLiss remains the fallback when that dataref is unavailable. The public ToLiss dataref inventories confirm the name `APHDG_Capt`, but do not publish a reliable unit / reference definition for every aircraft build. The **HDG target display offset deg** control is only a display calibration, not a correction to the aircraft or autopilot. When diagnostics are enabled and both sources exist, `HDG T-X Δ` shows their wrapped angular difference.

## ILS and interception cues

The LOC and G/S symbols are **raw deviation-dot scales**. They are not a synthetic runway, not a perspective localizer axis, and not the Airbus HUD's approach-reference flight-path / touchdown-point symbology.

Use the following settings to compare and calibrate the source against the ToLiss PFD:

- **ILS deviation source**: `auto` uses ToLiss when its deviation flags are valid, otherwise X-Plane; `toliss` and `xplane` force one source. Forced `toliss` mode uses ToLiss values even when its flags are currently false, while the drawing still hides an axis whose own display flag is false.
- **ILS deviation gain**: scales the raw value for display only (default 1.00).
- **Flip LOC** and **Flip G/S**: reverse a direction if the displayed dot moves opposite to the PFD.

The G/S scale has been moved inboard to avoid the altitude tape. When the ToLiss ILS flag and front course are available, a course diamond is added to the heading / track scale and the numeric ILS course is shown near the bottom of the display. This makes the inbound-course relationship easier to monitor during an intercept. When groundspeed is sufficient, the display also shows `CRS - TRK`, the wrapped angular difference between the ILS front course and estimated magnetic ground track. This is an angular reference only: it is **not** a lateral intercept solution, intercept director or capture prediction.

If the ILS cues do not agree with the PFD, turn on **Dataref readout** and compare `loc_val_t`, `gs_val_t`, `loc_val_x`, `gs_val_x`, their respective enable flags, and `ils_crs`. Test one source at a time before changing gain or sign. The ToLiss ILS dataref names are independently visible in community inventories / legacy XHSI source, but their units are not defined there; the default gain is therefore a starting point, not a verified conversion. Do not compensate for a wrong source by applying an arbitrary gain or offset until the raw values have been compared.

## Data availability and yellow flags

The SPD, ALT, ATT and HDG caution tags are based on whether the corresponding numeric values are actually available to the script:

- SPD: IAS value available.
- ALT: altitude value available.
- ATT: both pitch and roll values available.
- HDG: heading value available.

Some ToLiss builds may expose `AirbusFBW/Capt*Valid` flags as zero or intermittently changing while the numeric PFD values continue to update. This edition does not rely on those flags alone to suppress instruments or trigger caution tags. A tag appears when the corresponding numeric source is unavailable.

This is a data-availability indication, not a certified representation of ADR / IR failure logic. It must not be used for real-world operational decisions.

## What is and is not an Airbus HUD simulation

The public Airbus technical article in **FAST 46** describes the HUD's core attitude / energy set as aircraft attitude, FPV (bird), Total FPA energy chevrons and speed-delta cue. It also describes conformal approach guidance: the LOC-axis line in perspective and an approach-reference flight-path symbol relative to the touchdown point. Airbus describes phase-specific presentation and declutter concepts as well.

This project currently approximates part of the primary display mode: attitude / pitch ladder, FPV, a simplified FD cue, speed and altitude information, FMA, heading / track and raw LOC / G/S deviations. It does **not** yet implement:

- Airbus Total FPA / total-energy chevrons or the dedicated speed-delta symbol.
- The perspective LOC / F-LOC axis, synthetic runway, runway aiming point or touchdown point.
- A true Airbus HUD Flight Path Director (FPD) and final-approach FPA reference.
- Automatic phase-dependent symbology sets / certified declutter logic.
- Certified HUD optical alignment, collimation, field-of-view geometry or boresight calibration.
- The complete feature set of later Airbus HUD standards (e.g. ROPS, RNP AR, AP/FD TCAS, advisory runway-ahead or soft go-around functions).

These are deliberately listed as limitations rather than being represented by plausible-looking but unverified symbols. Accurate conformal approach cues need consistent runway / navigation geometry, valid approach parameters, and a cockpit-specific eye-point / optical model. The current public ToLiss dataref inventory does not document enough of those semantics to build that accurately yet.

## Diagnostics

Enable **Dataref readout** in the settings panel to show each value and source:

- `T` — ToLiss dataref.
- `X` — stock X-Plane dataref.
- `-` — no source found.

ToLiss datarefs are resolved lazily and retried periodically because the aircraft plugin may create them after the Lua script starts. The diagnostics view now includes both heading-target sources and both ILS deviation source sets so users can compare them without switching tools.

## Compatibility and limitations

- Intended for **X-Plane 12**, **FlyWithLua NG+**, and ToLiss **A319 / A320 / A321** variants whose datarefs match those used by the script.
- No universal compatibility is claimed for the ToLiss A340 or other aircraft. Shared dataref names alone do not guarantee that every value is available or means the same thing.
- Some elements depend on ToLiss-specific datarefs and are omitted when no suitable source exists.
- The overlay is drawn in screen coordinates. It is not a replacement for a native aircraft HUD, PFD, FMA or certified flight instrument.
- This is a community simulation add-on for entertainment / training-environment visualisation only. It is **not approved for real-world flight use**.

When reporting a problem, include your X-Plane version, FlyWithLua version, ToLiss aircraft / engine variant, the selected heading and ILS sources, and a diagnostic readout.

## Credits and licence

This edition is derived from **XPHUD for FlyWithLua v2.0.0** by **xbard** ([xpconnect.me](https://xpconnect.me)). The original upstream README is preserved as [`UPSTREAM_README.md`](UPSTREAM_README.md). The upstream MIT licence text and xbard copyright notice are retained in [`LICENSE`](LICENSE), with an additional copyright notice for Control_TWR’s own ToLiss A32X modifications.

Credits carried over from the upstream project:

- **Steve Hanley** — original HeliHUD concept for Microsoft Flight Simulator 2004 (2003).
- **Petr Medek** — HeliHud (2011), which inspired the HUD lineage.

The ToLiss A32X adaptation, data-availability flag handling, combiner presentation, heading / track improvements, ILS source selection and documentation in this edition are maintained by **Control_TWR**.

The software is provided under the MIT licence. See `LICENSE` for the full terms. All aircraft and simulator trademarks remain the property of their respective owners.


## Repository automation and maintenance

This repository includes GitHub Actions for Lua syntax / tooling CI, secret scanning (Gitleaks), workflow security auditing (zizmor), Dependabot updates, TODO-to-Issue synchronisation, GitHub Releases and the SkunkCrafts production depot. See [`CONTRIBUTING.md`](CONTRIBUTING.md), [`SECURITY.md`](SECURITY.md) and [`SKUNKCRAFTS_UPDATER.md`](SKUNKCRAFTS_UPDATER.md). Follow [`GITHUB_SETUP.md`](GITHUB_SETUP.md) for the initial GitHub settings and first release.

### TODO.md → GitHub Issues

`TODO.md` remains the source of truth. On changes to `TODO.md` pushed to `main`, the workflow creates or updates **one GitHub Issue per numbered `###` subsection containing checkboxes** (not one issue per checkbox). Stable markers prevent duplicates. Completing all checkboxes closes the matching issue; unchecking a task reopens it at the next synchronisation. Orphaned issues are not deleted. A manual workflow run defaults to dry-run; choose `apply: true` to write changes. The initial push of this TODO file to `main` will create 48 Issues for the currently open roadmap sections (the already-completed section is skipped); run the local dry-run command first if you want to inspect the proposed titles and bodies before pushing.

### Releases and SkunkCrafts Updater

`VERSION` must match the Lua header and a stable `vMAJOR.MINOR.PATCH` tag. Pushing the tag runs the release workflow, creates a manual-install ZIP, publishes a GitHub Release, and deploys a static SkunkCrafts depot to GitHub Pages. The product installs as its own `FlyWithLua/Scripts/XPHUD_ToLiss_A32X` folder; per-folder FlyWithLua management requires SkunkCrafts Updater 4.2.7 or newer. Complete the one-time GitHub Pages setup in [`SKUNKCRAFTS_UPDATER.md`](SKUNKCRAFTS_UPDATER.md) before publishing the first tag.

## Experimental native 3D combiner hardware

The repository now contains an experimental, separately installable C++ / X-Plane SDK prototype for an original cockpit-mounted HUD combiner assembly. The native plugin instantiates an original OBJ8 support frame and translucent pane, positions it from aircraft-body coordinates using the X-Plane coordinate transform, and hides it in external views. The procedural model source is in [native/generate_model.py](native/generate_model.py); build and calibration notes are in [native/README.md](native/README.md).

**Important:** this is physical 3D hardware only. The existing FlyWithLua HUD remains a screen-space overlay; its symbols are not projected onto the glass. This OBJ is not an aircraft cockpit object or ATTR_hud_glass display, and does not provide optical collimation. Do not distribute it as a stable release or enable it in the simulator until the native CI build and a live ToLiss cockpit placement test have passed. No ToLiss aircraft files are modified or redistributed.

The native prototype is built separately from the stable Lua-only v2.2.0 package. Its initial configuration is disabled (enabled = 0) and requires manual position/orientation calibration. See [Issue #54](https://github.com/Isaaker/tolissHUD/issues/54) and section 10.4 of [TODO.md](TODO.md).

## Development roadmap

The detailed engineering roadmap, dataref audit tasks, implementation milestones, acceptance criteria and simulator test matrix are maintained in [`TODO.md`](TODO.md). Tasks are prioritised by data integrity and source correctness before advanced HUD symbology.

## References

- [Airbus FAST 46 — “Head-Up Display System: Enhanced Operations’ Situational Awareness” (2010), pp. 25–30](https://aircraft.airbus.com/sites/g/files/jlcbta126/files/2022-04/FAST46.pdf) — primary public Airbus source for the core HUD symbology, FPV / Total FPA, conformal approach symbols, phase presentation and declutter concepts.
- [Airbus FAST 56 — “The evolving Airbus HUD offer” (August 2015)](https://aircraft.airbus.com/sites/g/files/jlcbta126/files/2022-04/FAST56.pdf) — A320 Family L5 HUD standard and examples of later certified capabilities.
- [X-Plane Developer — Autopilot navigation source reference](https://developer.x-plane.com/article/autopilot-navigation-source-reference/) — X-Plane NAV / APR source selection and ILS receiver context.
- [X-Plane Developer — Accessing the X-Plane autopilot from datarefs](https://developer.x-plane.com/article/accessing-the-x-plane-autopilot-from-datarefs/) — autopilot mode / selected magnetic-heading behaviour.
- [Community ToLiss A340 dataref inventory](https://github.com/dualznz/toliss-a430-datarefs) — useful for confirming public dataref names; not an official ToLiss specification and does not establish all units or semantics.
