# XPHUD ToLiss A32X — DataRef audit (initial static pass)

**Status:** preliminary source/name inventory; not a simulator-verified contract.  
**Code baseline:** `main`, XPHUD v2.2.0, reviewed 2026-11-07.  
**Scope:** normal 2D FlyWithLua edition only. No 3D/SDK prototype.

> This document deliberately separates evidence that a path exists from evidence about its type, units, sign, validity and operational meaning. A name in a community list is not proof of a complete data contract. Unknown items remain **UNKNOWN — TEST REQUIRED**.

## 1. Evidence and confidence

| Evidence | What it supports | What it does not support |
|---|---|---|
| [ToLiss A321 dataref/command community thread](https://forums.x-plane.org/forums/topic/259651-a321-dataref-and-commands-list/) | Community-reported names, including many `AirbusFBW/*` and `toliss_airbus/pfdoutputs/*` paths | Official status, current A320neo build compatibility, XPLM type, unit, sign, enum values, validity, update rate |
| ToLiss A320neo Aircraft Manual v1.0 (2023), Simulation Manual v1.1 (Nov 2024), Tutorial v1.1 (Nov 2024), supplied for this project | Aircraft/system behaviour and simulator procedures described in those manuals | A formal DataRef specification; types and semantics for the paths below |
| [X-Plane DataRefs browser](https://developer.x-plane.com/datarefs/) and [XPLMDataAccess](https://developer.x-plane.com/sdk/XPLMDataAccess/) | X-Plane-owned DataRef definitions and SDK access model | ToLiss plugin definitions |
| [XPLMDataTypeID](https://developer.x-plane.com/sdk/XPLMDataTypeID/) and [XPLMGetDataRefTypes](https://developer.x-plane.com/sdk/XPLMGetDataRefTypes/) | Type-mask values and runtime type introspection | Units or semantic correctness |
| [Moving the Plane — X-Plane Developer](https://developer.x-plane.com/article/movingtheplane/) | `local_vx/vy/vz` are world-coordinate velocity components in m/s | Validation of the HUD's complete track/FPA implementation |

**Confidence labels used here:**  
- **Name-listed:** path appears in the community inventory or is a standard X-Plane path.
- **XP-documented:** unit/meaning is supported by X-Plane documentation or its DataRef catalogue.
- **Runtime-pending:** actual type mask and live value behaviour still need capture on the user's installed simulator.
- **Unknown:** unit, sign, enum, range, validity or source semantics are not established.

## 2. Current input inventory

The following is the complete set of entries in the current `INPUTS` table in `xphud_toliss_a32x.lua`. Alternative paths are shown in lookup order. `T` and `X` in the current HUD diagnostics mean ToLiss and X-Plane respectively; they do not certify the selected source.

| HUD key | ToLiss path(s) | X-Plane fallback | Current audit status |
|---|---|---|---|
| `ias` | `AirbusFBW/IASCapt` | `sim/cockpit2/gauges/indicators/airspeed_kts_pilot` | ToLiss unit/type pending; XP fallback documented as pilot IAS, kt |
| `mach` | `AirbusFBW/MachCapt` | `sim/flightmodel/misc/machno` | ToLiss type/unit pending; XP Mach ratio/type runtime-pending |
| `show_mach` | `AirbusFBW/ShowMachCapt` | — | Name-listed; enum/boolean meaning and type unknown |
| `alt` | `AirbusFBW/ALTCapt` | `sim/cockpit2/gauges/indicators/altitude_ft_pilot` | ToLiss type/unit pending; XP fallback documented as indicated altitude, ft |
| `hdg` | `AirbusFBW/HDGCapt` | `sim/flightmodel/position/mag_psi` | ToLiss reference/unit pending; XP fallback magnetic heading, degrees |
| `pitch` | `toliss_airbus/pfdoutputs/captain/pitch_angle` | `sim/flightmodel/position/theta` | ToLiss sign/frame/type pending; XP theta documented in degrees, OpenGL/body reference |
| `roll` | `toliss_airbus/pfdoutputs/captain/roll_angle` | `sim/flightmodel/position/phi` | ToLiss sign/frame/type pending; XP phi documented in degrees |
| `vs` | `toliss_airbus/pfdoutputs/captain/vertical_speed` | `sim/flightmodel/position/vh_ind_fpm` | ToLiss unit/sign/type pending; XP fallback documented as ft/min |
| `fpa` | `toliss_airbus/pfdoutputs/captain/flight_path_angle` | — | Name-listed; unit, sign, true/magnetic reference and validity unknown |
| `drift` | `toliss_airbus/pfdoutputs/captain/drift_angle` | — | Name-listed; definition, sign and true/magnetic reference unknown |
| `ias_trend` | `AirbusFBW/IASTrendCapt` | — | Code comment assumes kt/10 s; **unverified** |
| `ias_acc` | — | `sim/cockpit2/gauges/indicators/airspeed_acceleration_kts_sec_pilot` | XP fallback documented as kt/s |
| `v_ias` | `AirbusFBW/CaptIASValid` | — | Name-listed; type, polarity and validity semantics unknown |
| `v_alt` | `AirbusFBW/CaptALTValid` | — | Name-listed; type, polarity and validity semantics unknown |
| `v_att` | `AirbusFBW/CaptATTValid` | — | Name-listed; type, polarity and validity semantics unknown |
| `v_hdg` | `AirbusFBW/CaptHDGValid` | — | Name-listed; type, polarity and validity semantics unknown |
| `vls` | `toliss_airbus/pfdoutputs/general/VLS_value`, then `AirbusFBW/VLS` | — | Name-listed; expected kt inferred from display role, not confirmed |
| `vmax` | `toliss_airbus/pfdoutputs/general/VMax_value`, then `AirbusFBW/VMO` | — | Name-listed; expected kt inferred from display role, not confirmed |
| `vaprot` | `toliss_airbus/pfdoutputs/general/VAProt_value` | — | Name-listed; unit/range/type unknown |
| `valpha` | `toliss_airbus/pfdoutputs/general/VAlphaMax_value`, then `toliss_airbus/pfdoutputs/general/VSW_value` | — | Two different named values used as alternatives; equivalence must be verified |
| `vgd` | `toliss_airbus/pfdoutputs/general/VGreenDot_value`, then `AirbusFBW/VGreenDot` | — | Name-listed; expected kt inferred, not confirmed |
| `show_to` | `toliss_airbus/pfdoutputs/general/show_to_speeds` | — | Name-listed; type/enum/meaning unknown |
| `v1` | `toliss_airbus/performance/V1` | — | Name-listed; unit/type/availability by aircraft variant unknown |
| `vr` | `toliss_airbus/pfdoutputs/general/VR_value`, then `toliss_airbus/performance/VR` | — | Name-listed; unit/type/availability by variant unknown |
| `spd_tgt` | `toliss_airbus/pfdoutputs/general/ap_speed_value` | — | Code comment says kt or Mach if below 2; unverified |
| `spd_man` | `AirbusFBW/SPDmanaged` | — | Name-listed; boolean/enum semantics unknown |
| `spd_dash` | `AirbusFBW/SPDdashed` | — | Name-listed; boolean/enum semantics unknown |
| `alt_tgt` | `toliss_airbus/pfdoutputs/general/ap_alt_target_value` | — | Code comment assumes ft; unverified |
| `hdg_sel_t` | `AirbusFBW/APHDG_Capt` | — | Name-listed; heading vs track, unit and reference unknown |
| `hdg_sel_x` | — | `sim/cockpit2/autopilot/heading_dial_deg_mag_pilot` | XP standard magnetic heading dial; runtime coupling to ToLiss FCU not verified |
| `hdg_man` | `AirbusFBW/HDGmanaged` | — | Name-listed; type/enum semantics unknown |
| `hdg_dash` | `AirbusFBW/HDGdashed` | — | Name-listed; type/enum semantics unknown |
| `hdg_trk` | `AirbusFBW/HDGTRKmode` | — | Name-listed; enum values unknown; code currently assumes numeric 1 = TRK |
| `fd1` | `AirbusFBW/FD1Engage` | — | Name-listed; type/polarity/engagement semantics unknown |
| `fd_pitch` | `toliss_airbus/pfdoutputs/general/fd1_pitch_cmd` | — | Name-listed; code assumes relative degrees; unit/reference/sign unknown |
| `fd_roll` | `toliss_airbus/pfdoutputs/general/fd1_roll_cmd` | — | Name-listed; code assumes relative degrees; unit/reference/sign unknown |
| `ap1` | `AirbusFBW/AP1Engage` | — | Name-listed; type/polarity/semantics unknown |
| `ap2` | `AirbusFBW/AP2Engage` | — | Name-listed; type/polarity/semantics unknown |
| `athr` | `AirbusFBW/ATHRmode` | — | Name-listed; enum values and meaning unknown |
| `ils_on_t` | `AirbusFBW/ILSonCapt` | — | Name-listed; receiver/source relationship and validity semantics unknown |
| `ils_crs_t` | `AirbusFBW/ILSCrs` | — | Name-listed; front course vs selected course, degrees true/magnetic and receiver unknown |
| `loc_on_t` | `AirbusFBW/LOConCapt` | — | Name-listed; meaning/polarity/receiver unknown |
| `loc_val_t` | `AirbusFBW/LOCvalCapt` | — | Name-listed; code assumes dots; unit, sign, scale and saturation unknown |
| `gs_on_t` | `AirbusFBW/GSonCapt` | — | Name-listed; meaning/polarity/receiver unknown |
| `gs_val_t` | `AirbusFBW/GSvalCapt` | — | Name-listed; code assumes dots; unit, sign, scale and saturation unknown |
| `loc_on_x` | — | `sim/cockpit2/radios/indicators/hsi_display_horizontal_pilot` | XP HSI display flag; exact type/semantics runtime-pending |
| `loc_val_x` | — | `sim/cockpit2/radios/indicators/hsi_hdef_dots_pilot` | XP HSI lateral deviation in dots; receiver/source coupling still to verify |
| `gs_on_x` | — | `sim/cockpit2/radios/indicators/hsi_display_vertical_pilot` | XP HSI display flag; exact type/semantics runtime-pending |
| `gs_val_x` | — | `sim/cockpit2/radios/indicators/hsi_vdef_dots_pilot` | XP HSI vertical deviation in dots; receiver/source coupling still to verify |
| `hdg_rel_trk` | `AirbusFBW/APHDGreltoTRK` | — | Name-listed; meaning, unit, sign and mode relationship unknown |
| `ralt` | — | `sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot` | XP fallback expected ft; runtime/type/range check pending |
| `ralt_amber` | `toliss_airbus/pfdoutputs/captain/ralt_is_amber` | — | Name-listed; type/polarity/amber threshold semantics unknown |
| `dh` | `toliss_airbus/performance/DH` | — | Name-listed; unit and selected-vs-displayed decision-height meaning unknown |
| `baro_std` | `AirbusFBW/BaroStdCapt` | — | Name-listed; type/polarity/meaning unknown |
| `baro_unit` | `AirbusFBW/BaroUnitCapt` | — | Code comment assumes 1 = inHg; unverified |
| `baro_hg` | — | `sim/cockpit2/gauges/actuators/barometer_setting_in_hg_pilot` | XP fallback in inHg by path; type/runtime check pending |
| `slip` | — | `sim/cockpit2/gauges/indicators/slip_deg` | XP slip indicator deflection in degrees; not automatically equivalent to aircraft beta |
| `gs_kt` | — | `sim/cockpit2/gauges/indicators/ground_speed_kt` | XP fallback in kt by path; type/runtime check pending |
| `gear` | `AirbusFBW/GearLever` | `sim/cockpit/switches/gear_handle_status` | ToLiss enum unknown; XP handle status is not necessarily actual gear position |
| `flap_lvr` | `AirbusFBW/FlapRequestPos` | — | Code comment assumes 0..4; enum/position semantics unverified |
| `flap_rat` | — | `sim/cockpit2/controls/flap_handle_deploy_ratio` | XP ratio; range/type and mapping to ToLiss detents pending |
| `agl` | — | `sim/flightmodel/position/y_agl` | XP AGL in metres; convert before ft display/use |
| `psi_true` | — | `sim/flightmodel/position/psi` | XP true heading in degrees; coordinate convention must be respected |
| `vx` | — | `sim/flightmodel/position/local_vx` | XP world-coordinate east velocity, m/s |
| `vy` | — | `sim/flightmodel/position/local_vy` | XP world-coordinate vertical velocity, m/s |
| `vz` | — | `sim/flightmodel/position/local_vz` | XP world-coordinate north/south velocity component, m/s; sign convention to verify against OpenGL axes |
| `view_ext` | — | `sim/graphics/view/view_is_external` | XP external-view flag; type/polarity runtime-pending |
| `running` | — | `sim/time/total_running_time_sec` | XP running-time seconds; type/runtime check pending |

## 2.1 Additional string DataRefs used by the FMA

The FMA reader constructs nine string paths dynamically; these are not part of the numeric `INPUTS` table and must be audited separately:

| Group | Paths | Current audit status |
|---|---|---|
| FMA row 1 | `AirbusFBW/FMA1g`, `AirbusFBW/FMA1w`, `AirbusFBW/FMA1b` | Community name inventory includes the FMA family; string type, layer meaning, encoding and update behaviour require runtime verification |
| FMA row 2 | `AirbusFBW/FMA2b`, `AirbusFBW/FMA2m`, `AirbusFBW/FMA2w` | Same; exact colour-layer semantics are currently merged by the HUD |
| FMA row 3 | `AirbusFBW/FMA3a`, `AirbusFBW/FMA3b`, `AirbusFBW/FMA3w` | Same; exact colour-layer semantics are currently merged by the HUD |

These paths are bound through FlyWithLua's string `dataref(..., "readonly")` mechanism, not the scalar XPLM getter path. The current code strips non-printable/non-ASCII characters and merges layers; this is a presentation decision, not proof that the source layers are semantically interchangeable.

## 3. Important code-level findings from this pass

1. **A numeric zero is currently accepted as a successful read.** This is correct for legitimate values such as zero deviation, zero pitch or zero vertical speed, but it also means an orphaned/disabled provider returning zero can look like live data.
2. **Resolved handles are cached indefinitely.** `ref()` retries only paths that were not found. It does not re-resolve a handle after the provider has been disabled/reloaded. X-Plane documents that orphaned datarefs can remain addressable and read as zero. Aircraft/plugin lifecycle and stale-data detection are therefore a P0 issue, not just a theoretical concern.
3. **Type introspection is compatibility selection, not contract validation.** `scalar_reader()` chooses the first supported scalar type in the mask (float, double, int). The code does not yet compare the actual type against an expected per-input type because no expected-type map exists.
4. **Fallback is based on nil, not validity/freshness.** If a ToLiss read returns a numeric zero, X-Plane fallback is not considered. This prevents accidental cross-source mixing in some cases, but cannot distinguish a legitimate zero from an orphaned or stale provider.
5. **ILS source selection is not receiver-complete.** Deviation source, `ILSonCapt`, course, tuned frequency and ident are not yet represented as one resolved receiver contract. The current code can draw an ILS course from ToLiss while the selected deviation values come from X-Plane.
6. **The current diagnostics only show values and T/X source labels.** They do not expose actual resolved path, type, unit, validity state or age.

No code behaviour has been changed in this audit pass.

## 4. Required simulator capture

For each supported aircraft variant/build, capture a diagnostic snapshot in these states:

- Cold load before the ToLiss plugin has fully initialised.
- Normal powered/IRS-aligned state on the ground.
- Electrical power removed / aircraft systems off.
- Each relevant PFD invalid flag changing state, if safely reproducible.
- NAV receiver switched between NAV1/NAV2/FMS and ILS tuned/untuned.
- LOC and G/S centred, then displaced both directions.
- HDG mode and TRK mode with selected target changes.
- Aircraft reload and ToLiss plugin reload if supported without restarting X-Plane.

For each capture record: X-Plane version/build, ToLiss aircraft variant and exact aircraft version, engine variant, FlyWithLua version, dataref path, XPLM type mask, raw value, PFD/FCU reference value, source/receiver and test condition. Do not infer units from a plausible-looking number.

## 5. Next implementation order

1. Add a declarative metadata map with expected types/units only where evidence exists; unknowns remain explicit.
2. Add a diagnostic mode that prints path, type mask, raw value and selected source.
3. Design freshness/lifecycle handling without treating legitimate zero as invalid.
4. Resolve a complete captain-side ILS receiver/source/course/frequency/ident contract.
5. Only after simulator captures, update FPV, FD, heading/track or ILS calculations.

## 6. Outstanding user/environment detail

The exact installed ToLiss A320neo aircraft version/build has not yet been supplied. Until it is known, this audit must not claim compatibility with a specific current ToLiss build. The community list is A321-oriented and dates from 2022; the supplied manuals describe the A320neo but are not DataRef specifications.
