# XPHUD ToLiss A32X — Technical Roadmap / TODO

**Reviewed baseline:** v2.2.0  
**Maintainer:** Control_TWR  
**Last technical review:** 2026-11-06  
**Target:** X-Plane 12 + FlyWithLua NG+ + ToLiss A319/A320/A321 (ceo/neo where the relevant datarefs are present)

> This file is a development plan for an unofficial simulator add-on. It is not an Airbus design specification, a type-design document, an FCOM/FCTM/QRH supplement, or a source of operational guidance. “Airbus-like” or “Airbus-inspired” means that the display follows concepts described in public Airbus material; it does **not** mean that this script reproduces a certified Airbus HUD.

---

## 0. Project objective and definition of “accurate”

The goal is to make XPHUD as technically faithful as the simulator, aircraft plug-in, public references and rendering architecture permit. Accuracy must be earned in this order:

1. **Correct source:** every value comes from the instrument/system that the symbol claims to represent.
2. **Correct semantics:** units, sign, reference frame, receiver, validity and operating mode are known.
3. **Correct computation:** any derived value is mathematically traceable and tested at edge cases.
4. **Correct symbology:** the symbol has the right meaning, shape, position, movement and decluttering behaviour.
5. **Correct projection:** symbols that claim to be conformal must line up with the outside world through the pilot’s eye point.
6. **Verified behaviour:** the implementation is compared against the ToLiss PFD/ND/FCU/FMA and repeatable X-Plane scenarios.

A convincing-looking symbol with an unknown source, unknown sign or unknown unit is **not** an accurate symbol. Prefer a clearly labelled raw indication or no indication at all over a false guidance cue.

### 0.1 Accuracy levels used in this roadmap

| Level | Meaning | Permitted wording in the UI/docs |
|---|---|---|
| **A — verified source** | Dataref, type, units, sign, source and mode checked against official SDK documentation or live aircraft behaviour | “ToLiss PFD value”, “X-Plane NAV1 LOC deviation”, etc. |
| **B — verified computation** | Derived from Level A inputs; formulas and sign conventions tested | “Estimated magnetic track”, “calculated energy trend” |
| **C — visual approximation** | Shape/layout inspired by public Airbus HUD descriptions, but exact Airbus implementation is not public or not reproduced | “HUD-style”, “Airbus-inspired” |
| **D — unavailable / out of scope** | Requires proprietary, certified, unexposed or unvalidated data / hardware | Hide it; do not fabricate it |

Do not promote a feature from C to A/B just because it looks right in one screenshot.

### 0.2 Hard design rules

- [ ] Keep the script **read-only** with respect to aircraft, autopilot, flight controls and navigation radios. XPHUD must not write ToLiss or X-Plane flight-system datarefs.
- [ ] Never command the autopilot, arm/capture an approach, tune a radio, change an HSI source or alter flight controls.
- [ ] Never invent a failure, warning, capture, flare, rollout or runway-clearance state.
- [ ] Do not display a guidance cue when its source is missing, stale, invalid, ambiguous or from a different receiver than the displayed course.
- [ ] Keep raw values available in diagnostics; conversions and display scaling must be separate, visible and documented.
- [ ] Distinguish **HDG**, **TRK**, **LOC**, **G/S**, **F-LOC/F-G/S**, **GPS/FMS path**, **GLS** and other approach sources. Do not call all lateral/vertical deviation “ILS”.
- [ ] No claim of certification, operational suitability, training approval or equivalence to the Airbus HUD.
- [ ] Do not copy Airbus FAST figures, photographs, drawings or substantial text into this repository. Cite and link to the publications; create original project diagrams if needed. FAST 56 includes explicit proprietary / reproduction restrictions.
- [ ] Keep upstream xbard attribution and the original MIT `LICENSE` intact. Make Control_TWR modifications clearly attributable and do not imply endorsement by xbard, ToLiss, Airbus or Laminar Research.

---

## 1. Baseline audit — v2.2.0

The following describes the code as reviewed, not a claim that every item is already validated in the simulator.

### 1.1 Existing implementation

- [x] FlyWithLua 2D draw callback and settings window.
- [x] ToLiss-first scalar dataref lookup with stock X-Plane fallbacks for selected instruments.
- [x] IAS / altitude tapes, target bugs, selected speed / altitude, speed markers and trend-related inputs.
- [x] Pitch ladder, horizon, bank scale, sideslip cue, FPV and simplified FD cue.
- [x] HDG/TRK scale, selected-heading marker, drift diamond and ILS-course marker.
- [x] Raw LOC / G/S deviation dot scales with source, gain and sign controls.
- [x] FMA text extraction from ToLiss string datarefs; monochrome merge of colour layers.
- [x] Radio altitude, VS, Mach, GS and barometric readouts.
- [x] Combiner tint, edge, bevel and user-position / size controls.
- [x] Diagnostics panel and automatic preference persistence.
- [x] Original MIT licence and upstream README retained in the release archive.

### 1.2 Known gaps and code-level risks to address first

- [ ] **Dataref type mismatch risk:** `read_inputs()` currently calls `XPLMGetDataf()` for every scalar input. X-Plane SDK documentation explicitly says dataref types must be known and automatic type conversion is not performed; a type mismatch can return the default zero. Add a typed reader before relying on boolean / integer mode flags. See [XPLMDataAccess — Dataref Types and accessors](https://developer.x-plane.com/sdk/XPLMDataAccess/).
- [ ] **Dataref contract is incomplete:** the `INPUTS` table records names but not expected type, units, reference frame, sign, valid range, aircraft applicability or source authority.
- [ ] **Availability is not freshness:** a cached reference can continue to exist while its provider is disabled/orphaned; X-Plane documents that orphaned datarefs read as zero. “Dataref exists” must not be treated as proof that a live instrument is publishing current data.
- [ ] **ILS state and ILS course are ToLiss-only:** `D.ils_on` and `D.ils_crs` are copied from `AirbusFBW/ILSonCapt` and `AirbusFBW/ILSCrs` only. Selecting the X-Plane deviation source does not currently create a complete X-Plane-derived ILS state/course path.
- [ ] **ILS source selection is not a full receiver model:** the current `use_t = t_loc_ok or t_gs_ok` chooses one source for both axes if either ToLiss axis appears valid. This avoids silently mixing two receivers, but can suppress a valid axis from the other source. The correct fix is to determine the actual captain-side PFD/HSI receiver and use a coherent receiver/source contract—not simply mix values axis by axis.
- [ ] **ILS source and course can disagree:** LOC/G/S deviation selection and `ILS CRS` currently come from different logic paths. Course, deviation, ident, frequency and validity must all refer to the same receiver/approach source.
- [ ] **ILS deviations are still assumed to be dots:** `LOCvalCapt` and `GSvalCapt` are commented as “assumed dots”; units, sign, scale, saturation and flag semantics require live verification. The display-only gain must not conceal an incorrect unit conversion.
- [ ] **X-Plane HSI source is not explicitly resolved:** the code reads the pilot HSI deviations but does not yet read and interpret `sim/cockpit2/radios/actuators/HSI_source_select_pilot` to establish which NAV/FMS source is selected.
- [ ] **Heading source priority is not proven for ToLiss:** `auto` prefers X-Plane’s magnetic heading dial and only falls back to `AirbusFBW/APHDG_Capt`. The X-Plane dial is documented as magnetic degrees, but it must be shown to be the value actually coupled to the ToLiss FCU/AP in this aircraft build before becoming the default for the ToLiss profile.
- [ ] **TRK target semantics remain unresolved:** the script reads `AirbusFBW/APHDGreltoTRK` but currently only exposes it in diagnostics. In TRK mode, the selected FCU target / bug may need to be interpreted as a track target rather than plotted as a heading target. Verify the reference before using this dataref.
- [ ] **TRK mode is detected by an exact numeric comparison:** `(D.hdg_trk or 0) == 1`. Confirm the dataref type and enum values; avoid assuming a boolean representation without auditing it.
- [ ] **Track calculation needs a controlled verification:** X-Plane documents `local_vx`, `local_vy`, `local_vz` as world-coordinate velocity components in m/s, with X movement east. The current `atan2(vx, -vz)` / `psi_true` derivation must be checked with cardinal tracks, crosswind and magnetic variation before it is treated as a verified reference.
- [ ] **FPV source arbitration needs completeness rules:** ToLiss FPA and drift are used together if both exist; otherwise the X-Plane inertial vector is used. Confirm they are same-frame / same-epoch values, define valid ranges and prevent stale partial inputs.
- [ ] **FD cue is an approximation:** `fd_pitch` and `fd_roll` are treated as relative degrees with hand-applied sign switches. Verify units, sign, zero reference and whether they are actual FD commands or another PFD output. Do not describe this as Airbus HUD FPD until verified.
- [ ] **FMA colour semantics are discarded:** the script merges colour layers into one green string. Preserve group position and annunciation priority, but check whether losing colour hides distinctions that matter. Never infer AP/FD capture solely from a parsed text fragment if a validated mode dataref exists.
- [ ] **Text measurement is approximate:** `text_size()` estimates widths using fixed character advances. It needs real measured glyph widths or a reliable per-font table and clipping/fit rules, especially for FMA and long numeric labels.
- [ ] **Settings are loaded without a complete validation/migration layer:** validate enum strings and numeric bounds after reading preferences; handle unknown keys and future versions safely.
- [ ] **Graphics state handling should be isolated:** explicitly set the required state for the callback and restore/document the expected state at exit where supported; verify alpha blending and line widths across X-Plane versions and other plugins.
- [ ] **The combiner frame is decorative, not an optical HUD:** drawing is screen-space and does not provide collimation, eye-point alignment, dynamic head-motion compensation, parallax correction or a real 3D runway projection.

---

## 2. MILESTONE 0 — Data integrity, typed inputs and diagnostics [P0 / BLOCKER]

No new flight guidance symbol should be implemented until this milestone is complete.

### 2.1 Create a formal dataref catalogue

- [ ] Replace the implicit `INPUTS` tuples with a declarative catalogue. Each input record must include:
  - logical key;
  - full dataref path(s), per-aircraft alternative paths if any;
  - provider (`X-Plane`, `ToLiss`, other plugin);
  - expected XPLM type (`int`, `float`, `double`, scalar/array/string);
  - unit (kt, ft, ft/min, degrees, degrees magnetic, degrees true, radians, m/s, ratio, boolean/enum, text);
  - coordinate/reference frame (body, world/local, magnetic, true, pilot-side, copilot-side);
  - sign convention and zero meaning;
  - valid range / invalid sentinel;
  - validity flag and its own semantics;
  - sample/update rate if known;
  - aircraft variants and minimum plugin/build tested;
  - confidence level A/B/C/D and evidence URL or test-log reference.
- [ ] Add a `DATAREF_AUDIT.md` (or a generated section here) listing every active dataref, including those not yet used by a drawing function.
- [ ] Record unknown semantics as `UNKNOWN — TEST REQUIRED`; do not fill them by intuition or names alone.

### 2.2 Implement typed reads

- [ ] Check whether the FlyWithLua runtime exposes `XPLMGetDataRefTypes()` and/or equivalent type introspection. If available, read and validate type masks before binding a reader.
- [ ] Use `XPLMGetDatai()` for integer / enum / boolean references and `XPLMGetDataf()` or `XPLMGetDatad()` for documented float/double scalars.
- [ ] For any array/string dataref, use a supported array/string binding and explicit length handling; never call a scalar float getter for it.
- [ ] If runtime type introspection is not exposed by the Lua API, maintain an audited type map from SDK / ToLiss evidence and fail safe on unexpected values.
- [ ] Add per-source getter wrappers: `read_float`, `read_double`, `read_int`, `read_string`, `read_array` (only if actually needed).
- [ ] Do not convert every value to float and then guess whether it was an integer flag.
- [ ] Verify the `XPLMFindDataRef` / cached-handle lifecycle across aircraft reload, ToLiss plugin reload and X-Plane reload. X-Plane documents orphaned references that return zero while remaining addressable.

### 2.3 Model availability, validity and freshness separately

- [ ] Replace the current single `nil`/non-`nil` concept with explicit states:
  - `MISSING`: path does not resolve;
  - `TYPE_MISMATCH`: actual type is not compatible;
  - `INVALID`: provider's documented validity flag says invalid;
  - `STALE`: data is not changing when a heartbeat / timestamp / known changing field should be changing, or provider has been disabled;
  - `VALID`: finite, in-range and current;
  - `VALID_ZERO`: zero is a legitimate measurement (e.g. zero vertical speed or zero deviation).
- [ ] Never mark a live 0-degree pitch / 0-dot LOC / 0-kt acceleration as invalid merely because its value is zero.
- [ ] Do not treat the existence of a dataref handle as evidence that the publishing plugin is currently alive.
- [ ] Add per-input age / last-change telemetry where possible. If the provider supplies no timestamp, document the weaker freshness test used.
- [ ] Detect aircraft changes and rebuild the active dataref profile when switching ToLiss variant or loading another aircraft.
- [ ] Keep `Capt*Valid` visible in diagnostics as evidence, but do not make it the sole validity criterion until its live behaviour is understood for each variant.
- [ ] Ensure unavailable values do not silently fall through to a stock X-Plane value from a different instrument/source and create a mixed-source picture.

### 2.4 Sampling and internal data model

- [ ] Introduce one immutable **frame snapshot** per draw cycle: raw values, selected sources, validity, timestamps/ages, and derived values are computed once then consumed by drawing functions.
- [ ] Keep raw (`*_raw`), normalized (`*_norm`) and screen-space (`*_px`) values distinct.
- [ ] Centralize conversions: metres↔feet, m/s↔kt, radians↔degrees, true↔magnetic, angle wrapping, sign inversion.
- [ ] Use a single tested `wrap180()` / `wrap360()` implementation for all bearings and courses.
- [ ] Reject NaN, ±infinity, impossible magnitudes and sentinel values before calculations. Record the reason in diagnostics.
- [ ] Do not smooth primary attitude / PFD-like values with arbitrary lag. Apply filtering only to noisy *derived* trends, and document filter time constants.
- [ ] Confirm `read_inputs()` is not doing any expensive lookup or string binding repeatedly after initialization.

### 2.5 Diagnostics and test recording

- [ ] Extend the debug layer to show `value | source | type | unit | valid-state | age` for important inputs.
- [ ] Show the resolved ToLiss/X-Plane source path, not just `T` or `X`.
- [ ] Show the HSI/NAV source selected, receiver 1/2, tuned frequency, decoded ident (when available), ILS/LOC/G/S flags and selected course.
- [ ] Show both ToLiss and X-Plane raw heading targets, wrapped delta, ToLiss HDG/TRK mode and `APHDGreltoTRK`.
- [ ] Add an optional CSV/log capture at a controlled low rate (e.g. 5–10 Hz), disabled by default. Include simulator time and aircraft identity; do not write every draw frame.
- [ ] Add a “copy diagnostic snapshot” action or a plain-text output suitable for posting in a bug report.
- [ ] Make debug output non-overlapping with the actual HUD; provide a separate diagnostics window or a compact mode.

**Acceptance criteria (P0):**

- [ ] Every active dataref has a documented type and unit, or is clearly marked experimental and not used for flight guidance.
- [ ] Type mismatch cannot masquerade as a valid zero measurement.
- [ ] Power-off, alignment, plugin-disabled, dataref-missing, aircraft-switch and normal-flight states are distinguishable.
- [ ] All values displayed in a given instrument group use one coherent source and one consistent snapshot.

---

## 3. MILESTONE 1 — Flight reference, attitude and trajectory [P1]

Airbus FAST 46 describes the HUD attitude/energy group as aircraft attitude (pitch, roll, sideslip and heading), the FPV (“bird”), Total FPA and the speed-delta cue. It describes FPV as actual trajectory using FPA longitudinally and drift laterally. Exact Airbus calibration and symbol implementation are not fully specified in the public article.

### 3.1 Attitude and horizon

- [ ] Verify ToLiss captain pitch/roll datarefs against the ToLiss PFD at level flight, known pitch attitudes and known bank angles.
- [ ] Verify sign conventions: nose-up vs nose-down; right-wing-down vs left-wing-down; screen y direction.
- [ ] Verify ToLiss PFD attitude and X-Plane body attitude have the same reference and timing. Do not mix pitch from one source with roll from another.
- [ ] Calibrate pitch ladder angular spacing against known simulated attitude values; remove the need for a user to guess `ladder_deg` for normal operation.
- [ ] Verify pitch ladder sign, 5°/10° rung intervals, positive/negative rung style and clipping at extreme attitudes.
- [ ] Verify roll arc / pointer / bank angle direction at ±10°, ±30°, ±45° and ±60°.
- [ ] Check sideslip source and scale; distinguish slip angle, beta, and a cockpit slip/skid indicator if the datarefs are not equivalent.
- [ ] Add a ground / low-speed attitude handling rule without suppressing legitimate FPV when stationary tests are being run.

### 3.2 Flight Path Vector (FPV / bird)

- [ ] Confirm whether the ToLiss `captain/flight_path_angle` is degrees, positive-up, and a true flight-path angle relative to the local horizontal.
- [ ] Confirm whether `captain/drift_angle` is the aircraft drift / track-minus-heading angle, its sign convention, and whether it is true- or magnetic-referenced.
- [ ] Confirm ToLiss FPA and drift are updated together and refer to the same captain-side sensor / solution.
- [ ] Validate X-Plane fallback using documented `local_vx`, `local_vy`, `local_vz` in m/s. Its horizontal components are world-coordinate components; test cardinal headings and crosswind.
- [ ] Verify the conversion `FPA = atan2(vertical speed, horizontal groundspeed)` and `track = atan2(east velocity, north velocity)` against X-Plane's own track / path values.
- [ ] Verify true-vs-magnetic conversion. Avoid adding magnetic variation twice or omitting it from one component.
- [ ] Define source arbitration: prefer complete valid ToLiss FPA+drift; otherwise use a complete X-Plane vector; never mix one ToLiss component with one X-Plane component.
- [ ] Add source and validity indication for FPV; hide it when speed / vector magnitude is too small or invalid.
- [ ] Check FPV movement for forward flight, climb, descent, crosswind, sideslip, high bank, high pitch, wind shifts and approach.
- [ ] Verify symbol shape and reference point against the public FAST 46 illustrations; label it FPV, not flight director.
- [ ] Confirm symbol does not clip outside the safe display area and remains geometrically aligned with the pitch ladder.

### 3.3 Total FPA / total-energy chevrons

- [ ] Research the meaning shown in FAST 46: Total FPA / “total energy chevrons” indicate total aircraft energy (potential + kinetic) and acceleration/deceleration status.
- [ ] Do **not** equate Total FPA to vertical speed, IAS trend, or selected-speed error without evidence.
- [ ] Inventory candidate inputs: vertical velocity, true/ground speed, longitudinal acceleration, IAS acceleration / trend, altitude rate, and any native ToLiss energy/total-FPA output.
- [ ] Determine whether ToLiss exposes the actual HUD Total FPA / energy cue or an equivalent value; request official ToLiss dataref semantics if necessary.
- [ ] If no native output exists, design a clearly documented *simulator approximation* from a physically derived total-energy rate. Define assumptions, units, filter, deadband and sign convention before drawing it.
- [ ] Consider the specific-energy relation as a modelling basis only: total mechanical energy per unit mass depends on gravitational height and kinetic speed; validate the chosen conversion to a displayed angular cue instead of assuming a direct angle mapping.
- [ ] Define the visual states for increasing energy, steady energy and decreasing energy from source-backed examples; do not copy Airbus artwork.
- [ ] Add hysteresis / deadband so chevrons do not flicker around zero energy rate.
- [ ] Verify level acceleration, level deceleration, constant-speed level flight, climb with acceleration, climb with deceleration, descent with acceleration and descent with deceleration.
- [ ] Show a diagnostic numeric energy-rate value to make the approximation auditable.
- [ ] Keep the feature disabled by default until sign, scaling and all test cases are validated.

### 3.4 Speed-delta cue

- [ ] Identify the exact meaning and input definition of Airbus’ speed-delta cue from additional public Airbus references or approved user-provided references. FAST 46 identifies its location next to the FPV but does not provide a complete public computation specification.
- [ ] Do not silently substitute `IAS - selected speed`, `IAS trend`, `acceleration`, `VLS margin` or `speed error` for the Airbus cue.
- [ ] If only an approximation is possible, name it explicitly (e.g. `SPEED TREND` or `IAS Δ`) rather than `Airbus speed delta`.
- [ ] Decide whether it should be derived from `IASTrendCapt`, `airspeed_acceleration_kts_sec_pilot`, or an independently measured IAS time derivative. Validate units (`kt`, `kt/10 s`, `kt/s`) first.
- [ ] Define sign, magnitude scaling, deadband, saturation, display location and no-data behaviour.
- [ ] Verify against level acceleration / deceleration and approach speed stabilisation cases.

### 3.5 Flight Director vs Flight Path Director

- [ ] Audit `fd1_pitch_cmd` and `fd1_roll_cmd`: type, units, sign, command/reference frame, scaling, active/armed states and update rate.
- [ ] Compare the cue against ToLiss PFD FD bars and FMA across HDG, NAV, LOC, GS, managed climb/descent and go-around.
- [ ] Verify behaviour with FD1 only, FD2 only, both FDs, no FD and AP on/off.
- [ ] Determine whether the current circle/cross is a valid FD cue, a generic guidance cue or neither.
- [ ] Do not call the existing symbol the Airbus HUD **Flight Path Director / Approach Reference Flight Path**. These are distinct concepts and require separate definitions.
- [ ] Implement exact Airbus-inspired FPD only after its reference data and geometric meaning are established; otherwise keep a clearly named simplified flight-director marker.

**Acceptance criteria (M1):**

- [ ] Pitch/roll and FPV agree with ToLiss PFD / known sim truth within the agreed simulator test tolerance.
- [ ] Crosswind causes a correct, stable drift/track relation.
- [ ] FPV and energy cues do not jump, reverse sign, flicker or remain on screen when their inputs are invalid.
- [ ] No symbol is described as Airbus-exact where public evidence is incomplete.

---

## 4. MILESTONE 2 — Heading, track and FCU target fidelity [P1]

### 4.1 Identify the actual selected target

- [ ] Compare `AirbusFBW/APHDG_Capt` with `sim/cockpit2/autopilot/heading_dial_deg_mag_pilot` while turning the ToLiss FCU knob through 000°, 001°, 090°, 180°, 270°, 359° and wrap-around.
- [ ] Establish whether each value represents selected magnetic heading, selected magnetic track, a relative target, a normalized value or a display value.
- [ ] Establish whether the X-Plane dial is synchronized by ToLiss in every A319/A320/A321 build. If not, do not make it the unconditional `auto` priority for ToLiss aircraft.
- [ ] Verify the sign and meaning of `AirbusFBW/APHDGreltoTRK`; its name alone is not sufficient to infer whether it is relative to track, signed left/right or an absolute target.
- [ ] Capture the source values, FCU displayed target and FMA mode in a diagnostic log during each test.
- [ ] Define source selection in terms of aircraft profile and verified availability, not “first dataref found”.
- [ ] Remove display offset as a normal fix. Keep any offset solely as a clearly labelled last-resort calibration, default zero, and never modify the selected target itself.

### 4.2 Separate heading reference from track reference

- [ ] Define a canonical `mag_heading`, `true_heading`, `mag_track`, `true_track`, `drift_angle` and `selected_lateral_target` structure.
- [ ] Derive magnetic track using one validated magnetic-reference path; do not add a true-referenced course to a magnetic scale.
- [ ] Confirm whether ToLiss `HDGTRKmode` means FCU target mode, PFD reference mode or another mode bit.
- [ ] In HDG mode, plot the selected magnetic heading bug against the magnetic heading scale.
- [ ] In TRK mode, plot the selected magnetic track target against a magnetic track scale; do not plot a heading target against track unless the target has been converted using validated ToLiss data.
- [ ] Use `APHDGreltoTRK` only once its direction, unit and mode applicability are proven.
- [ ] Decide how the current heading marker and selected target marker differ in shape so that the pilot can tell heading from track at a glance.
- [ ] Add HDG/TRK mode label, mode source and target source to diagnostics.

### 4.3 Scale geometry and motion

- [ ] Verify tick spacing in degrees, label cadence, scale width and centring.
- [ ] Ensure shortest-angle wrap is used around 000°/360°.
- [ ] Ensure the selected bug remains correct at 359° relative to a 001° track and vice versa.
- [ ] Verify the scale's relationship to the horizon line under roll and pitch. Do not conflate a compass tape with the attitude ladder.
- [ ] Test heading reference during turns, crosswind, high drift, low groundspeed, high pitch and high bank.
- [ ] Define a safe behaviour when groundspeed is too low to estimate track: show HDG or hide TRK scale instead of generating a noisy track.
- [ ] Check marker clipping: if the selected value is outside the visible scale, use a consistent edge cue / off-scale indicator rather than silently pinning the bug at the edge.

### 4.4 FMA and actual lateral mode

- [ ] Audit ToLiss FMA1/FMA2/FMA3 layer datarefs and `HDGmanaged`, `HDGdashed`, `HDGTRKmode`, AP engagement flags.
- [ ] Determine which FMA text denotes selected HDG, managed NAV, LOC armed, LOC capture, LOC track and go-around; do not infer from the label “HDG” alone.
- [ ] Verify whether a heading target should be displayed in managed NAV / LOC / TRK mode and when it should be dashed, removed or replaced by a path target.
- [ ] Retain the ToLiss FMA as authoritative where it is present and validated; use stock X-Plane AP bit fields only for a deliberately separate generic-aircraft fallback.
- [ ] Never parse a partial FMA string as a guaranteed mode state without checking freshness and full line content.

**Acceptance criteria (M2):**

- [ ] The displayed selected heading/track matches the actual ToLiss FCU target over the full 0–359° range, including wrap-around.
- [ ] The target marker does not run several degrees ahead/behind because of a source, frame or reference mismatch.
- [ ] HDG and TRK modes are unambiguous; wind/drift affects TRK only as defined by the verified mode.
- [ ] No target is displayed from a stale generic X-Plane dataref when the ToLiss FCU is the active source.

---

## 5. MILESTONE 3 — Radio navigation / ILS receiver correctness [P0 for ILS work]

X-Plane's official navigation-source documentation states that the HSI source selector determines the displayed / coupled source; it documents on-side NAV receiver behaviour for ILS, and distinguishes ILS, RNAV/FMS, GLS and LOC/back-course cases. The HUD must follow the actual captain-side source, not whichever dataref happens to be non-zero.

### 5.1 Receiver and source model

- [ ] Read and decode the captain-side HSI source selector: `sim/cockpit2/radios/actuators/HSI_source_select_pilot`.
- [ ] Confirm ToLiss captain PFD / ND receiver logic and whether the simulator source selector is authoritative for the ToLiss PFD.
- [ ] Determine which receiver is on-side for the captain's PFD/AP in the specific ToLiss build (X-Plane's generic ILS description uses NAV1 for a left/on-side autopilot and NAV2 for right/on-side; verify how ToLiss maps this).
- [ ] Read NAV1 and NAV2 independently. Do not assume the first receiver with a signal is the one displayed.
- [ ] Record tuned NAV frequency, signal validity, station ID and DME ID separately for each receiver.
- [ ] Use `navN_nav_id` for navaid identity and `navN_dme_id` for DME identity; X-Plane 12 distinguishes them for DME-only reception.
- [ ] Read each receiver's front-course / selected-course data and confirm true/magnetic reference before showing it.
- [ ] Treat GPS/FMS, GLS, FLS, LOC back-course and VOR as separate source/mode types. Do not show an ILS label or ILS course marker for another mode.
- [ ] Build a single `nav_solution` object with receiver, source type, frequency, ident, course, distance, validity, mode and age.
- [ ] Make receiver selection deterministic and visible in diagnostics; never switch silently between NAV1 and NAV2 during a capture.

### 5.2 Reconcile ToLiss and X-Plane sources

- [ ] Determine exact semantics for `AirbusFBW/ILSonCapt`, `ILSCrs`, `LOConCapt`, `LOCvalCapt`, `GSonCapt` and `GSvalCapt` for each supported aircraft build.
- [ ] Determine whether `LOConCapt` / `GSonCapt` mean display flags, receiver valid, signal captured, or deviation display active. Do not treat them as interchangeable.
- [ ] Determine whether ToLiss deviation values are dots, normalized ratios, degrees or another quantity.
- [ ] Determine whether ToLiss course is the selected front course, localizer beam course or a display reference; confirm 000°/360° behaviour.
- [ ] Resolve the current mismatch: `D.ils_on` / `D.ils_crs` are ToLiss-only while `D.loc_on` / `D.gs_on` may come from X-Plane.
- [ ] Define `auto` priority only after the actual captain PFD source is known. Forced source modes must state exactly which receiver/source they force.
- [ ] Avoid mixing LOC from one source with G/S from another unless both are proven to be the same navigation solution and explicitly presented as separate independent sources.
- [ ] If one axis is invalid, show that axis as flagged while retaining the valid axis only when the chosen receiver/source is known and coherent.
- [ ] Report source mismatch in diagnostics rather than hiding it behind `auto`.

### 5.3 LOC and G/S raw deviation scale

- [ ] Verify units, sign, full-scale deflection, usable range and saturation for both ToLiss and X-Plane values.
- [ ] Establish whether `hsi_hdef_dots_pilot` and `hsi_vdef_dots_pilot` are normalized in dots and whether their sign follows the intended fly-to / needle-deflection convention.
- [ ] Confirm whether display flags `hsi_display_horizontal_pilot` / `hsi_display_vertical_pilot` mean valid receiver, selected source, active deviation display or another state.
- [ ] Validate the ToLiss scale against the actual captain PFD at centre, half-scale, full-scale left/right and full-scale up/down.
- [ ] Validate the X-Plane scale against X-Plane's HSI with the selected NAV source and against the ToLiss PFD when ToLiss uses the same receiver.
- [ ] Remove “gain” as a substitute for unit correctness. Keep a small calibration factor only for verified display geometry / font scaling and document its role.
- [ ] Define a stable centre deadband only if it reflects display resolution; never hide actual small deviations by over-filtering.
- [ ] Use proper invalid/flagged state when no signal, wrong frequency, receiver deselected, out of range or no G/S.
- [ ] Distinguish LOC-only from LOC+G/S; no artificial G/S diamonds when vertical guidance is absent.
- [ ] Keep the present raw dot presentation labelled as raw PFD-style deviation, not Airbus conformal HUD approach guidance.

### 5.4 ILS information block

- [ ] Show source type (`ILS`, `LOC`, `F-LOC`, `F-G/S`, `GLS`, `FMS/GPS`, etc.) only when known.
- [ ] Show selected NAV receiver (NAV1/NAV2 or ToLiss-defined receiver) and tuned frequency.
- [ ] Show station ident only when valid and correctly decoded.
- [ ] Show DME distance only when it belongs to the same selected approach / receiver; distinguish DME ident from NAV ident.
- [ ] Show course only when the course source is valid; identify it as magnetic/true if the reference is relevant to the scale.
- [ ] Hide or explicitly flag course if the receiver is not tracking a localizer.
- [ ] Handle localizer back-course: identify the reverse-sensing condition and apply correct display behaviour only after its source and ToLiss implementation are verified.

### 5.5 Interception and capture awareness

- [ ] Keep the existing `CRS - TRK` cue as an angular awareness aid, but verify that course and track are both magnetic and belong to the same navigation solution.
- [ ] Rename or document `CRS - TRK` so it cannot be mistaken for a predicted capture solution.
- [ ] Add a numeric `LOC deviation trend` only after the dot sign/scale is validated; calculate its rate from timestamped snapshots and apply modest filtering / hysteresis.
- [ ] Determine whether a valid localizer bearing / DME / ownship position / runway geometry exists to estimate cross-track error and range to the beam. Raw dot deflection alone does not give an invariant distance-to-centreline.
- [ ] If distance-to-intercept or time-to-capture is ever shown, document the full geometry and assumptions; otherwise omit it.
- [ ] Detect LOC armed / LOC capture / LOC tracking from validated ToLiss FMA/mode data, not from “near-centre” deviation.
- [ ] Detect G/S armed / G/S capture / G/S tracking independently from lateral LOC state.
- [ ] For generic X-Plane fallback only, consider `sim/cockpit/autopilot/autopilot_state` bits for NAV armed/engaged and G/S armed/engaged (validate version and aircraft configuration). X-Plane documents NAV armed/engaged and glideslope armed/engaged as separate bit fields.
- [ ] Do not use generic X-Plane AP bit fields as the source of truth for ToLiss custom autoflight without proving that ToLiss publishes/synchronizes them.
- [ ] Build a deterministic state machine: `NO_SOURCE → TUNED/VALID → ARMED → CAPTURE → TRACKING → LOST/FLAGGED`, with separate lateral and vertical channels.
- [ ] Add hysteresis and timing so state labels do not flicker when a mode changes at a boundary.
- [ ] Make capture/loss annunciations follow the actual FMA and do not issue an invented “capture” prediction.
- [ ] Test capture from below/above, intercept angles 10°/30°/45°/90°, high crosswind, overshoot, LOC-only, GS-only, wrong frequency, NAV source switch and signal loss.

**Acceptance criteria (M3):**

- [ ] Deviation, course, frequency, ident, DME and mode all identify the same active receiver/source.
- [ ] LOC and G/S agree with the captain PFD in sign, scale, centre and flagging.
- [ ] No ILS symbols appear during an unrelated VOR/FMS/GLS approach unless explicitly labelled for that source type.
- [ ] LOC/G/S capture status matches the actual ToLiss FMA transition, not a heuristic based on dot position.

---

## 6. MILESTONE 4 — Airbus-inspired conformal approach guidance [P2 / major feature]

This is the largest visual/geometry task. FAST 46 describes a conformal LOC-axis line whose angle to the horizon communicates lateral position relative to the runway centreline, and an Approach Reference Flight Path symbol relative to the touchdown point for vertical path error. FAST 46 explicitly says natural perspective rules apply. These are **not** the same as the existing two raw deviation-dot scales.

### 6.1 Obtain a trustworthy runway / approach solution

- [ ] Identify the active landing runway from the ToLiss FMGS / active approach data if accessible.
- [ ] Investigate X-Plane navigation database / nav-aid APIs as fallback; do not infer a runway just from the nearest airport or a course number.
- [ ] Obtain or calculate runway threshold coordinates, runway axis / true bearing, displaced threshold, runway length and width where available.
- [ ] Obtain runway elevation / threshold elevation and a defined runway reference point (threshold, aiming point, touchdown-zone reference) separately.
- [ ] Obtain localizer station coordinates, antenna offset, front-course, beam direction and back-course flag where available.
- [ ] Obtain published approach path angle / FPA from the active procedure or a verified ILS glide path; do not hardcode 3.0° as universal.
- [ ] Establish the active approach type and source: ILS, LOC, FLS, GLS, RNAV/RNP or visual. Each has different guidance geometry and validity.
- [ ] Validate all coordinates and headings against known airport chart data or X-Plane's airport/nav database. Log the source and version.
- [ ] If a required geometric parameter is missing, hide the conformal cues and retain the raw deviation scale.

### 6.2 World-to-eye coordinate transformation

- [ ] Define an Earth/local tangent coordinate convention and explicitly document axis order and sign.
- [ ] Convert runway / localizer geo-coordinates to X-Plane local/world coordinates using supported SDK transforms where available; avoid naive lat/lon-to-pixel math.
- [ ] Read ownship position, elevation, pitch, roll, true heading and pilot eye reference position.
- [ ] Apply a camera/eye transform, including cockpit view orientation, view offsets, FOV, aspect ratio and zoom.
- [ ] Project runway geometry into screen/combiner coordinates using a perspective projection consistent with the active view.
- [ ] Apply clipping to the HUD combiner bounds and avoid rendering behind / outside the physical pane region.
- [ ] Test with cockpit camera movement, pilot seat movement, zoom, window resize, multi-monitor aspect ratios and VR if supported.
- [ ] Do not claim optical collimation or parallax correction from a normal 2D screen-space draw callback.
- [ ] Decide whether this feature requires a native X-Plane SDK plugin or a 3D cockpit object rather than the existing FlyWithLua 2D layer.

### 6.3 LOC axis conformal symbol

- [ ] Build the projected runway/localizer centreline from verified geometry, not from the selected course marker alone.
- [ ] Ensure the LOC axis is in perspective and its relationship to the horizon changes correctly with lateral position, range and view angle.
- [ ] Verify left/right movement with aircraft offset to both sides of the extended centreline.
- [ ] Verify behaviour when established, when intercepting from both sides, and when behind / beyond the localizer antenna.
- [ ] Handle localizer offset, runway magnetic variation, course reversal and back-course explicitly.
- [ ] Define no-signal / wrong-runway / no-geometry behaviour: do not render a false centreline.
- [ ] Keep raw LOC deviation available as a separate fallback/monitoring element where useful.

### 6.4 Approach Reference Flight Path and touchdown point

- [ ] Define the runway aiming point and touchdown reference from actual runway geometry / validated procedure data; do not equate an arbitrary screen point with the threshold.
- [ ] Define the Approach Reference Flight Path (ARFP) symbol independently from the actual FPV and from the flight director command symbol.
- [ ] Determine the selected / published descent path angle from a validated approach source.
- [ ] Compute how the ARFP relation to the touchdown point changes for above-path, on-path and below-path conditions.
- [ ] Validate natural perspective: the point and path marks must project to the correct apparent locations for aircraft position and view point.
- [ ] Test stable approach, high/low path, lateral offset, crosswind, different glide angles, runway slope, displaced thresholds and approach lighting conditions.
- [ ] Do not provide PAPI/VASIS replacement claims. The public Airbus article describes the concept, not enough of the detailed certification/calibration procedure to duplicate it.
- [ ] Mark this feature “experimental” until tested over multiple runways and aircraft view configurations.

### 6.5 ILS-only vs visual approach geometry

- [ ] For ILS, use the actual localizer and glide-slope solution; do not substitute runway axis alone for a localizer beam when it is offset or has a different front course.
- [ ] For visual approaches, require explicit runway selection and a chosen approach path reference. If the user-selected target is used, label it as user-defined.
- [ ] Distinguish path deviation from raw G/S dots. A G/S angle, beam geometry and DME/range may be needed to determine vertical position relative to the ideal path.
- [ ] No conformal approach graphics for an unknown runway, ambiguous active approach or unsupported navigation mode.

**Acceptance criteria (M4):**

- [ ] The runway/localizer projected geometry remains fixed to the real simulated runway through normal cockpit view changes (within the defined simulator visual tolerance).
- [ ] Left/right and above/below cases move the symbols in the correct direction.
- [ ] The FPV, ARFP, runway aiming point and touchdown point are distinct, correctly named concepts.
- [ ] If geometry is uncertain, the feature disappears safely instead of approximating a misleading runway.

---

## 7. MILESTONE 5 — Flight-phase modes and decluttering [P2]

FAST 46 describes distinct HUD display modes for taxi, take-off, climb/cruise/descent, approach and roll-out, with declutter levels to preserve outside visibility. The public article does not provide a complete state machine or thresholds; those must be defined from verified ToLiss state and simulator behaviour.

### 7.1 Phase detector

- [ ] Identify suitable source inputs for ground/air state, weight-on-wheels if exposed, groundspeed, radio altitude, gear, thrust, FMA, approach source and rollout state.
- [ ] Prefer explicit ToLiss flight-phase state if its meaning and units can be verified.
- [ ] Avoid using a single arbitrary AGL threshold as the complete phase detector.
- [ ] Build an explicit phase-state machine: `PARKED / TAXI / TAKEOFF / CLIMB / CRUISE / DESCENT / APPROACH / FLARE / ROLLOUT / GO_AROUND` only where reliable states exist.
- [ ] Add transition hysteresis, minimum dwell time and safe fallback state.
- [ ] Expose current phase and the inputs driving it in diagnostics.
- [ ] Allow a manual phase override for development/test only; clearly label it and make it reset safely.

### 7.2 Phase-specific symbol sets

- [ ] **Taxi:** ground speed, ground-acceleration / energy cue only if verified; remove unnecessary airborne attitude/approach clutter.
- [ ] **Take-off:** retain attitude/FPV and verified lateral raw guidance; add take-off-specific symbols only when source semantics exist. Tail-strike limit belongs to aircraft-specific validated data and should not be invented.
- [ ] **Climb / cruise / descent:** preserve attitude/energy and flight-path awareness; expose only valid weather-avoidance / TCAS alert cues sourced from the actual simulator system.
- [ ] **Approach:** prioritise FPV, verified approach source, raw deviations, course, conformal cues (once M4 is complete), RA and required FMA information.
- [ ] **Flare:** only implement if a verified flare cue / height reference is available and the exact behaviour is understood. Do not invent a flare prompt from AGL alone.
- [ ] **Roll-out:** add a ground deceleration scale only after its reference / units and braking interpretation are defined. FAST 46 mentions this mode but does not specify the complete algorithm.
- [ ] **Go-around:** use actual ToLiss FMA / mode data; avoid guessed TOGA state.
- [ ] Do not implement Airbus-specific warning logic solely from generic X-Plane values.

### 7.3 Declutter priorities

- [ ] Define essential, secondary and optional symbol layers.
- [ ] Establish deterministic draw priority: safety-critical valid alert (if present) > attitude/FPV > required approach guidance > speed/altitude > secondary info > debug.
- [ ] Make optional elements disappear before they obscure the outside scene.
- [ ] Provide configurable but bounded declutter levels, not arbitrary per-element changes that can create inconsistent layouts.
- [ ] Check for overlapping FMA, tapes, G/S scale, LOC scale, radio altitude, combiner frame and side readouts at all supported sizes / aspect ratios.
- [ ] Ensure debug diagnostics do not overlay the actual flying symbology by default.

**Acceptance criteria (M5):**

- [ ] The correct phase is selected consistently through each transition and does not flicker.
- [ ] The display is visibly less cluttered when the task requires an unobstructed outside view.
- [ ] Unsupported modes degrade to a simple, honest display rather than a guessed Airbus mode.

---

## 8. MILESTONE 6 — Supporting PFD-like information and display quality [P2]

### 8.1 Speed / altitude tapes

- [ ] Audit all speed limits and markers: VLS, VMAX/VMO, alpha-protection, alpha-max, green dot, V1, VR, selected speed, managed speed and dashed/constraint states.
- [ ] Confirm each marker's units, validity, applicability by flight phase and precedence when two values coincide.
- [ ] Confirm IAS/Mach target logic; do not infer Mach mode only because a numeric value is below 2 unless the source confirms it.
- [ ] Confirm altitude tape reference (barometric indicated altitude, selected altitude, QNH/QFE/STD) and unit conversion.
- [ ] Confirm selected altitude source and whether it is FCU target vs FMS constraint.
- [ ] Verify trend vector units and filter (kt/s vs kt per 10 s); do not show an arbitrarily scaled trend.
- [ ] Verify tape direction, tick spacing, label rounding and off-scale bugs.
- [ ] Ensure speed/altitude readout boxes fit all supported font sizes and never extend outside their labels/plates.
- [ ] Test metric / imperial settings only if ToLiss exposes them and the project explicitly supports them.

### 8.2 Radio altitude and barometric setting

- [ ] Confirm radio altitude validity and behaviour on ground, terrain, water, slopes and near DH.
- [ ] Confirm ToLiss `ralt_is_amber` and `DH` semantics; do not reconstruct a certified decision-height alert from a generic value if ToLiss already supplies the display state.
- [ ] Validate the radio-altimeter low-height flashing logic, amber state and no-data state.
- [ ] Audit barometric standard flag, unit flag, and conversion between hPa/inHg.
- [ ] Confirm whether baro value is captain-side setting, active ADC correction or generic X-Plane setting.

### 8.3 FMA

- [ ] Preserve the five FMA columns/positions and rows; validate actual font metrics and spacing.
- [ ] Determine how ToLiss exposes colour layers and whether their position / style carries meaning.
- [ ] Keep a single-colour HUD but preserve semantic priority using the Airbus-style shapes/underlines/boxing only where supported by public references or clearly labelled project conventions.
- [ ] Add explicit clipping and text-fit calculations for long labels.
- [ ] Show AP1/AP2/FD/A/THR status only if FMA strings are unavailable and the state sources have been validated.
- [ ] Do not derive `LOC*`, `G/S*`, `FINAL`, `LAND`, `FLARE`, `ROLLOUT` or go-around from raw LOC/G/S deviations.

### 8.4 Text, fonts, line weight and readability

- [ ] Replace the estimated `#text * char_width` measurement with real measurement where FlyWithLua exposes it, or an audited glyph-width table per fixed bitmap font.
- [ ] Add a label fitter that chooses the smallest allowed font, reduces padding, wraps only where semantically acceptable or hides secondary content.
- [ ] Keep font baseline and cap-height separate; calculate plate bounds from actual glyph metrics.
- [ ] Add clipping / safe-area rules for FMA and readout plates.
- [ ] Test 720p, 1080p, 1440p, 4K, ultrawide, resized windows and high-DPI scaling.
- [ ] Verify line widths are stable and not overly bright / thick at small sizes.
- [ ] Compare green intensity / contrast against bright clouds, dark ground, dusk, night, snow and city lighting.
- [ ] Ensure glass tint never reduces outside visibility excessively; provide a minimum/maximum range and a safe reset.

### 8.5 Combiner and view calibration

- [ ] Make it clear that the current panel is a screen-space visual combiner, not a true HUD optical unit.
- [ ] Separate symbology anchor, combiner frame geometry and clipping region; they currently share one centre/size assumption.
- [ ] Add a calibration pattern for centre boresight, horizon level, known pitch/bank and the combiner perimeter.
- [ ] Store calibration profiles by display resolution / aspect ratio / aircraft and cockpit view where practicable.
- [ ] Prevent symbols from drawing outside the combiner polygon.
- [ ] Make edge/bevel strength, tint and text brightness independent and avoid any opaque glass fill.
- [ ] Confirm alpha blending on supported X-Plane / FlyWithLua combinations and check the rest of the simulator rendering is not affected.
- [ ] Evaluate an optional native plugin / 3D cockpit implementation for true world-conformal projection and pilot eye-point geometry; keep it as a separate architectural milestone.
- [ ] For VR, do not claim correct collimation or parallax with a single 2D desktop overlay. Require stereo-aware rendering and per-eye calibration if support is ever attempted.

**Acceptance criteria (M6):**

- [ ] No labels, boxes or symbols overlap or spill outside the combiner at the supported resolutions.
- [ ] Speed/altitude tapes agree with ToLiss PFD numerically and directionally.
- [ ] FMA remains readable and correctly aligned during long mode strings.
- [ ] Glass styling is restrained and does not obscure the outside view.

---

## 9. MILESTONE 7 — Advanced functions: implement only with verified source [P3 / optional]

FAST 56 describes the A320 Family L5 HUD standard (certified in February 2015) and mentions integration with ROPS, RNP AR, AP/FD TCAS, advisory runway-ahead, soft go-around and BUSS. These are aircraft/system integrations, not decorative symbols. They are not part of the current Lua overlay and must not be simulated from guessed logic.

- [ ] **TCAS / AP-FD TCAS:** only display alerts from the actual ToLiss/X-Plane TCAS state and message data; verify traffic source, threat level, RA direction and state transitions. Never synthesize an RA.
- [ ] **Windshear:** do not create a warning from weather heuristics. Use a validated simulator/aircraft warning source or leave out.
- [ ] **ROPS / runway overrun:** requires validated runway, braking, stopping-distance and aircraft performance logic; out of scope unless a dedicated trusted source exists.
- [ ] **RNP AR / RNP monitoring:** requires active FMS procedure, navigation accuracy/integrity, containment and alert data. Do not infer from GPS track error alone.
- [ ] **Advisory runway ahead:** requires ownship/runway geometry and correct runway association; no nearest-runway guess.
- [ ] **Soft go-around:** do not simulate as a switch or cue without validated aircraft logic.
- [ ] **BUSS:** only if the actual ToLiss aircraft exposes a genuine BUSS source/state; do not build a lookalike backup speed scale from arbitrary thresholds.
- [ ] **Low Visibility Take-Off / CAT II/III / autoland monitoring:** do not add minima or capability indications based on generic simulator state; aircraft option and approved procedures matter.
- [ ] Keep unsupported features documented under “not implemented / not simulated”.

---

## 10. MILESTONE 8 — Compatibility, code architecture and performance [P1]

### 10.1 Aircraft profiles

- [ ] Define explicit profiles for ToLiss A319, A320, A321 and each supported ceo/neo variant/build.
- [ ] During aircraft load/change, identify the profile and enable only validated datarefs for that profile.
- [ ] Build a per-profile support matrix: available, unavailable, experimental, verified.
- [ ] Do not advertise A340 compatibility unless all essential datarefs, modes and source semantics are independently validated for that aircraft.
- [ ] Keep stock X-Plane fallback clearly separated from ToLiss-specific mode logic.

### 10.2 Code organisation

- [ ] Split the monolithic file into logical modules or clearly isolated sections:
  - configuration / preferences;
  - dataref catalogue and typed readers;
  - snapshot / source arbitration;
  - unit and geometry helpers;
  - flight-state / navigation-state logic;
  - symbol drawing;
  - settings UI;
  - diagnostics / logging.
- [ ] Keep drawing functions pure where practical: pass a snapshot and geometry; do not read datarefs from inside draw helpers.
- [ ] Keep all conversion and wrap functions in one utility section/module.
- [ ] Add versioned preferences with a migration path when settings names or meanings change.
- [ ] Add a compatibility guard for FlyWithLua features / X-Plane versions; fail visibly but safely if required drawing APIs are absent.
- [ ] Add an explicit debug mode that never changes flight-system state.

### 10.3 Performance and robustness

- [ ] Cache dataref handles and string bindings, but detect aircraft/provider changes and stale/orphan states.
- [ ] Measure CPU time / frame-time overhead with diagnostics off and on.
- [ ] Avoid file I/O, large string parsing and expensive dataref lookup in the draw callback.
- [ ] Rate-limit logging; no repeated error spam.
- [ ] Guard every renderer group against missing/invalid values; one bad dataref must not blank the whole HUD.
- [ ] Verify callback behaviour during pause, replay, time acceleration, plugin reload, aircraft reload and settings close/open.
- [ ] Restore or isolate OpenGL state as safely as FlyWithLua allows.
- [ ] Ensure preferences are written atomically or recover gracefully from a partial file.

**Acceptance criteria (M8):**

- [ ] No X-Plane crash, Lua error loop, permanent blank HUD or persistent graphics-state corruption during the test matrix.
- [ ] No material FPS regression in normal use; publish measured results and test hardware/conditions where possible.
- [ ] Each supported aircraft has a documented dataref/profile status.

---

## 11. Verification plan — required test matrix

A feature is not “done” until it has a reproducible simulator test and a recorded result. For each test, save: X-Plane version/build, ToLiss aircraft/version, FlyWithLua version, operating system, view/FOV/resolution, weather/wind, source settings, diagnostic log and screenshots/video where helpful.

### 11.1 Data source / startup

- [ ] Cold & dark, before electrical power.
- [ ] Electrical power applied; ADIRS off / aligning / aligned.
- [ ] Engines off / engines running.
- [ ] ToLiss plugin unavailable, disabled, reloaded and re-enabled.
- [ ] Lua script loaded before aircraft plugin and reloaded after aircraft load.
- [ ] Switch A319 ↔ A320 ↔ A321 and ceo ↔ neo where installed.
- [ ] Switch to a non-ToLiss aircraft and back.
- [ ] Confirm that valid zero values are not flagged as missing.
- [ ] Confirm stale/orphaned datarefs do not masquerade as a healthy zero state.

### 11.2 Attitude / trajectory / energy

- [ ] Straight-and-level flight, zero drift.
- [ ] Climb and descent at constant speed.
- [ ] Level acceleration and deceleration.
- [ ] Climb with acceleration / deceleration.
- [ ] Descent with acceleration / deceleration.
- [ ] Constant bank left/right and roll-in/roll-out.
- [ ] Crosswind from left/right and tailwind/headwind.
- [ ] High sideslip and unusual attitudes.
- [ ] Very low groundspeed / stationary / taxi.
- [ ] Turbulence and wind changes.
- [ ] Compare ToLiss FPV and X-Plane inertial FPV.

### 11.3 Heading / track / selected targets

- [ ] FCU selected values: 000, 001, 090, 180, 270, 359 degrees.
- [ ] Cross 359°→000° and 000°→359° in both directions.
- [ ] HDG mode, TRK mode, managed NAV and selected HDG transitions.
- [ ] Wind correction with heading different from track.
- [ ] Compare FCU target, ToLiss dataref, X-Plane heading dial and displayed bug.
- [ ] FD/AP1/AP2 states and mode changes.
- [ ] Source mismatch / stale generic heading target.

### 11.4 Radio navigation / ILS

- [ ] NAV1 ILS, NAV2 ILS and receiver/source switching.
- [ ] Correct frequency / wrong frequency / no ident / DME-only reception.
- [ ] LOC and G/S centred; small deviation; half-scale; full-scale left/right/up/down.
- [ ] Localizer intercept from left and right at 10°, 30°, 45° and 90°.
- [ ] Localizer capture and track; overshoot and recapture.
- [ ] G/S intercept from below and above; G/S capture and track.
- [ ] LOC-only approach; no G/S; G/S invalid; signal out of range.
- [ ] Back-course / reverse sensing if supported by the aircraft and simulator setup.
- [ ] VOR, RNAV/FMS, GLS, FLS and LOC-backcourse cases to ensure they are not mislabeled ILS.
- [ ] Compare all indications with the captain PFD and FMA.
- [ ] Test high crosswind, crab angle and drift.
- [ ] Test Go-Around from an established approach.

### 11.5 Conformal approach / visual references

- [ ] Runway directly ahead and offset left/right.
- [ ] Aircraft above / on / below selected approach path.
- [ ] Different runway headings, runway lengths, displaced thresholds and runway slopes.
- [ ] Different published approach path angles.
- [ ] Cockpit view / eye-point / FOV / zoom changes.
- [ ] Day, night, dusk, clouds, haze, rain and reduced visibility.
- [ ] Confirm cue projection remains attached to the runway geometry.

### 11.6 Rendering / UI / reliability

- [ ] 720p, 1080p, 1440p, 4K and ultrawide; windowed and full screen.
- [ ] Small and large HUD sizes; min/max line width and text scale.
- [ ] FMA strings with longest labels; all numeric labels at min/max values.
- [ ] Glass on/off; min/max tint and edge; plate alpha on/off.
- [ ] External view hidden; cockpit view shown; view transitions.
- [ ] Paused, replay, time acceleration and plugin reload.
- [ ] Settings save, restart, corrupt preferences and restore defaults.
- [ ] Diagnostics enabled without obscuring flying symbols.
- [ ] Multiple other plugins loaded to check graphics-state interference.

---

## 12. Automated tests and tooling

- [ ] Create pure-Lua tests for:
  - `wrap180()` / `wrap360()`;
  - unit conversions;
  - true/magnetic reference handling;
  - FPA and track calculations;
  - dataref validity/range/freshness;
  - source arbitration;
  - LOC/G/S sign and normalization;
  - HDG/TRK selected-target mapping;
  - phase-state transitions and hysteresis;
  - perspective projection helpers, if M4 proceeds.
- [ ] Run tests in the same Lua version / subset used by FlyWithLua (avoid depending on newer Lua syntax unless supported).
- [ ] Add a fake dataref layer / recorded snapshot playback so calculations can be tested without a live flight.
- [ ] Add golden test snapshots for known cases: level 0° drift, 10° right drift, 3° climb, 3° descent, heading wrap, LOC centre/full-scale and G/S centre/full-scale.
- [ ] Add a release smoke-test script that checks required files, Lua syntax where tooling is available, version strings and ZIP contents.
- [ ] Record known test gaps honestly in each release.

---

## 13. Documentation, project release and community support

- [ ] Keep `README.md` feature claims aligned with the verified support matrix; mark experimental features clearly.
- [ ] Link this `TODO.md` from the README.
- [ ] Keep `AIRBUS_HUD_NOTES.md` as a research summary, not as an Airbus specification.
- [ ] Add `DATAREF_AUDIT.md` with actual source/type/unit/validity results per aircraft version.
- [ ] Add `TESTING.md` with simulator scenario instructions and a template for user-reported test results.
- [ ] Add `KNOWN_LIMITATIONS.md` if the limitations section becomes too long for the README.
- [ ] Add screenshots from the project itself (no Airbus FAST images unless permission allows); label screenshots with simulator and aircraft versions.
- [ ] Add GitHub issue templates: bug report, dataref audit, visual alignment and feature request.
- [ ] Ask contributors to attach diagnostic snapshots, not just say “LOC is off” or “heading is wrong”.
- [ ] Keep the original `LICENSE` file unchanged. Preserve upstream credits in the Lua header and README.
- [ ] Do not bundle ToLiss aircraft files, proprietary datarefs, Airbus manuals, Airbus figures or copyrighted reference artwork.
- [ ] Add a clear disclaimer in the README and forum announcement: simulation-only, unofficial, no operational use, not affiliated with Airbus/ToLiss/Laminar Research.
- [ ] Version releases only when code, README, changelog, TODO, test record and ZIP contents agree.

---

## 14. Suggested implementation order

The order below is deliberate. Do not jump straight to a synthetic runway or extra symbols while the input semantics are uncertain.

| Order | Milestone | Priority | Depends on | Exit gate |
|---:|---|---|---|---|
| 1 | Typed dataref catalogue, freshness and diagnostics | **P0** | None | Every critical input is type/unit/source audited |
| 2 | Receiver/source arbitration and ILS course coherence | **P0** | 1 | ILS source, course, deviations and flags refer to one receiver |
| 3 | Heading/track target reconciliation | **P1** | 1 | FCU target agrees through 0–359°, HDG/TRK tested |
| 4 | Attitude, FPV and FD validation | **P1** | 1 | Correct signs, units, drift and no mixed sources |
| 5 | LOC/G/S dot scale validation and capture state | **P1** | 1–2 | Matches PFD/FMA in intercept and capture tests |
| 6 | Total-energy / speed-delta research and prototype | **P1** | 1, 4 | Correctly named, physically defensible and tested |
| 7 | FMA / tapes / label layout cleanup | **P1** | 1–5 | No overlap and no misleading state text |
| 8 | Phase state machine and declutter | **P2** | 1–7 | Phase transitions tested and stable |
| 9 | Runway / localizer / approach geometry provider | **P2** | 1–2 | Correct runway/approach geometry source |
| 10 | Eye-point projection and conformal LOC/ARFP cues | **P2** | 9 | Stable visual alignment across viewpoint tests |
| 11 | Native 3D / SDK rendering decision | **P2 architecture** | 10 | Screen-space limitations documented or 3D path justified |
| 12 | Advanced integrated functions | **P3 / optional** | Verified aircraft data only | No guessed warnings or capabilities |
| 13 | Regression tests, docs and release package | Every release | Relevant milestones | Reproducible test record and clean ZIP |

---

## 15. Release gate — definition of “done”

A release is ready for public GitHub / X-Plane.org publication only when all applicable gates pass:

- [ ] The project starts cleanly in the supported X-Plane / FlyWithLua / ToLiss combination.
- [ ] All critical datarefs are typed, unit-checked and documented.
- [ ] HUD readings agree with the ToLiss captain PFD / FCU / FMA in the tested conditions.
- [ ] ILS receiver, course, ident, frequency, LOC and G/S are coherent and valid.
- [ ] Heading/track target agrees with the ToLiss FCU in all tested wrap-around and HDG/TRK cases.
- [ ] No false LOC/G/S capture, no false FMA mode, no synthetic warning and no invalid conformal cue is shown.
- [ ] All unsupported symbols are hidden or explicitly described as approximations.
- [ ] Text and graphics fit supported screen layouts.
- [ ] No known graphics-state or performance regression is left undocumented.
- [ ] README, CHANGELOG, TODO, research notes, LICENSE and packaged files agree.
- [ ] ZIP has been extracted and tested after creation.
- [ ] The release notes state the exact test matrix completed and the remaining limitations.

---

## 16. Research references

### Airbus — public technical material

1. **Airbus FAST 46 (August 2010), “Head-Up Display System — Enhanced Operations’ Situational Awareness”, pp. 27–29.** Public explanation of core HUD symbols (attitude, FPV, Total FPA, speed delta), conformal LOC-axis / approach-reference path concepts, natural perspective, phase-specific modes and decluttering. It is a technical-magazine article, not the approved A320 FCOM/FCTM or a full HUD design definition.  
   https://aircraft.airbus.com/sites/g/files/jlcbta126/files/2022-04/FAST46.pdf
2. **Airbus FAST 56 (August 2015), “The evolving Airbus HUD offer”, especially A320 Family L5 discussion.** Describes the A320 Family L5 HUD standard and its integration with functions such as ROPS, RNP AR, AP/FD TCAS, advisory runway ahead, soft go-around and BUSS. These are aircraft/system integrations; the article does not provide implementation data or permission to reproduce Airbus artwork.  
   https://aircraft.airbus.com/sites/g/files/jlcbta126/files/2022-04/FAST56.pdf

### Laminar Research / X-Plane — official developer material

3. **X-Plane Developer — XPLMDataAccess.** Dataref type masks, scalar/array reading and the rule that automatic type conversion is not performed; mismatched/orphaned reads can return default zero.  
   https://developer.x-plane.com/sdk/XPLMDataAccess/
4. **X-Plane Developer — Autopilot navigation source reference.** HSI source selection, on-side ILS receiver behaviour and distinctions between ILS, RNAV/FMS, GLS and LOC back-course approaches; includes course, IDs and DME context.  
   https://developer.x-plane.com/article/autopilot-navigation-source-reference/
5. **X-Plane Developer — Accessing the X-Plane autopilot from datarefs.** Documents the stock `autopilot_state` mode bit fields, including NAV and glideslope armed/engaged. Use as generic X-Plane fallback only unless ToLiss synchronisation is proven.  
   https://developer.x-plane.com/article/accessing-the-x-plane-autopilot-from-datarefs/
6. **X-Plane Developer — Changes to Radio Navigation.** Distinguishes NAV ID from DME ID and explains X-Plane 12 DME-only reception behaviour.  
   https://developer.x-plane.com/article/changes-to-radio-navigation/
7. **X-Plane Developer — Moving the Plane.** Documents the local coordinate system and world-coordinate velocity components (`local_vx`, `local_vy`, `local_vz`) in metres per second; useful for validating FPV / track calculations.  
   https://developer.x-plane.com/article/movingtheplane/

### Community / non-authoritative evidence

8. Community ToLiss dataref lists and legacy source material can help discover candidate dataref names. They do **not** establish official units, sign conventions, validity semantics, update rates or guarantees across versions. Each candidate must be verified in the installed aircraft.  
   https://github.com/dualznz/toliss-a430-datarefs

---

## 17. Open questions requiring live ToLiss/X-Plane evidence

- [ ] What exact XPLM type does each `AirbusFBW/*` flag and `toliss_airbus/pfdoutputs/*` value use in each supported aircraft build?
- [ ] What unit, sign and validity contract applies to `LOCvalCapt` and `GSvalCapt`?
- [ ] What is the exact relationship between `ILSonCapt`, `LOConCapt`, `GSonCapt` and their associated deviation values?
- [ ] Does `ILSCrs` represent magnetic front course, true course, selected FCU course or another value?
- [ ] Does `APHDG_Capt` represent selected magnetic heading, selected magnetic track or an internal relative target? Is it synchronized with X-Plane's heading dial?
- [ ] What is the exact meaning/sign/unit of `APHDGreltoTRK` and `HDGTRKmode`?
- [ ] Are ToLiss captain FPA/drift values true or magnetic referenced, and are they sampled from the same source/time?
- [ ] What is the correct semantic contract for `fd1_pitch_cmd` / `fd1_roll_cmd`?
- [ ] Which ToLiss datarefs expose active runway, approach type, localizer/glide-slope validity, path angle, runway threshold, touchdown-zone and flight phase?
- [ ] Can the installed ToLiss aircraft expose the captain's selected NAV receiver/source consistently to FlyWithLua?
- [ ] Which parts of the current screen-space renderer can be made conformal with the public FlyWithLua API, and which require a native SDK / 3D aircraft integration?

Until these questions have evidence, leave the affected features tagged experimental or not implemented.
