# Changelog

## Unreleased

- Read scalar datarefs with a getter selected from X-Plane's reported type; skip and report unsupported types instead of silently treating a mismatched read as zero.
- Validate loaded preferences against supported boolean, enum and numeric values, and report load/save failures in the FlyWithLua log.

## 2.3.0 — Overhead-unit hardware and eye distance

- Rebuilt the 2D combiner hardware. The glareshield-mounted shoe and struts are gone: an overhead unit (underside with projector window, rear face with vents and identification plate) now sits above the pilot, and the combiner hangs from a hinge bar with pivot blocks, side and lower frame rails and a latch tab. Parts are drawn through a small pinhole model, so the glass is a slight trapezoid whose convergence grows as the combiner gets closer.
- Replaced **Mount stand-off** with **Eye distance (visual cm)**, 45–120, default 70. It scales glass, symbology and hardware together; the default sits further from the pilot's face than before. A saved `size` is kept, so the HUD draws about 14 % smaller at the default distance.
- Deploy / stow now swings the combiner down on its hinge, then fades the symbology in. Hardware and glass are no longer dimmed by the symbology brightness control, and the projector window glows only while data is valid.
- Added a calibration pattern (settings checkbox, not saved): level horizon, bank scale, boresight and glass outline, drawn with the live symbol code.
- Preferences are now versioned (`prefs_version`) with a migration step, written atomically and ended with a marker so interrupted writes are recognised. Migration removes `mount_standoff_cm` and moves the old default hardware opacity (0.72) to the new default (0.92).
- All bearing wraps now use one `wrap180()` / `wrap360()` pair.
- Added an offline Lua test harness (`tests/lua/`) with a FlyWithLua mock, an SVG renderer and 400+ checks, run in CI, and `tools/preview_hud.py` to render a PNG preview without the simulator.

## 2.2.0 — ILS / heading refinement

- Moved the G/S deviation scale inboard to avoid collision with the altitude tape.
- Added selectable ILS deviation source (`auto`, `toliss`, `xplane`) and a display-only gain control so ToLiss and stock X-Plane deviation values can be compared against the PFD.
- Kept LOC and G/S deviation values from the same selected source rather than mixing receivers.
- Added the ToLiss ILS active flag and front-course dataref to the display / diagnostic layer, plus a `CRS - TRK` angular difference readout when groundspeed permits a track estimate.
- Added an ILS course reference marker on the heading / track scale and a numeric front-course readout when available.
- Moved the heading / track scale to the horizon line by default, following the public Airbus A320/A321 HUD technique description; in TRK mode it is centred on the estimated magnetic ground track using drift.
- Added selectable heading-target source (`auto`, `toliss`, `xplane`), a small display offset for calibration, diagnostics for both target sources plus `APHDGreltoTRK`, and a wrapped `HDG T-X` source-difference readout.
- Changed `auto` heading-target priority to the documented X-Plane magnetic heading dial, retaining ToLiss as fallback, to avoid relying by default on an undocumented ToLiss target reference.
- Corrected forced `toliss` ILS source selection so it remains selectable even when the ToLiss LOC / G/S validity flags are currently false.
- Documented the distinction between this screen-space overlay, Airbus conformal approach guidance and later certified HUD functions. Added public Airbus / X-Plane reference links.

## 2.1.0 — Combiner and data-availability improvements

- Changed SPD / ALT / ATT / HDG flag logic to use availability of the corresponding numeric datarefs rather than relying on the ToLiss `Capt*Valid` flags alone.
- Added an optional translucent combiner treatment with clipped corners, a restrained glass tint, perimeter edge, bevel and faint highlight.
- Added separate settings for combiner visibility, tint opacity and edge opacity.
- Renamed the HUD intensity control to **Symbology brightness** to clarify that FlyWithLua bitmap-font text is brightened / dimmed rather than alpha-blended.
- Increased padding around text plates and instrument readout boxes.
- Set an explicit X-Plane 2D graphics state with alpha testing disabled and alpha blending enabled before drawing the HUD.
- Added attribution to Control_TWR while retaining upstream xbard attribution and the original MIT licence.

## 2.0.0 — ToLiss A32X adaptation baseline

- Airbus A319 / A320 / A321-oriented HUD profile based on XPHUD for FlyWithLua v2.0.0.
- Removed the upstream helicopter, weapons / combat and force-trim feature sets from this airliner-focused edition.
- Renamed commands, globals, shared dataref and preferences file to avoid conflicts with the upstream XPHUD script.
