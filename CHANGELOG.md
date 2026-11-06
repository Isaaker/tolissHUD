# Changelog

## Unreleased

- Read scalar datarefs with a getter selected from X-Plane's reported type; skip and report unsupported types instead of silently treating a mismatched read as zero.
- Validate loaded preferences against supported boolean, enum and numeric values, and report load/save failures in the FlyWithLua log.

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
