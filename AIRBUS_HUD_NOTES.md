# Airbus HUD research notes — XPHUD ToLiss A32X

## Scope

This project was compared against Airbus public technical material, primarily FAST 46 (2010), “Head-Up Display System — Enhanced Operations' Situational Awareness”, pp. 25–30, and FAST 56 (2016), “The evolving Airbus HUD offer”. These are public Airbus technical-magazine articles, not a substitute for the aircraft's approved FCOM, FCTM, QRH, HUD supplement or operational procedures.

## Symbology described by Airbus FAST 46

The core attitude / energy group is described as:

- Aircraft attitude: pitch, roll, sideslip and heading.
- Flight Path Vector (FPV), also called the bird; it represents actual trajectory using FPA and drift.
- Total FPA / total-energy chevrons, indicating energy state and acceleration / deceleration.
- Speed-delta cue adjacent to the FPV.

For approach, the article describes conformal trajectory cues superimposed on the outside scene:

- The angle between the LOC axis and the horizon indicates lateral position relative to the runway centreline.
- The Approach Reference Flight Path symbol relative to the touchdown point indicates vertical position relative to the ideal approach path.
- Natural perspective rules apply to the illustrations.

The same article describes different display modes for taxi, take-off, climb / cruise / descent, approach and roll-out, with declutter levels to preserve the outside view.

## Current implementation mapping

| Airbus concept | XPHUD v2.3.0 status |
|---|---|
| Pitch / roll / attitude ladder | Approximation implemented |
| FPV / bird and drift | Implemented using ToLiss PFD outputs when available, otherwise X-Plane inertial velocity |
| Heading / track reference | Implemented as a 2D scale; TRK mode uses estimated magnetic ground track |
| Flight director / FPD | Simplified FD cue only; not verified as the exact Airbus HUD FPD symbology |
| Speed / altitude / FMA | PFD-like supporting symbology implemented |
| LOC / G/S deviations | Raw deviation-dot scales implemented; source selectable |
| ILS course reference | Added as a 2D course marker, numeric readout and CRS–TRK angular difference; situational reference only |
| Selected heading bug | Reads the X-Plane magnetic heading dial by default; ToLiss source remains selectable and diagnostics show the difference |
| Total FPA / energy chevrons | Not implemented |
| Speed-delta symbol next to FPV | Not implemented as the Airbus-specific cue |
| Perspective LOC / F-LOC axis | Not implemented |
| Synthetic runway / aiming point / touchdown point | Not implemented |
| Final Approach FPA / approach reference path | Not implemented |
| Phase-adaptive display / declutter | Not implemented |
| Optical collimation / boresight / eye-point geometry | Not possible with the current screen-space 2D overlay |

## Why the approach geometry is deferred

A proper conformal runway and approach-reference display needs a trustworthy runway threshold / localizer geometry, approach course and vertical path, receiver / FMS source selection, aircraft position and a projection tied to the pilot eye point. Merely drawing a course line from the selected ILS course or stretching a deviation bar would look convincing but would not reproduce the geometry described by Airbus.

The public ToLiss dataref name inventories are useful for identifying available names, but do not document the units / semantics of every relevant ILS and selected-heading value. The script therefore exposes source selection, gain / sign calibration and diagnostics instead of silently inventing conversions. Auto heading selection prefers X-Plane's documented magnetic heading dial; the ToLiss value remains available for comparison and fallback.

## Additional Airbus FAST 56 context

FAST 56 describes the A320 Family L5 HUD standard, certified in February 2015, and lists integration with functions such as ROPS, RNP AR, AP/FD TCAS, advisory runway-ahead, soft go-around and BUSS. These certified aircraft-level functions are outside the scope of this FlyWithLua drawing overlay.

## References

- Airbus FAST 46 (2010): https://aircraft.airbus.com/sites/g/files/jlcbta126/files/2022-04/FAST46.pdf
- Airbus FAST 56 (August 2015): https://aircraft.airbus.com/sites/g/files/jlcbta126/files/2022-04/FAST56.pdf
- X-Plane Developer — Autopilot navigation source reference: https://developer.x-plane.com/article/autopilot-navigation-source-reference/
- X-Plane Developer — Accessing the X-Plane autopilot from datarefs: https://developer.x-plane.com/article/accessing-the-x-plane-autopilot-from-datarefs/
- Community ToLiss dataref name inventory (not an official specification): https://github.com/dualznz/toliss-a430-datarefs
