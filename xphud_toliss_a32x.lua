-- XPHUD for FlyWithLua v2.3.0 ToLiss A32X edition ---------------------------
-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 xbard                (original XPHUD for FlyWithLua v2.0.0)
-- Copyright (c) 2026 Control_TWR        (ToLiss A32X edition and enhancements)
-- See LICENSE.  Version 2.3.0 (ToLiss A32X edition)
--
-- MODIFIED VERSION.  This file is derived from "XPHUD for FlyWithLua" v2.0.0 by
-- xbard (https://xpconnect.me), released under the MIT licence.  It is an
-- unofficial edition and is NOT made, endorsed or supported by the original
-- author, by XPConnect, by ToLiss or by Airbus.
--
-- What this edition does
--   A head-up display for the ToLiss A319 / A320 / A321 (ceo and neo) in
--   X-Plane 12, drawn with FlyWithLua's 2D OpenGL callback and styled after the
--   Airbus single-colour (green) HUD: FMA, speed tape with speed-limit markers,
--   altitude tape, vertical speed, flight path vector, flight director cue,
--   pitch ladder + horizon, roll scale, heading scale, ILS deviation, radio
--   altitude, Mach, selected speed / altitude / heading, failure flags.
--
--   DATA SOURCES.  Every value is read from a ToLiss dataref when that dataref
--   exists (AirbusFBW/... and toliss_airbus/pfdoutputs/...).  When it does not
--   (other aircraft, or a ToLiss dataref that is not there) the stock X-Plane
--   dataref is used instead; where no stock equivalent exists the element is
--   simply hidden.  Datarefs are resolved lazily and retried every 2 seconds,
--   because the ToLiss plugin creates its datarefs after the aircraft loads.
--   Nothing from ToLiss is bundled: you need your own copy of the aircraft.
--
--   Changes from upstream XPHUD 2.0.0
--     * new default profile: Airbus A32X HUD, colour theme "green" by default
--     * numeric dataref availability drives failure flags (not Capt*Valid alone)
--     * translucent combiner pane, beveled edge and adjustable glass opacity
--     * 2.3.0: combiner hardware redrawn as an overhead unit with a hinged,
--       perspective combiner, and an adjustable eye distance (see README)
--     * helicopter set (hover arrow, landing bars, NR%, VRS), weapons/combat
--       set and force-trim were removed (they do not apply to an airliner, and
--       the trim code wrote joystick override datarefs)
--     * commands, shared dataref, prefs file and globals were renamed
--       (XPHUD_A32X/..., xphud_toliss_a32x.prefs, xa32_*) so this edition can
--       be installed next to the original without clashing with it
--
-- Credits carried over from upstream:
--   * The original HeliHUD was designed, developed and released by Steve
--     Hanley for Microsoft Flight Simulator 2004 in September 2003, as freeware.
--   * HUD after Petr Medek's HeliHud (2011, https://github.com/me2d13/helihud),
--     MIT-licensed.
--
-- Install:  X-Plane 12/Resources/plugins/FlyWithLua/Scripts/xphud_toliss_a32x.lua
-- Commands: XPHUD_A32X/Toggle, XPHUD_A32X/Settings, XPHUD_A32X/Center
-- Shared dataref: XPHUD_A32X/Visible (int, writable)
-- Settings persist to Output/preferences/xphud_toliss_a32x.prefs
-- ---------------------------------------------------------------------------

require("graphics")

local EDITION = "XPHUD for FlyWithLua v2.3.0 ToLiss A32X edition"

if not SUPPORTS_FLOATING_WINDOWS then
    logMsg("XPHUD A32X: this FlyWithLua build has no floating-window/imgui support; "
        .. "the HUD will still draw, but the settings window is unavailable.")
end

-- ---------------------------------------------------------------- config --

local DEFAULTS = {
    visible        = true,
    hide_external  = true,    -- hide the HUD in outside views
    size           = 600,     -- HUD/combiner size in pixels
    pos_x          = 0,       -- HUD centre offset from screen centre, px
    pos_y          = 0,       -- +x right, +y down
    line_w         = 2.5,     -- line thickness in pixels (scaled with size)
    text_scale     = 1.0,     -- multiplier on all HUD text
    hud_alpha      = 1.0,     -- symbology brightness (bitmap fonts do not expose glyph alpha)
    plate_alpha    = 0.0,     -- dark backing behind individual readouts (0 = off)
    show_glass     = true,    -- draw the transparent combiner pane and its subtle edge
    show_hardware  = true,    -- draw the overhead unit, hinge and combiner frame
    hardware_alpha = 0.92,    -- hardware opacity (1 = solid dark metal)
    eye_distance_cm = 70,     -- visual eye-to-combiner distance; scales the whole assembly
    night_profile  = false,   -- soften frame and glass edge for dark scenes
    startup_splash = true,    -- brief XPHUD identity screen when the script starts
    animate_deployment = true,-- animate the 2D combiner on show/hide
    glass_alpha    = 0.035,  -- subtle pane tint; keep low to preserve outside visibility
    glass_edge_alpha = 0.22, -- combiner edge / reflection opacity
    theme          = "green", -- green | modern | classic
    fpv_src        = "auto",  -- auto (ToLiss PFD values) | xplane (inertial vector from the sim)
    ladder_deg     = 15,      -- degrees of pitch that span 0.4 * HUD size
    spd_range_kt   = 40,      -- speed tape half-window
    alt_range_ft   = 400,     -- altitude tape half-window
    ralt_max_ft    = 2500,    -- radio altitude shown below this
    fd_roll_deg    = 30,      -- FD roll order that deflects the cue to 0.4 * size
    inv_loc        = false,   -- calibration: flip LOC deviation sign
    inv_gs         = false,   -- calibration: flip glideslope deviation sign
    inv_fd_pitch   = false,   -- calibration: flip FD pitch order sign
    inv_fd_roll    = false,   -- calibration: flip FD roll order sign
    hdg_sel_source = "auto", -- auto (X-Plane standard magnetic dial first) | xplane | toliss
    hdg_sel_offset = 0,       -- small display calibration, degrees
    hdg_scale_horizon = true, -- Airbus-style heading/track scale on horizon line
    ils_source      = "auto", -- auto (ToLiss if valid) | xplane | toliss
    ils_gain        = 1.0,     -- display calibration only; 1.0 = raw PFD dot values
    show_debug     = false,   -- live readout: value + source of every dataref
    show_fma       = true,
    show_spd       = true,
    show_alt       = true,
    show_vs        = true,
    show_hdg       = true,
    show_horizon   = true,
    show_bank      = true,
    show_fpv       = true,
    show_fd        = true,
    show_ils       = true,
    show_ralt      = true,
    show_center    = true,
    show_mach      = true,
    show_gs        = true,
    show_baro      = true,
    show_targets   = true,    -- selected speed / altitude readouts and bugs
    show_trend     = true,
    show_vmarks    = true,    -- VLS, alpha-prot, alpha-max, VMAX, green dot, V1/VR
    show_flags     = true,    -- SPD / ALT / ATT / HDG failure flags
    show_cfg       = false,   -- gear + flap lever
}

local PREF_BOUNDS = {
    size = { 300, 1200 },
    pos_x = { -10000, 10000 },
    pos_y = { -10000, 10000 },
    line_w = { 1, 6 },
    text_scale = { 0.7, 2.5 },
    hud_alpha = { 0.2, 1 },
    plate_alpha = { 0, 1 },
    hardware_alpha = { 0, 1 },
    eye_distance_cm = { 45, 120 },
    glass_alpha = { 0, 0.18 },
    glass_edge_alpha = { 0, 0.8 },
    ladder_deg = { 8, 30 },
    spd_range_kt = { 20, 80 },
    alt_range_ft = { 200, 1000 },
    ralt_max_ft = { 500, 3000 },
    fd_roll_deg = { 10, 60 },
    hdg_sel_offset = { -10, 10 },
    ils_gain = { 0.25, 4 },
}

local PREF_OPTIONS = {
    theme = { green = true, modern = true, classic = true },
    fpv_src = { auto = true, xplane = true },
    hdg_sel_source = { auto = true, xplane = true, toliss = true },
    ils_source = { auto = true, xplane = true, toliss = true },
}

local cfg = {}
for k, v in pairs(DEFAULTS) do cfg[k] = v end

-- "green" is the A32X HUD: one colour, cues told apart by shape and brightness.
-- "modern" / "classic" are kept from upstream for people who want colour.
local PALETTES = {
    green = {
        text    = {0.35, 1.00, 0.45},
        units   = {0.22, 0.62, 0.30},
        box     = {0.35, 1.00, 0.45},
        center  = {0.60, 1.00, 0.55},
        ladder  = {0.35, 0.92, 0.45},
        track   = {0.60, 1.00, 0.55},
        fpv     = {0.60, 1.00, 0.55},
        fd      = {0.60, 1.00, 0.55},
        caution = {0.85, 1.00, 0.25},
        warn    = {0.65, 1.00, 0.30},
        trend   = {0.35, 0.90, 0.45},
        ils     = {0.60, 1.00, 0.55},
        bug     = {0.60, 1.00, 0.55},
    },
    modern = {
        text    = {1.00, 1.00, 1.00},
        units   = {0.65, 0.65, 0.65},
        box     = {1.00, 1.00, 1.00},
        center  = {1.00, 0.85, 0.10},
        ladder  = {0.95, 0.95, 0.95},
        track   = {1.00, 0.30, 1.00},
        fpv     = {0.10, 1.00, 0.10},
        fd      = {1.00, 0.30, 1.00},
        caution = {1.00, 0.70, 0.10},
        warn    = {1.00, 0.15, 0.10},
        trend   = {0.30, 0.85, 1.00},
        ils     = {0.30, 0.85, 1.00},
        bug     = {0.30, 0.85, 1.00},
    },
    classic = {
        text    = {1.00, 1.00, 1.00},
        units   = {1.00, 1.00, 1.00},
        box     = {0.10, 0.90, 0.20},
        center  = {1.00, 0.25, 1.00},
        ladder  = {1.00, 1.00, 1.00},
        track   = {1.00, 0.25, 1.00},
        fpv     = {0.10, 1.00, 0.10},
        fd      = {1.00, 0.25, 1.00},
        caution = {1.00, 0.70, 0.10},
        warn    = {1.00, 0.15, 0.10},
        trend   = {0.35, 0.55, 1.00},
        ils     = {1.00, 0.25, 1.00},
        bug     = {0.35, 0.55, 1.00},
    },
}
local COL = PALETTES.green   -- re-resolved from cfg.theme each frame

local THEME_ORDER = { "green", "modern", "classic" }
local FPV_ORDER   = { "auto", "xplane" }
local HDG_SOURCE_ORDER = { "auto", "xplane", "toliss" }
local ILS_SOURCE_ORDER = { "auto", "xplane", "toliss" }

local KT_PER_MS = 1.0 / 0.514444
local FT_PER_M  = 1.0 / 0.3048
local atan2 = math.atan2 or math.atan

-- Angle helpers: the only place bearings / courses are wrapped.  Lua's % takes
-- the sign of the divisor, so both results are well defined for any input.
local function wrap360(a) return a % 360 end             -- [0, 360)
local function wrap180(a) return (a + 180) % 360 - 180 end -- [-180, 180)

-- ------------------------------------------------------------ data layer --
-- Dataref types must be checked before choosing a scalar getter: X-Plane does
-- not convert between int, float and double. A missing dataref is retried
-- every RETRY_S seconds because ToLiss creates its references after aircraft
-- load. Nothing here is written to the sim.

local RETRY_S = 2
local refs, miss = {}, {}
local scalar_readers, warned_reader = {}, {}

local XPLM_TYPE_INT = 1
local XPLM_TYPE_FLOAT = 2
local XPLM_TYPE_DOUBLE = 4

local function has_dataref_type(mask, type_id)
    return math.floor(mask / type_id) % 2 == 1
end

local function scalar_reader(path, dataref)
    local cached = scalar_readers[path]
    if cached ~= nil then
        if cached == false then return nil end
        return cached.getter
    end

    if type(XPLMGetDataRefTypes) ~= "function" then
        if not warned_reader.no_type_api then
            logMsg("XPHUD A32X: XPLMGetDataRefTypes is unavailable; scalar datarefs will be skipped")
            warned_reader.no_type_api = true
        end
        scalar_readers[path] = false
        return nil
    end

    local types = XPLMGetDataRefTypes(dataref)
    local getter, kind
    if has_dataref_type(types, XPLM_TYPE_FLOAT) and type(XPLMGetDataf) == "function" then
        getter, kind = XPLMGetDataf, "float"
    elseif has_dataref_type(types, XPLM_TYPE_DOUBLE) and type(XPLMGetDatad) == "function" then
        getter, kind = XPLMGetDatad, "double"
    elseif has_dataref_type(types, XPLM_TYPE_INT) and type(XPLMGetDatai) == "function" then
        getter, kind = XPLMGetDatai, "int"
    end

    if not getter then
        if not warned_reader[path] then
            logMsg("XPHUD A32X: unsupported non-scalar dataref type for '" .. path .. "'")
            warned_reader[path] = true
        end
        scalar_readers[path] = false
        return nil
    end

    scalar_readers[path] = { getter = getter, kind = kind }
    return getter
end

local function ref(path)
    local r = refs[path]
    if r then return r end
    local t = os.time()
    local m = miss[path]
    if m and (t - m) < RETRY_S then return nil end
    r = XPLMFindDataRef(path)
    if r then
        refs[path] = r
        miss[path] = nil
        return r
    end
    miss[path] = t
    return nil
end

local PF = "toliss_airbus/pfdoutputs/"
local XG = "sim/cockpit2/gauges/indicators/"
local XR = "sim/cockpit2/radios/indicators/"

-- key, ToLiss datarefs (first one found wins), stock X-Plane fallbacks.
-- Names come from the ToLiss dataref list; the ones whose unit or sign could
-- not be confirmed from the name alone are marked (?) and appear in the
-- diagnostics readout so they can be checked in the sim.
local INPUTS = {
    { "ias",       { "AirbusFBW/IASCapt" },                     { XG .. "airspeed_kts_pilot" } },
    { "mach",      { "AirbusFBW/MachCapt" },                    { "sim/flightmodel/misc/machno" } },
    { "show_mach", { "AirbusFBW/ShowMachCapt" },                {} },
    { "alt",       { "AirbusFBW/ALTCapt" },                     { XG .. "altitude_ft_pilot" } },
    { "hdg",       { "AirbusFBW/HDGCapt" },                     { "sim/flightmodel/position/mag_psi" } },
    { "pitch",     { PF .. "captain/pitch_angle" },             { "sim/flightmodel/position/theta" } },
    { "roll",      { PF .. "captain/roll_angle" },              { "sim/flightmodel/position/phi" } },
    { "vs",        { PF .. "captain/vertical_speed" },          { "sim/flightmodel/position/vh_ind_fpm" } },
    { "fpa",       { PF .. "captain/flight_path_angle" },       {} },
    { "drift",     { PF .. "captain/drift_angle" },             {} },
    { "ias_trend", { "AirbusFBW/IASTrendCapt" },                {} },                                  -- (?) kt in 10 s
    { "ias_acc",   {},                                          { XG .. "airspeed_acceleration_kts_sec_pilot" } },
    { "v_ias",     { "AirbusFBW/CaptIASValid" },                {} },                                  -- (?) 1 = valid
    { "v_alt",     { "AirbusFBW/CaptALTValid" },                {} },
    { "v_att",     { "AirbusFBW/CaptATTValid" },                {} },
    { "v_hdg",     { "AirbusFBW/CaptHDGValid" },                {} },
    { "vls",       { PF .. "general/VLS_value", "AirbusFBW/VLS" },          {} },                       -- (?) kt
    { "vmax",      { PF .. "general/VMax_value", "AirbusFBW/VMO" },         {} },
    { "vaprot",    { PF .. "general/VAProt_value" },            {} },
    { "valpha",    { PF .. "general/VAlphaMax_value", PF .. "general/VSW_value" }, {} },
    { "vgd",       { PF .. "general/VGreenDot_value", "AirbusFBW/VGreenDot" },     {} },
    { "show_to",   { PF .. "general/show_to_speeds" },          {} },
    { "v1",        { "toliss_airbus/performance/V1" },          {} },
    { "vr",        { PF .. "general/VR_value", "toliss_airbus/performance/VR" },   {} },
    { "spd_tgt",   { PF .. "general/ap_speed_value" },          {} },                                  -- (?) kt, or Mach if < 2
    { "spd_man",   { "AirbusFBW/SPDmanaged" },                  {} },
    { "spd_dash",  { "AirbusFBW/SPDdashed" },                   {} },
    { "alt_tgt",   { PF .. "general/ap_alt_target_value" },     {} },                                  -- (?) ft
    { "hdg_sel_t", { "AirbusFBW/APHDG_Capt" },                  {} },
    { "hdg_sel_x", {}, { "sim/cockpit2/autopilot/heading_dial_deg_mag_pilot" } },
    { "hdg_man",   { "AirbusFBW/HDGmanaged" },                  {} },
    { "hdg_dash",  { "AirbusFBW/HDGdashed" },                   {} },
    { "hdg_trk",   { "AirbusFBW/HDGTRKmode" },                  {} },
    { "fd1",       { "AirbusFBW/FD1Engage" },                   {} },
    { "fd_pitch",  { PF .. "general/fd1_pitch_cmd" },           {} },                                  -- (?) deg, relative
    { "fd_roll",   { PF .. "general/fd1_roll_cmd" },            {} },                                  -- (?) deg, relative
    { "ap1",       { "AirbusFBW/AP1Engage" },                   {} },
    { "ap2",       { "AirbusFBW/AP2Engage" },                   {} },
    { "athr",      { "AirbusFBW/ATHRmode" },                    {} },
    -- ILS sources are read separately so the panel can select/compare them.
    { "ils_on_t",  { "AirbusFBW/ILSonCapt" },                    {} },
    { "ils_crs_t", { "AirbusFBW/ILSCrs" },                       {} },
    { "loc_on_t",  { "AirbusFBW/LOConCapt" },                    {} },
    { "loc_val_t", { "AirbusFBW/LOCvalCapt" },                   {} }, -- assumed dots; verify in ToLiss build
    { "gs_on_t",   { "AirbusFBW/GSonCapt" },                     {} },
    { "gs_val_t",  { "AirbusFBW/GSvalCapt" },                    {} }, -- assumed dots; verify in ToLiss build
    { "loc_on_x",  {}, { XR .. "hsi_display_horizontal_pilot" } },
    { "loc_val_x", {}, { XR .. "hsi_hdef_dots_pilot" } },
    { "gs_on_x",   {}, { XR .. "hsi_display_vertical_pilot" } },
    { "gs_val_x",  {}, { XR .. "hsi_vdef_dots_pilot" } },
    { "hdg_rel_trk", { "AirbusFBW/APHDGreltoTRK" },              {} },
    { "ralt",      {},                                          { XG .. "radio_altimeter_height_ft_pilot" } },
    { "ralt_amber",{ PF .. "captain/ralt_is_amber" },           {} },
    { "dh",        { "toliss_airbus/performance/DH" },          {} },
    { "baro_std",  { "AirbusFBW/BaroStdCapt" },                 {} },
    { "baro_unit", { "AirbusFBW/BaroUnitCapt" },                {} },                                  -- (?) 1 = inHg
    { "baro_hg",   {},                                          { "sim/cockpit2/gauges/actuators/barometer_setting_in_hg_pilot" } },
    { "slip",      {},                                          { XG .. "slip_deg" } },
    { "gs_kt",     {},                                          { XG .. "ground_speed_kt" } },
    { "gear",      { "AirbusFBW/GearLever" },                   { "sim/cockpit/switches/gear_handle_status" } },
    { "flap_lvr",  { "AirbusFBW/FlapRequestPos" },              {} },                                  -- (?) 0..4
    { "flap_rat",  {},                                          { "sim/cockpit2/controls/flap_handle_deploy_ratio" } },
    { "agl",       {},                                          { "sim/flightmodel/position/y_agl" } },
    { "psi_true",  {},                                          { "sim/flightmodel/position/psi" } },
    { "vx",        {},                                          { "sim/flightmodel/position/local_vx" } },
    { "vy",        {},                                          { "sim/flightmodel/position/local_vy" } },
    { "vz",        {},                                          { "sim/flightmodel/position/local_vz" } },
    { "view_ext",  {},                                          { "sim/graphics/view/view_is_external" } },
    { "running",   {},                                          { "sim/time/total_running_time_sec" } },
}

local D, SRC, SRC_PATH, SRC_TYPE = {}, {}, {}, {} -- values and selected source metadata

local function read_inputs()
    for i = 1, #INPUTS do
        local e = INPUTS[i]
        local val, src, selected_path, selected_type = nil, "-", nil, nil
        local tl, xp = e[2], e[3]
        for j = 1, #tl do
            local path = tl[j]
            local r = ref(path)
            local getter = r and scalar_reader(path, r)
            if getter then
                val = getter(r); src = "T"; selected_path = path
                selected_type = scalar_readers[path] and scalar_readers[path].kind
                break
            end
        end
        if val == nil then
            for j = 1, #xp do
                local path = xp[j]
                local r = ref(path)
                local getter = r and scalar_reader(path, r)
                if getter then
                    val = getter(r); src = "X"; selected_path = path
                    selected_type = scalar_readers[path] and scalar_readers[path].kind
                    break
                end
            end
        end
        if val ~= nil and (val ~= val or val == math.huge or val == -math.huge) then val = nil end
        D[e[1]] = val
        SRC[e[1]] = src
        SRC_PATH[e[1]] = selected_path
        SRC_TYPE[e[1]] = selected_type
    end

    -- Select the FCU heading/track target.  ToLiss' APHDG_Capt has no public
    -- unit/reference description in the community dataref inventory; X-Plane's
    -- standard pilot dial is explicitly a magnetic heading in degrees.  Keep
    -- both selectable because some aircraft builds may only update one source.
    local target, target_src
    if cfg.hdg_sel_source == "xplane" then
        target, target_src = D.hdg_sel_x, (D.hdg_sel_x ~= nil and "X" or "-")
        if target == nil then target, target_src = D.hdg_sel_t, (D.hdg_sel_t ~= nil and "T*" or "-") end
    elseif cfg.hdg_sel_source == "toliss" then
        target, target_src = D.hdg_sel_t, (D.hdg_sel_t ~= nil and "T" or "-")
        if target == nil then target, target_src = D.hdg_sel_x, (D.hdg_sel_x ~= nil and "X*" or "-") end
    else
        -- Auto prefers the documented X-Plane magnetic heading dial.  ToLiss
        -- remains the fallback when that standard dataref is unavailable.
        target, target_src = D.hdg_sel_x, (D.hdg_sel_x ~= nil and "X" or "-")
        if target == nil then target, target_src = D.hdg_sel_t, (D.hdg_sel_t ~= nil and "T" or "-") end
    end
    if target ~= nil then
        D.hdg_sel = wrap360(target + (cfg.hdg_sel_offset or 0))
    else
        D.hdg_sel = nil
    end
    SRC.hdg_sel = target_src

    -- Pick a complete ILS deviation source.  Do not combine the LOC from one
    -- receiver with the G/S from another: each axis is selected as a pair.
    local t_loc_ok = (D.loc_on_t or 0) > 0.5 and D.loc_val_t ~= nil
    local t_gs_ok  = (D.gs_on_t or 0) > 0.5 and D.gs_val_t ~= nil
    local x_loc_ok = (D.loc_on_x or 0) > 0.5 and D.loc_val_x ~= nil
    local x_gs_ok  = (D.gs_on_x or 0) > 0.5 and D.gs_val_x ~= nil
    local use_t = false
    if cfg.ils_source == "toliss" then
        use_t = true
    elseif cfg.ils_source == "xplane" then
        use_t = false
    else
        use_t = t_loc_ok or t_gs_ok
    end
    if use_t then
        D.loc_on, D.loc_val = D.loc_on_t, D.loc_val_t
        D.gs_on, D.gs_val = D.gs_on_t, D.gs_val_t
        SRC.loc_on, SRC.loc_val = SRC.loc_on_t, SRC.loc_val_t
        SRC.gs_on, SRC.gs_val = SRC.gs_on_t, SRC.gs_val_t
    else
        D.loc_on, D.loc_val = D.loc_on_x, D.loc_val_x
        D.gs_on, D.gs_val = D.gs_on_x, D.gs_val_x
        SRC.loc_on, SRC.loc_val = SRC.loc_on_x, SRC.loc_val_x
        SRC.gs_on, SRC.gs_val = SRC.gs_on_x, SRC.gs_val_x
    end
    D.ils_on = D.ils_on_t
    D.ils_crs = D.ils_crs_t
    SRC.ils_on, SRC.ils_crs = SRC.ils_on_t, SRC.ils_crs_t

    -- horizontal ground speed from the sim's inertial velocity (OpenGL +Z is south)
    local vn, ve = -(D.vz or 0), (D.vx or 0)
    D.gs_ms = math.sqrt(vn * vn + ve * ve)
end

-- String datarefs (the FMA lines).  Read through FlyWithLua's dataref()
-- binding, created only once the dataref actually exists.
local str_vars, str_n = {}, 0
local function read_str(path)
    local v = str_vars[path]
    if v == nil then
        if not ref(path) then return nil end
        str_n = str_n + 1
        local name = "xa32_s_" .. str_n
        local ok, err = pcall(dataref, name, path, "readonly")
        if ok then
            str_vars[path] = name
        else
            str_vars[path] = false
            logMsg("XPHUD A32X: cannot bind string dataref " .. path .. " : " .. tostring(err))
        end
        v = str_vars[path]
    end
    if not v then return nil end
    local s = _G[v]
    if type(s) ~= "string" then return nil end
    return (s:gsub("[^\32-\126]", " "))
end

-- ------------------------------------------------------ diagnostic capture --
-- Manual snapshots and a low-rate CSV recorder. No simulator datarefs are
-- written. Collection is opt-in and files are saved under Output/preferences.
local diag_recording = false
local diag_last_sample = 0
local diag_sample_id = 0
local diag_file_path = nil
local diag_error = nil
local DIAG_AIRCRAFT_PROFILE = "ToLiss A320neo standard (latest installed; exact build not yet captured)"
local DIAG_FMA_LAYERS = { { "g", "w", "b" }, { "b", "m", "w" }, { "a", "b", "w" } }

local function csv_cell(v)
    if v == nil then return "" end
    local s = tostring(v)
    if s:find('[,\r\n"]') then return '"' .. s:gsub('"', '""') .. '"' end
    return s
end

local function diag_new_path()
    local base = (SYSTEM_DIRECTORY or "") .. "Output/preferences/"
    local stamp = os.date("%Y%m%d_%H%M%S")
    local path = base .. "XPHUD_A32X_diag_" .. stamp .. ".csv"
    local suffix = 1
    while true do
        local f = io.open(path, "r")
        if not f then return path end
        f:close()
        path = base .. "XPHUD_A32X_diag_" .. stamp .. "_" .. suffix .. ".csv"
        suffix = suffix + 1
    end
end

local DIAG_HEADER = table.concat({
    "sample_id", "local_time", "sim_running_time_s", "xphud_version",
    "aircraft_profile", "sample_kind", "hud_key", "provider", "dataref_path",
    "xplm_type_mask", "reader_type", "raw_value", "text_value",
    "selected_input_path", "input_source"
}, ",")

local function diag_write_line(path, line, mode)
    local f, err = io.open(path, mode or "a")
    if not f then diag_error = tostring(err); return false end
    local ok, werr = f:write(line, "\n")
    local cok, cerr = f:close()
    if not ok or not cok then diag_error = tostring(werr or cerr); return false end
    return true
end

local function diag_capture(kind)
    -- Refresh the sample even when the HUD overlay itself is hidden.
    read_inputs()
    if not diag_file_path then
        diag_file_path = diag_new_path()
        if not diag_write_line(diag_file_path, DIAG_HEADER, "w") then
            diag_file_path = nil
            return false
        end
    end
    diag_sample_id = diag_sample_id + 1
    local sample_id = diag_sample_id
    local local_time = os.date("%Y-%m-%d %H:%M:%S")
    local sim_time = D.running
    local rows = {}
    local function add_row(key, provider, path, raw, text_value, type_mask, reader_type, selected)
        rows[#rows + 1] = table.concat({
            csv_cell(sample_id), csv_cell(local_time), csv_cell(sim_time),
            csv_cell(EDITION), csv_cell(DIAG_AIRCRAFT_PROFILE), csv_cell(kind),
            csv_cell(key), csv_cell(provider), csv_cell(path), csv_cell(type_mask),
            csv_cell(reader_type), csv_cell(raw), csv_cell(text_value),
            csv_cell(selected and "1" or "0"), csv_cell(SRC[key])
        }, ",")
    end

    for i = 1, #INPUTS do
        local e = INPUTS[i]
        local key = e[1]
        for _, group in ipairs({ { "T", e[2] }, { "X", e[3] } }) do
            local provider, paths = group[1], group[2]
            for j = 1, #paths do
                local path = paths[j]
                local handle = ref(path)
                local mask, value, reader_type
                if handle and type(XPLMGetDataRefTypes) == "function" then
                    local ok, result = pcall(XPLMGetDataRefTypes, handle)
                    if ok then mask = result end
                end
                if handle then
                    local getter = scalar_reader(path, handle)
                    if getter then
                        local ok, result = pcall(getter, handle)
                        if ok and type(result) == "number"
                            and result == result and result ~= math.huge and result ~= -math.huge then
                            value = result
                        end
                        reader_type = scalar_readers[path] and scalar_readers[path].kind
                    end
                end
                add_row(key, provider, path, value, nil, mask, reader_type,
                        SRC_PATH[key] == path)
            end
        end
    end

    -- FMA values are strings and are deliberately recorded separately from
    -- scalar DataRefs, preserving the exact path/layer and readable text.
    for i = 1, 3 do
        for _, layer in ipairs(DIAG_FMA_LAYERS[i]) do
            local path = "AirbusFBW/FMA" .. i .. layer
            local value = read_str(path)
            add_row("fma" .. i .. layer, "T", path, nil, value, "string", "string", false)
        end
    end

    for i = 1, #rows do
        if not diag_write_line(diag_file_path, rows[i], "a") then return false end
    end
    diag_error = nil
    return true
end

local function diag_start_recording()
    if diag_recording then return end
    diag_file_path = nil
    diag_sample_id = 0
    if diag_capture("record_start") then
        diag_recording = true
        diag_last_sample = os.time()
    end
end

local function diag_stop_recording()
    if not diag_recording then return end
    diag_capture("record_stop")
    diag_recording = false
end

local function diag_tick()
    if not diag_recording then return end
    local now = os.time()
    if now > diag_last_sample then
        diag_last_sample = now
        diag_capture("record")
    end
end

local function diag_snapshot()
    -- Append to the active session when recording; otherwise create a
    -- standalone file. A manual snapshot must not interrupt a recording.
    if not diag_file_path then diag_sample_id = 0 end
    return diag_capture("snapshot")
end

-- ----------------------------------------------------------------- state --

local settings_open  = false
local settings_wnd   = nil
local settings_dirty = false
local have_visible_dr = false
local vis_primed     = false
local vis_last       = nil
local draw_error_count = 0

-- ---------------------------------------------------------- persistence --
-- The preferences file is plain key=value text.  It carries a format version
-- (prefs_version) so a renamed or re-purposed setting can be migrated instead
-- of silently reinterpreted, and it is replaced atomically on save so a crash
-- or full disk cannot leave a half-written file in place of the old one.

local PREFS_VERSION = 2
local PREFS_END_MARK = "# end of preferences"

-- PREF_MIGRATIONS[n] upgrades the raw (string-valued) table from version n to
-- n + 1.  Files written before versioning existed are treated as version 1.
local PREF_MIGRATIONS = {
    [1] = function(raw)
        -- 2.3.0: the 2D "mount stand-off" strut length was replaced by the
        -- eye-to-combiner distance, and the hardware was redrawn as an
        -- overhead unit.  Drop the old key and move the old default opacity
        -- (0.72) to the new default instead of keeping a ghostly frame.
        raw.mount_standoff_cm = nil
        if tonumber(raw.hardware_alpha) == 0.72 then raw.hardware_alpha = nil end
        return raw
    end,
}

local function migrate_prefs(raw, version)
    local v = tonumber(version) or 1
    while v < PREFS_VERSION do
        local step = PREF_MIGRATIONS[v]
        if step then raw = step(raw) or raw end
        v = v + 1
    end
    return raw
end

local function prefs_file()
    local base = SYSTEM_DIRECTORY or ""
    return base .. "Output/preferences/xphud_toliss_a32x.prefs"
end

-- Write `text` to `path` through a temporary file.  os.rename() replaces an
-- existing file on macOS / Linux but not on Windows, so a failed rename is
-- retried after removing the old file; the last resort is a plain overwrite.
local function write_file_atomic(path, text)
    local tmp = path .. ".tmp"
    local f, err = io.open(tmp, "w")
    if not f then return false, err end
    local w_ok, w_err = f:write(text)
    local c_ok, c_err = f:close()
    if not w_ok or not c_ok then
        os.remove(tmp)
        return false, w_err or c_err or "write failed"
    end
    if os.rename(tmp, path) then return true end
    os.remove(path)
    if os.rename(tmp, path) then return true end
    os.remove(tmp)
    local g, gerr = io.open(path, "w")
    if not g then return false, gerr end
    local ok, perr = g:write(text)
    local cl_ok, cl_err = g:close()
    if not ok or not cl_ok then return false, perr or cl_err or "write failed" end
    return true
end

local function save_prefs()
    local ok, err = pcall(function()
        local lines = {
            "# " .. EDITION .. " preferences - edit via the in-sim settings window\n",
            string.format("prefs_version=%d\n", PREFS_VERSION),
        }
        local keys = {}
        for k in pairs(DEFAULTS) do keys[#keys + 1] = k end
        table.sort(keys)
        for _, k in ipairs(keys) do
            lines[#lines + 1] = string.format("%s=%s\n", k, tostring(cfg[k]))
        end
        lines[#lines + 1] = PREFS_END_MARK .. "\n"
        local w_ok, w_err = write_file_atomic(prefs_file(), table.concat(lines))
        if not w_ok then error(w_err or "could not write preferences file") end
    end)
    if not ok then
        logMsg("XPHUD A32X: preferences save error: " .. tostring(err))
    end
end

-- Validate one raw string value against the type / range / options of its default.
local function apply_pref(k, v)
    local dv = DEFAULTS[k]
    if type(dv) == "boolean" then
        if v == "true" or v == "false" then
            cfg[k] = (v == "true")
        else
            logMsg("XPHUD A32X: invalid boolean preference '" .. k .. "'; using default")
        end
    elseif type(dv) == "number" then
        local n = tonumber(v)
        local bounds = PREF_BOUNDS[k]
        if not n or n ~= n or n == math.huge or n == -math.huge then
            logMsg("XPHUD A32X: invalid numeric preference '" .. k .. "'; using default")
        elseif bounds and (n < bounds[1] or n > bounds[2]) then
            logMsg("XPHUD A32X: out-of-range preference '" .. k .. "'; clamping to supported range")
            cfg[k] = math.max(bounds[1], math.min(bounds[2], n))
        else
            cfg[k] = n
        end
    else
        local options = PREF_OPTIONS[k]
        if not options or options[v] then
            cfg[k] = v
        else
            logMsg("XPHUD A32X: invalid option preference '" .. k .. "'; using default")
        end
    end
end

local function load_prefs()
    local ok, err = pcall(function()
        local f = io.open(prefs_file(), "r")
        if not f then return end
        local raw, saw_end, any = {}, false, false
        for line in f:lines() do
            if line == PREFS_END_MARK then saw_end = true end
            local k, v = line:match("^([%w_]+)=(.*)$")
            if k then raw[k] = v; any = true end
        end
        f:close()
        if any and not saw_end then
            logMsg("XPHUD A32X: preferences file has no end marker (older version or interrupted "
                .. "write); using every valid entry")
        end
        local version = tonumber(raw.prefs_version) or 1
        raw.prefs_version = nil
        if version > PREFS_VERSION then
            logMsg("XPHUD A32X: preferences were written by a newer version; unknown keys are ignored")
        end
        raw = migrate_prefs(raw, version)
        for k, v in pairs(raw) do
            if DEFAULTS[k] ~= nil then apply_pref(k, v) end
        end
    end)
    if not ok then
        logMsg("XPHUD A32X: preferences load error: " .. tostring(err))
    end
end

load_prefs()

-- --------------------------------------------------------------- helpers --

local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

local function smoothstep(t)
    t = clamp(t, 0, 1)
    return t * t * (3 - 2 * t)
end

local function ival(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    return math.floor(v + 0.5)
end

local function istr(v, fmt)
    local n = ival(v)
    if not n then return "--" end
    return string.format(fmt or "%d", n)
end

local function flash(period)    -- ~62% duty square wave, `period` seconds
    return ((D.running or 0) % (period or 0.8)) < (period or 0.8) * 0.62
end

-- ------------------------------------------------- 2D primitives (y-flip) --
-- Geometry is written top-left / y-down; FlyWithLua's screen is bottom-left /
-- y-up, so every primitive converts once with fy(y) = SCREEN_HIGHT - y.

local SH = 0
local MASTER_A = 1.0
local function fy(y) return SH - y end

local function C(col, a) graphics.set_color(col[1], col[2], col[3], (a or 1.0) * MASTER_A) end

local function d_line(x1, y1, x2, y2, col, w)
    C(col); graphics.set_width(w or 1); graphics.draw_line(x1, fy(y1), x2, fy(y2))
end
local function d_line_a(x1, y1, x2, y2, col, w, a)
    C(col, a); graphics.set_width(w or 1); graphics.draw_line(x1, fy(y1), x2, fy(y2))
end
local function d_tri_f(x1, y1, x2, y2, x3, y3, col, a)
    C(col, a); graphics.draw_triangle(x1, fy(y1), x2, fy(y2), x3, fy(y3))
end
local function d_tri(x1, y1, x2, y2, x3, y3, col, w)
    d_line(x1, y1, x2, y2, col, w); d_line(x2, y2, x3, y3, col, w); d_line(x3, y3, x1, y1, col, w)
end
local function d_quad(x1, y1, x2, y2, x3, y3, x4, y4, col, w)
    d_line(x1, y1, x2, y2, col, w); d_line(x2, y2, x3, y3, col, w)
    d_line(x3, y3, x4, y4, col, w); d_line(x4, y4, x1, y1, col, w)
end
local function d_quad_f(x1, y1, x2, y2, x3, y3, x4, y4, col, a)
    d_tri_f(x1, y1, x2, y2, x3, y3, col, a); d_tri_f(x1, y1, x3, y3, x4, y4, col, a)
end
local function d_circle(x, y, r, col, w)
    C(col); graphics.draw_circle(x, fy(y), r, w or 1)
end
local function d_circle_f(x, y, r, col, a)
    C(col, a); graphics.draw_filled_circle(x, fy(y), r)
end

-- ------------------------------------------------------------ HUD text --
-- FlyWithLua only offers a handful of fixed bitmap fonts, so a requested text
-- scale snaps to the nearest available size.

local DS = {
    Times_Roman_24 = draw_string_Times_Roman_24,
    Helvetica_18   = draw_string_Helvetica_18,
    Helvetica_12   = draw_string_Helvetica_12,
    Helvetica_10   = draw_string_Helvetica_10,
}
for name, fn in pairs(DS) do
    if type(fn) ~= "function" then
        logMsg("XPHUD A32X: font draw_string_" .. name .. " missing from this FlyWithLua build")
    end
end

-- cap = digit height, cw = per-character advance (estimated; measure_string
-- under-reports the big fonts in FlyWithLua).
local FONT_TIERS = {
    { name = "Times_Roman_24", h = 24, cap = 17, cw = 13, min = 22 },
    { name = "Helvetica_18",   h = 18, cap = 14, cw = 10, min = 15 },
    { name = "Helvetica_12",   h = 12, cap = 9,  cw = 7,  min = 11 },
    { name = "Helvetica_10",   h = 10, cap = 7,  cw = 6,  min = 0  },
}

local function font_for(scale)
    local px = scale * cfg.text_scale * 12
    for _, t in ipairs(FONT_TIERS) do
        if px >= t.min then return DS[t.name], t.name, t.h, t.cap, t.cw end
    end
    local t = FONT_TIERS[#FONT_TIERS]
    return DS[t.name], t.name, t.h, t.cap, t.cw
end

local function text_size(s, scale)
    local _, _, fh, _, cw = font_for(scale)
    return #s * cw, fh
end

-- x = anchor; align -1 left edge at x, 0 centred, 1 right edge at x.
-- y = TOP of the text.  plate = dark backing box.  Returns the line height.
local function draw_text(x, y, s, color, scale, align, plate)
    local fn, _, fh, cap, cw = font_for(scale)
    if type(fn) ~= "function" then return fh end
    local tw = #s * cw
    local px = x
    if align == 0 then px = x - tw / 2 elseif align == 1 then px = x - tw end
    local by = fy(y) - fh

    if plate and cfg.plate_alpha > 0.01 then
        local p = 4 + fh / 12
        local m = 3
        local pt = y + fh - cap - m
        local pb = y + fh + m
        d_quad_f(px - p, pt, px + tw + p, pt,
                 px + tw + p, pb, px - p, pb, {0, 0, 0}, cfg.plate_alpha)
    end
    -- FlyWithLua's draw_string_<font>(x, y, text) renders in the CURRENT GL
    -- colour and carries no alpha, so master opacity dims brightness instead.
    local tb = 0.55 + 0.45 * MASTER_A
    graphics.set_color(color[1] * tb, color[2] * tb, color[3] * tb, 1.0)
    fn(px, by, s)
    return fh
end

-- y of the TOP of a text line so that its digits are vertically centred on yc
local function text_top_centred(yc, scale)
    local _, _, fh, cap = font_for(scale)
    return yc - fh + cap / 2
end

local function rot_pt(cx, cy, dx, dy, s, c)
    return cx + dx * c - dy * s, cy + dx * s + dy * c
end

-- ------------------------------------------------------------- elements --

local function draw_center(cx, cy, S, th)
    local half, leg = 0.035 * S, 0.016 * S
    for _, sx in ipairs({-1, 1}) do
        for _, sy in ipairs({-1, 1}) do
            local x, y = cx + sx * half, cy + sy * half
            d_line(x, y, x - sx * leg, y, COL.center, th)
            d_line(x, y, x, y - sy * leg, COL.center, th)
        end
    end
end

-- Horizon line + pitch ladder.  Rungs are generated around the current pitch,
-- so any attitude is covered; the visible window is limited to +-0.28 * S.
local function draw_horizon(cx, cy, S, k, th, pitch, roll)
    local ppd = 0.4 * S / math.max(cfg.ladder_deg, 1)
    local a = math.rad(-roll)
    local s, c = math.sin(a), math.cos(a)
    local lth = math.max(1, th * 0.7)
    local lim = 0.28 * S

    local function ladder_line(x1, y1, x2, y2)
        local px1, py1 = rot_pt(cx, cy, x1, y1, s, c)
        local px2, py2 = rot_pt(cx, cy, x2, y2, s, c)
        d_line(px1, py1, px2, py2, COL.ladder, lth)
    end

    local hy = pitch * ppd
    if math.abs(hy) < lim then
        ladder_line(-0.26 * S, hy, -0.07 * S, hy)
        ladder_line(0.07 * S, hy, 0.26 * S, hy)
    end
    local base = math.floor(pitch / 5 + 0.5) * 5
    for deg = base - 20, base + 20, 5 do
        if deg ~= 0 and deg >= -90 and deg <= 90 then
            local ry = (pitch - deg) * ppd
            if math.abs(ry) < lim then
                local hw = (deg % 10 == 0) and 0.14 * S or 0.09 * S
                if deg > 0 then
                    ladder_line(-hw, ry, -0.05 * S, ry)
                    ladder_line(0.05 * S, ry, hw, ry)
                else
                    for _, sx in ipairs({-1, 1}) do
                        local x0, x1 = sx * 0.05 * S, sx * hw
                        for seg = 0, 2 do
                            local a0 = x0 + (x1 - x0) * (seg * 2) / 5
                            local a1 = x0 + (x1 - x0) * (seg * 2 + 1) / 5
                            ladder_line(a0, ry, a1, ry)
                        end
                    end
                end
                if deg % 10 == 0 then
                    local lx, ly = rot_pt(cx, cy, hw + 0.012 * S, ry, s, c)
                    draw_text(lx, text_top_centred(ly, 0.9 * k), string.format("%d", math.abs(deg)),
                              COL.ladder, 0.9 * k, -1)
                end
            end
        end
    end
end

-- Roll scale (arc ticks + sky pointer) with the slip trapezoid.
local function draw_bank(cx, cy, S, k, th, roll, slip)
    local R = 0.30 * S
    for _, t in ipairs({-60, -45, -30, -20, -10, 0, 10, 20, 30, 45, 60}) do
        local tr = math.rad(t)
        local len = (t == 0 or math.abs(t) >= 45) and 0.03 * S or 0.018 * S
        local sx, sy = math.sin(tr), -math.cos(tr)
        d_line(cx + sx * R, cy + sy * R, cx + sx * (R + len), cy + sy * (R + len), COL.ladder, th * 0.8)
    end
    local a = math.rad(-roll)
    local s, c = math.sin(a), math.cos(a)
    local w = 0.014 * S
    local ax, ay = rot_pt(cx, cy, 0, -R, s, c)
    local b1x, b1y = rot_pt(cx, cy, -w, -R + 2 * w, s, c)
    local b2x, b2y = rot_pt(cx, cy, w, -R + 2 * w, s, c)
    d_tri_f(ax, ay, b1x, b1y, b2x, b2y, COL.center)
    local sl = clamp((slip or 0) / 8, -1.5, 1.5) * 2 * w
    local t1x, t1y = rot_pt(cx, cy, -w - sl, -R + 2.4 * w, s, c)
    local t2x, t2y = rot_pt(cx, cy, w - sl, -R + 2.4 * w, s, c)
    local t3x, t3y = rot_pt(cx, cy, w * 1.3 - sl, -R + 3.4 * w, s, c)
    local t4x, t4y = rot_pt(cx, cy, -w * 1.3 - sl, -R + 3.4 * w, s, c)
    d_quad_f(t1x, t1y, t2x, t2y, t3x, t3y, t4x, t4y, COL.center)
end

-- Flight path vector: inertial velocity vector on the pitch ladder.  Vertical =
-- flight path angle, lateral = drift (track minus heading), both roll-stabilised
-- with the same scale and rotation as the ladder.
local function fpv_angles()
    if (D.gs_ms or 0) < 2.5 then return nil end                 -- taxi jitter deadband
    if cfg.fpv_src ~= "xplane" and D.fpa ~= nil and D.drift ~= nil then
        return D.fpa, D.drift
    end
    local gs = D.gs_ms
    local gamma = math.deg(atan2(D.vy or 0, gs))
    local track = math.deg(atan2(D.vx or 0, -(D.vz or 0)))
    local drift = wrap180(track - (D.psi_true or 0))
    return gamma, drift
end

local function draw_fpv(cx, cy, S, k, th, pitch, roll, gamma, drift)
    local ppd = 0.4 * S / math.max(cfg.ladder_deg, 1)
    local a = math.rad(-roll)
    local s, c = math.sin(a), math.cos(a)
    local dx = clamp(drift, -15, 15) * ppd
    local dy = clamp((pitch - gamma) * ppd, -0.27 * S, 0.27 * S)
    local x, y = rot_pt(cx, cy, dx, dy, s, c)
    local function lp(ox, oy) return rot_pt(x, y, ox, oy, s, c) end
    local r = 0.02 * S
    d_circle(x, y, r, COL.fpv, th)
    local x1, y1 = lp(r, 0)
    local x2, y2 = lp(3 * r, 0)
    d_line(x1, y1, x2, y2, COL.fpv, th)             -- right wing
    x1, y1 = lp(-r, 0)
    x2, y2 = lp(-3 * r, 0)
    d_line(x1, y1, x2, y2, COL.fpv, th)             -- left wing
    x1, y1 = lp(0, -r)
    x2, y2 = lp(0, -2 * r)
    d_line(x1, y1, x2, y2, COL.fpv, th)             -- fin
end

-- Flight director guidance cue.  Drawn against the boresight (aircraft
-- reference): fly the boresight onto the cue.  Orders are taken as degrees
-- relative to the aircraft, +pitch = pull up, +roll = roll right.
local function draw_fd(cx, cy, S, k, th)
    if (D.fd1 or 0) ~= 1 or D.fd_pitch == nil or D.fd_roll == nil then return end
    local ppd = 0.4 * S / math.max(cfg.ladder_deg, 1)
    local sp = cfg.inv_fd_pitch and -1 or 1
    local sr = cfg.inv_fd_roll and -1 or 1
    local dy = clamp(-D.fd_pitch * sp * ppd, -0.22 * S, 0.22 * S)
    local dx = clamp(D.fd_roll * sr * (0.4 * S / math.max(cfg.fd_roll_deg, 1)), -0.22 * S, 0.22 * S)
    local x, y = cx + dx, cy + dy
    local r = 0.016 * S
    d_circle(x, y, r, COL.fd, th)
    d_line(x - r * 0.55, y, x + r * 0.55, y, COL.fd, th * 0.8)
    d_line(x, y - r * 0.55, x, y + r * 0.55, COL.fd, th * 0.8)
end

-- Vertical tape.  side = -1 speed (left), +1 altitude (right).  The scale spine
-- is the edge nearest the HUD centre; ticks and numbers sit outboard of it.
local TAPE_HALF = 0.25      -- half height of the tape window, in HUD sizes
local TAPE_X    = 0.335     -- spine distance from the centre, in HUD sizes

local function readout_box(cx, cy, S, k, th, side, txt, widest)
    local tw, fh = text_size(widest, 1.3 * k)
    local bw = math.max(0.10 * S, tw + 16)
    local bh = fh + 12
    local xin = cx + side * TAPE_X * S
    local xout = xin + side * bw
    d_line(xin, cy - bh / 2, xout, cy - bh / 2, COL.box, th)
    d_line(xout, cy - bh / 2, xout, cy + bh / 2, COL.box, th)
    d_line(xout, cy + bh / 2, xin, cy + bh / 2, COL.box, th)
    -- pointer on the inner side, pointing at the HUD centre
    local p = 0.016 * S
    d_line(xin, cy - bh / 2, xin - side * p, cy, COL.box, th)
    d_line(xin - side * p, cy, xin, cy + bh / 2, COL.box, th)
    draw_text(xin + side * bw / 2, text_top_centred(cy, 1.3 * k), txt, COL.text, 1.3 * k, 0, true)
    return bh
end

local function draw_tape(cx, cy, S, k, th, side, value, ppu, step, lstep, bh)
    local half = TAPE_HALF * S
    local xin = cx + side * TAPE_X * S
    d_line(xin, cy - half, xin, cy + half, COL.box, th * 0.8)
    local lo, hi = value - half / ppu, value + half / ppu
    local v = math.ceil(lo / step) * step
    local guard = 0
    while v <= hi and guard < 300 do
        guard = guard + 1
        local y = cy - (v - value) * ppu
        if math.abs(y - cy) > bh / 2 + 3 then
            local major = (v % lstep) == 0
            local len = (major and 0.022 or 0.012) * S
            d_line(xin, y, xin + side * len, y, COL.box, th * 0.8)
            if major then
                draw_text(xin + side * (len + 4 * k), text_top_centred(y, 0.9 * k),
                          string.format("%d", math.floor(v + 0.5)), COL.box, 0.9 * k, (side == -1) and 1 or -1)
            end
        end
        v = v + step
    end
    return xin
end

-- hollow (selected) / filled (managed) target bug on the inner side of the spine
local function draw_bug(xin, side, y, S, th, filled)
    local b, hw = 0.022 * S, 0.012 * S
    local bx = xin - side * b
    if filled then
        d_tri_f(xin, y, bx, y - hw, bx, y + hw, COL.bug)
    end
    d_tri(xin, y, bx, y - hw, bx, y + hw, COL.bug, th)
end

local function speed_mark(xin, side, y, kind, S, th)
    local L = 0.05 * S
    if kind == "dash" or kind == "dashdown" then
        for i = 0, 3 do
            local a = xin + side * (i * 0.0125 * S)
            d_line(a, y, a + side * 0.0075 * S, y, COL.box, th)
        end
    else
        d_line(xin, y, xin + side * L, y, COL.box, th)
    end
    if kind == "up" or kind == "down" or kind == "dashdown" then
        local dir = (kind == "up") and -1 or 1
        for i = 1, 4 do
            local a = xin + side * (i * 0.011 * S)
            d_line(a, y, a - side * 0.006 * S, y + dir * 0.012 * S, COL.box, th * 0.7)
        end
    end
end

local function draw_speed(cx, cy, S, k, th)
    local ias = D.ias or 0
    local v = math.max(ias, 30)
    local ppu = TAPE_HALF * S / math.max(cfg.spd_range_kt, 10)
    local half = TAPE_HALF * S
    local txt = (ias >= 30) and istr(ias) or "---"
    local bh = select(2, text_size("0", 1.3 * k)) + 12
    local xin = draw_tape(cx, cy, S, k, th, -1, v, ppu, 10, 20, bh)
    local function Y(s) return cy - (s - v) * ppu end
    local function inwin(y) return y >= cy - half and y <= cy + half end

    if cfg.show_vmarks then
        if D.vmax and D.vmax > 0 and inwin(Y(D.vmax)) then speed_mark(xin, -1, Y(D.vmax), "up", S, th) end
        if D.vls and D.vls > 0 and inwin(Y(D.vls)) then speed_mark(xin, -1, Y(D.vls), "down", S, th) end
        if D.vaprot and D.vaprot > 0 and inwin(Y(D.vaprot)) then speed_mark(xin, -1, Y(D.vaprot), "dash", S, th) end
        if D.valpha and D.valpha > 0 and inwin(Y(D.valpha)) then speed_mark(xin, -1, Y(D.valpha), "dashdown", S, th) end
        if D.vgd and D.vgd > 0 and inwin(Y(D.vgd)) then
            d_circle(xin - 0.014 * S, Y(D.vgd), 0.008 * S, COL.box, th)
        end
        if (D.show_to or 0) == 1 then
            for _, m in ipairs({ { D.v1, "V1" }, { D.vr, "VR" } }) do
                if m[1] and m[1] > 0 and inwin(Y(m[1])) then
                    local y = Y(m[1])
                    d_line(xin, y, xin - 0.03 * S, y, COL.box, th)
                    draw_text(xin + 0.008 * S, text_top_centred(y, 0.8 * k), m[2], COL.box, 0.8 * k, -1)
                end
            end
        end
    end

    -- speed trend: arrow from the current speed to the speed predicted in 10 s
    if cfg.show_trend then
        local trend = D.ias_trend
        if trend == nil and D.ias_acc ~= nil then trend = D.ias_acc * 10 end
        if trend and math.abs(trend) >= 2 and ias >= 30 then
            local y1, y2 = Y(v), Y(v + clamp(trend, -60, 60))
            local x = xin + 0.040 * S
            d_line(x, y1, x, y2, COL.trend, th)
            local ah = 0.012 * S
            local dirn = (y2 > y1) and 1 or -1
            d_line(x, y2, x - ah * 0.6, y2 - dirn * ah, COL.trend, th)
            d_line(x, y2, x + ah * 0.6, y2 - dirn * ah, COL.trend, th)
        end
    end

    -- selected / managed speed target: bug on the tape + numeric readout above
    if cfg.show_targets and D.spd_tgt ~= nil then
        local dashed = (D.spd_dash or 0) == 1
        local tgt = D.spd_tgt
        local managed = (D.spd_man or 0) == 1
        local label
        if dashed or tgt <= 0 then
            label = "---"
        elseif tgt < 2 then                                       -- Mach target
            label = string.format(".%02d", math.floor(tgt * 100 + 0.5))
            if (D.mach or 0) > 0.1 and ias >= 30 then
                local y = clamp(Y(ias * tgt / D.mach), cy - half, cy + half)
                draw_bug(xin, -1, y, S, th, managed)
            end
        else
            label = istr(tgt)
            draw_bug(xin, -1, clamp(Y(tgt), cy - half, cy + half), S, th, managed)
        end
        draw_text(xin - 0.05 * S, cy - half - 0.065 * S, label, COL.bug, 1.2 * k, 0, true)
    end

    readout_box(cx, cy, S, k, th, -1, txt, "888")
end

local function draw_alt(cx, cy, S, k, th)
    local alt = D.alt or 0
    local ppu = TAPE_HALF * S / math.max(cfg.alt_range_ft, 100)
    local half = TAPE_HALF * S
    local bh = select(2, text_size("0", 1.3 * k)) + 12
    local xin = draw_tape(cx, cy, S, k, th, 1, alt, ppu, 100, 200, bh)
    local function Y(a) return cy - (a - alt) * ppu end

    if cfg.show_targets and D.alt_tgt ~= nil then
        local tgt = D.alt_tgt
        draw_bug(xin, 1, clamp(Y(tgt), cy - half, cy + half), S, th, false)
        draw_text(xin + 0.05 * S, cy - half - 0.065 * S, istr(tgt), COL.bug, 1.2 * k, 0, true)
    end

    local shown = math.floor(alt / 20 + 0.5) * 20               -- the Airbus drum steps in 20 ft
    readout_box(cx, cy, S, k, th, 1, string.format("%d", shown), "88888")
end

local function draw_vs(cx, cy, S, k)
    local vs = D.vs
    if vs == nil or math.abs(vs) < 100 then return end
    local n = math.floor(math.abs(vs) / 50 + 0.5) * 50
    local txt = string.format("%s%d", vs >= 0 and "+" or "-", n)
    draw_text(cx + 0.39 * S, cy + 0.265 * S, txt, COL.text, 1.1 * k, 0, true)
end

local function draw_side_info(cx, cy, S, k)
    local xl, xr = cx - 0.39 * S, cx + 0.39 * S
    local y1, y2 = cy + 0.265 * S, cy + 0.315 * S
    if cfg.show_mach then
        local m = D.mach or 0
        local show
        if D.show_mach ~= nil then show = (D.show_mach == 1) else show = (m >= 0.5) end
        if show then
            local txt = (m < 1) and string.format(".%02d", math.floor(m * 100 + 0.5))
                                 or string.format("%.2f", m)
            draw_text(xl, y1, "M " .. txt, COL.text, 1.1 * k, 0, true)
        end
    end
    if cfg.show_gs and D.gs_kt then
        draw_text(xl, y2, "GS " .. istr(D.gs_kt), COL.units, 1.0 * k, 0)
    end
    if cfg.show_baro then
        local txt
        if (D.baro_std or 0) == 1 then txt = "STD"
        elseif D.baro_hg then
            if (D.baro_unit or 0) == 1 then txt = string.format("%.2f", D.baro_hg)
            else txt = istr(D.baro_hg * 33.8639) end
        end
        if txt then draw_text(xr, y2, txt, COL.text, 1.0 * k, 0, true) end
    end
end

-- Heading/track scale.  Airbus A320/A321 HUD material places this scale on
-- the horizon line.  In TRK mode, centre it on ground track (HDG + drift), not
-- magnetic heading; this avoids a wind-drift-sized error in the selected bug.
local function draw_hdg(cx, cy, S, k, th, drift, pitch, roll)
    local hdg = D.hdg or 0
    local trk_mode = (D.hdg_trk or 0) == 1
    local base = hdg
    if trk_mode and drift ~= nil then base = wrap360(hdg + drift) end

    local ppd = cfg.hdg_scale_horizon and (0.4 * S / math.max(cfg.ladder_deg, 1)) or (0.35 * S / 25)
    local half_deg = cfg.hdg_scale_horizon and clamp(math.floor(0.34 * S / ppd), 10, 25) or 25
    local y_horizon = cfg.hdg_scale_horizon and ((pitch or 0) * (0.4 * S / math.max(cfg.ladder_deg, 1))) or (0.41 * S)
    local a = cfg.hdg_scale_horizon and math.rad(-(roll or 0)) or 0
    local sn, cs = math.sin(a), math.cos(a)

    local function point(rel, dy)
        if cfg.hdg_scale_horizon then
            return rot_pt(cx, cy, rel * ppd, y_horizon + dy, sn, cs)
        end
        return cx + rel * ppd, y_horizon + dy
    end

    local x1, y1 = point(-half_deg, 0)
    local x2, y2 = point(half_deg, 0)
    d_line(x1, y1, x2, y2, COL.ladder, th * 0.8)

    local start = math.floor((base - half_deg) / 5) * 5
    for m = start, start + 2 * half_deg + 5, 5 do
        local h = wrap360(m)
        local rel = wrap180(h - base)
        if math.abs(rel) <= half_deg then
            local x, y = point(rel, 0)
            local len = (h % 10 == 0) and 0.022 * S or 0.012 * S
            local xt, yt = point(rel, len)
            d_line(x, y, xt, yt, COL.ladder, th * 0.8)
            if h % 10 == 0 then
                local label
                if h == 0 then label = "N" elseif h == 90 then label = "E"
                elseif h == 180 then label = "S" elseif h == 270 then label = "W"
                else label = string.format("%02d", math.floor(h / 10)) end
                local lx, ly = point(rel, 0.026 * S)
                draw_text(lx, ly, label, COL.ladder, 0.9 * k, 0)
            end
        end
    end

    local cx1, cy1 = point(0, -0.015 * S)
    local cx2, cy2 = point(0, 0.022 * S)
    d_line(cx1, cy1, cx2, cy2, COL.center, th)
    local tx, ty = point(0, -0.058 * S)
    draw_text(tx, ty, string.format("%03d", wrap360(math.floor(base + 0.5))),
              COL.text, 1.2 * k, 0, true)
    if trk_mode then
        local lx, ly = point(0.14 * S / ppd, -0.058 * S)
        draw_text(lx, ly, "TRK", COL.units, 0.9 * k, 0)
        -- In TRK mode the little open diamond identifies magnetic heading.
        if drift ~= nil then
            local rel = clamp(-drift, -half_deg, half_deg)
            local hx, hy = point(rel, 0)
            local d = 0.010 * S
            d_quad(hx, hy - d, hx + d, hy, hx, hy + d, hx - d, hy, COL.track, th * 0.75)
        end
    else
        if drift ~= nil then
            local rel = clamp(drift, -half_deg, half_deg)
            local dx, dy = point(rel, 0)
            local d = 0.012 * S
            d_quad(dx, dy - d, dx + d, dy, dx, dy + d, dx - d, dy, COL.track, th * 0.8)
        end
    end

    -- ILS front-course reference on the same magnetic/track scale.  This is
    -- an intercept-angle aid, not the Airbus conformal LOC-axis symbol.
    if (D.ils_on or 0) > 0.5 and D.ils_crs ~= nil and D.ils_crs >= 0 and D.ils_crs <= 360 then
        local crs = wrap360(D.ils_crs)
        local rel = clamp(wrap180(crs - base), -half_deg, half_deg)
        local ix, iy = point(rel, -0.030 * S)
        local d = 0.009 * S
        d_quad(ix, iy - d, ix + d, iy, ix, iy + d, ix - d, iy, COL.ils, th * 0.85)
    end

    if cfg.show_targets and D.hdg_sel ~= nil and (D.hdg_dash or 0) ~= 1 and (D.hdg_man or 0) ~= 1 then
        local rel = clamp(wrap180(D.hdg_sel - base), -half_deg, half_deg)
        local bx, by = point(rel, -0.004 * S)
        local d = 0.010 * S
        local b1x, b1y = point(rel - d / ppd, -0.004 * S - 1.6 * d)
        local b2x, b2y = point(rel + d / ppd, -0.004 * S - 1.6 * d)
        d_tri(bx, by, b1x, b1y, b2x, b2y, COL.bug, th)
    end
end

-- ILS deviation: localizer dots along the bottom, glideslope dots inboard of
-- the altitude tape.  Diamonds clamp at 2.5 dots; drawn fly-to (+loc -> right,
-- +gs -> up).  Use source / gain / sign controls to calibrate against the PFD.
local function draw_ils(cx, cy, S, k, th)
    local pp = 0.052 * S
    local d = 0.010 * S
    local gain = clamp(cfg.ils_gain or 1.0, 0.25, 4.0)
    local maxoff = 2.5
    local loc_valid = (D.loc_on or 0) > 0.5 and D.loc_val ~= nil
    local gs_valid  = (D.gs_on or 0) > 0.5 and D.gs_val ~= nil
    local ils_active = (D.ils_on or 0) > 0.5

    -- Compact raw-deviation scales.  The G/S scale is deliberately inboard of
    -- the altitude tape to avoid overlap.  These are PFD-style dots, not the
    -- perspective LOC axis / touchdown-point symbology of an Airbus HUD.
    if loc_valid then
        local y0 = cy + 0.335 * S
        for _, dd in ipairs({-2, -1, 1, 2}) do
            d_circle(cx + dd * pp, y0, 0.006 * S, COL.ils, th * 0.75)
        end
        d_line(cx, y0 - 0.014 * S, cx, y0 + 0.014 * S, COL.ils, th * 0.85)
        local val = D.loc_val * gain * (cfg.inv_loc and -1 or 1)
        local x = cx + clamp(val, -maxoff, maxoff) * pp
        d_quad(x, y0 - d, x + d, y0, x, y0 + d, x - d, y0, COL.ils, th)
        draw_text(cx + 2.55 * pp, text_top_centred(y0, 0.8 * k), "LOC", COL.units, 0.8 * k, -1)
    elseif ils_active then
        draw_text(cx, cy + 0.335 * S - 0.012 * S, "LOC", COL.caution, 0.9 * k, 0, true)
    end

    if gs_valid then
        local x0 = cx + 0.205 * S
        for _, dd in ipairs({-2, -1, 1, 2}) do
            d_circle(x0, cy + dd * pp, 0.006 * S, COL.ils, th * 0.75)
        end
        d_line(x0 - 0.014 * S, cy, x0 + 0.014 * S, cy, COL.ils, th * 0.85)
        local val = D.gs_val * gain * (cfg.inv_gs and -1 or 1)
        local y = cy - clamp(val, -maxoff, maxoff) * pp
        d_quad(x0, y - d, x0 + d, y, x0, y + d, x0 - d, y, COL.ils, th)
        draw_text(x0, cy - 2.8 * pp, "G/S", COL.units, 0.8 * k, 0)
    elseif ils_active then
        draw_text(cx + 0.205 * S, cy - 0.155 * S, "G/S", COL.caution, 0.9 * k, 0, true)
    end

    if ils_active and D.ils_crs ~= nil and D.ils_crs >= 0 and D.ils_crs <= 360 then
        local crs = wrap360(math.floor(D.ils_crs + 0.5))
        draw_text(cx, cy + 0.405 * S, string.format("ILS CRS %03d", crs), COL.units, 0.85 * k, 0, true)

        -- Course-to-track angular difference: useful for situational awareness
        -- during intercept setup, but not a lateral-deviation or capture predictor.
        local _, drift = fpv_angles()
        if D.hdg ~= nil and drift ~= nil then
            local track = wrap360(D.hdg + drift)
            local delta = wrap180(crs - track)
            local rounded = math.floor(delta + (delta >= 0 and 0.5 or -0.5))
            draw_text(cx, cy + 0.445 * S, string.format("CRS - TRK  %+03d deg", rounded),
                      COL.units, 0.78 * k, 0, true)
        end
    end
end

-- Radio altitude, boxed (and flashing) at or below the decision height / when
-- ToLiss flags it amber.
local function draw_ralt(cx, cy, S, k, th)
    local ra = D.ralt
    if ra == nil and D.agl ~= nil then ra = D.agl * FT_PER_M end
    if ra == nil or ra > cfg.ralt_max_ft then return end
    ra = math.max(ra, 0)
    local n = (ra > 50) and math.floor(ra / 10 + 0.5) * 10 or math.floor(ra / 2 + 0.5) * 2
    local txt = string.format("%d", n)
    local amber = (D.ralt_amber or 0) == 1 or ((D.dh or 0) > 0 and ra <= D.dh)
    local top = cy + 0.285 * S
    if amber and not flash(1.0) then return end
    draw_text(cx, top, txt, amber and COL.caution or COL.text, 1.3 * k, 0, true)
    if amber then
        local tw, fh = text_size(txt, 1.3 * k)
        d_quad(cx - tw / 2 - 6, top - 2, cx + tw / 2 + 6, top - 2,
               cx + tw / 2 + 6, top + fh + 3, cx - tw / 2 - 6, top + fh + 3, COL.caution, th * 0.8)
    end
end

-- ---- FMA --------------------------------------------------------------
-- The ToLiss FMA is three text lines (FMA1/2/3), each split into colour layers
-- (g, w, b, m, a) of the same positional text.  A single-colour HUD needs no
-- colour, so the layers of a line are merged character by character, then cut
-- into column groups wherever two or more spaces occur.  Each group is placed
-- by its character position, so the five FMA columns keep their alignment
-- whatever the bitmap font's real glyph widths are.

local FMA_LAYERS = { { "g", "w", "b" }, { "b", "m", "w" }, { "a", "b", "w" } }

local function merge_layers(list)
    local n = 0
    for _, s in ipairs(list) do if #s > n then n = #s end end
    local out = {}
    for i = 1, n do
        local ch = " "
        for _, s in ipairs(list) do
            local c = s:sub(i, i)
            if c ~= "" and c ~= " " then ch = c; break end
        end
        out[i] = ch
    end
    return table.concat(out)
end

local function fma_lines()
    local lines, any = {}, false
    for i = 1, 3 do
        local layers = {}
        for _, c in ipairs(FMA_LAYERS[i]) do
            local s = read_str("AirbusFBW/FMA" .. i .. c)
            if s and s:find("%S") then layers[#layers + 1] = s; any = true end
        end
        lines[i] = (#layers > 0) and merge_layers(layers) or ""
    end
    return any and lines or nil
end

local function groups_of(line)
    -- split a merged FMA line into column groups: runs of text where a single
    -- space is kept inside a group and two or more spaces end it
    local g = {}
    local i, n = 1, #line
    while i <= n do
        if line:sub(i, i) ~= " " then
            local s, last, j = i, i, i + 1
            while j <= n do
                local ch = line:sub(j, j)
                if ch ~= " " then
                    last = j
                elseif j == n or line:sub(j + 1, j + 1) == " " then
                    break
                end
                j = j + 1
            end
            g[#g + 1] = { s, line:sub(s, last) }
            i = last + 1
        else
            i = i + 1
        end
    end
    return g
end

local function draw_fma(cx, cy, S, k, th)
    local lines = fma_lines()
    local top = cy - 0.495 * S
    local scale = 1.0 * k
    local _, _, fh, _, cw = font_for(scale)
    local rowh = fh + 2
    if not lines then
        -- No FMA strings (non-ToLiss aircraft, or not readable): show the
        -- engagement status that stock-style numeric datarefs can give.
        local parts = {}
        if (D.ap1 or 0) == 1 then parts[#parts + 1] = "AP1" end
        if (D.ap2 or 0) == 1 then parts[#parts + 1] = "AP2" end
        if (D.fd1 or 0) == 1 then parts[#parts + 1] = "FD" end
        if (D.athr or 0) >= 1 then parts[#parts + 1] = "A/THR" end
        if #parts > 0 then draw_text(cx, top, table.concat(parts, "  "), COL.text, scale, 0, true) end
        return
    end
    local nmax = 30
    for i = 1, 3 do if #lines[i] > nmax then nmax = #lines[i] end end
    local adv = math.min(cw, 0.92 * S / nmax)                -- px per FMA character cell
    local x0 = cx - (nmax * adv) / 2
    for i = 1, 3 do
        local y = top + (i - 1) * rowh
        for _, g in ipairs(groups_of(lines[i])) do
            draw_text(x0 + (g[1] - 1) * adv, y, g[2], COL.text, scale, -1, true)
        end
    end
end

-- ---- flags, config, diagnostics ------------------------------------------

local function draw_flags(cx, cy, S, k, th, v_ias, v_alt, v_att, v_hdg)
    if not flash(0.8) then return end
    if not v_ias then draw_text(cx - 0.39 * S, cy - 0.02 * S, "SPD", COL.caution, 1.6 * k, 0, true) end
    if not v_alt then draw_text(cx + 0.39 * S, cy - 0.02 * S, "ALT", COL.caution, 1.6 * k, 0, true) end
    if not v_att then draw_text(cx, cy - 0.12 * S, "ATT", COL.caution, 2.0 * k, 0, true) end
    if not v_hdg then draw_text(cx, cy + 0.41 * S, "HDG", COL.caution, 1.6 * k, 0, true) end
end

-- ------------------------------------------- overhead unit and combiner --
-- A Head-Up Display in an Airbus cockpit is not a stand on the glareshield: an
-- Overhead Unit (OHU) is fixed to the roof above and ahead of the pilot's head
-- and the glass combiner hangs from a hinge on its front edge.  This section
-- draws that arrangement in the 2D FlyWithLua layer, using a small pinhole
-- model so the parts have consistent perspective:
--
--   * eye space is in centimetres: X right, Y up, Z forward from the eye;
--   * the combiner is a flat plate that hangs from the hinge and leans so that
--     its lower edge is slightly nearer the pilot (a gentle trapezoid whose
--     convergence grows as the eye distance shrinks);
--   * the OHU is a box above the hinge, seen from below and behind - its
--     underside with the projector window, and its rear face;
--   * the whole assembly is scaled by REF / eye_distance, so a larger
--     "eye distance" moves it away from the pilot's face.
--
-- It is an illustration drawn in screen space, centred on the same anchor as
-- the symbology.  It is NOT a measured ToLiss installation, not collimated and
-- it has no head-motion parallax; nothing here reads or drives aircraft state.

local GLASS_TINT = { 0.16, 0.28, 0.20 }
local GLASS_EDGE = { 0.36, 0.78, 0.48 }
local GLASS_HI   = { 0.72, 0.94, 0.80 }
local GLASS_SHADE= { 0.06, 0.22, 0.11 }

local HW_BODY  = { 0.080, 0.086, 0.092 }
local HW_DARK  = { 0.020, 0.024, 0.028 }
local HW_EDGE  = { 0.30, 0.33, 0.35 }
local HW_HI    = { 0.52, 0.56, 0.58 }
local OHU_UNDER_NEAR = { 0.030, 0.034, 0.038 }   -- underside next to the hinge lip
local OHU_UNDER_FAR  = { 0.070, 0.076, 0.082 }   -- underside next to the rear edge
local OHU_BACK_LOW   = { 0.150, 0.158, 0.168 }   -- rear face, lit from the cabin
local OHU_BACK_HIGH  = { 0.070, 0.074, 0.080 }
local OHU_LIP        = { 0.230, 0.245, 0.255 }
local WINDOW_DARK    = { 0.006, 0.012, 0.010 }
local WINDOW_GLOW    = { 0.30, 1.00, 0.42 }

local EYE_REF_CM, EYE_MIN_CM, EYE_MAX_CM = 60, 45, 120

local HW = {
    ppc        = 0.05,   -- pixels per cm per unit of HUD size, at the design depth
    glass_hw   = 10.8,   -- glass half width, cm
    glass_len  = 23.0,   -- glass length along the plate measured from the hinge line, cm
    hinge_bar  = 1.0,    -- hinge bar covering the top of the glass, cm
    rail_w     = 0.8,    -- side rail width, cm
    rail_bot   = 1.2,    -- lower rail width, cm
    tilt       = 12,     -- deployed lean from vertical (lower edge towards the pilot), deg
    tilt_stow  = 65,     -- the deploy swing starts from this angle, deg
    centre_y   = 1.0,    -- lifts the plate so the symbology centre sits mid-glass, cm
    ohu_hw     = 11.8,   -- overhead unit half width, cm
    ohu_depth  = 8.5,    -- overhead unit depth towards the pilot, cm
    ohu_height = 6.5,    -- visible height of the overhead unit rear face, cm
}

local function lerp(a, b, t) return a + (b - a) * t end
local function lerp_col(c1, c2, t)
    return { lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t), lerp(c1[3], c2[3], t) }
end

local function eye_distance()
    return clamp(tonumber(cfg.eye_distance_cm) or DEFAULTS.eye_distance_cm, EYE_MIN_CM, EYE_MAX_CM)
end

-- Uniform scale of glass + symbology + hardware: 1.0 at the 60 cm reference.
local function eye_scale()
    return clamp(EYE_REF_CM / eye_distance(), 0.5, 1.4)
end

-- Projection model for one frame.  `swing` is 1 for the deployed combiner and 0
-- for the folded one (the plate rotates about the hinge line).
local function assembly_geometry(cx, cy, S, swing)
    local d = eye_distance()
    swing = clamp(swing or 1, 0, 1)
    local ppc = HW.ppc * S
    local rest = math.rad(HW.tilt)
    local th = math.rad(HW.tilt + (1 - swing) * (HW.tilt_stow - HW.tilt))
    local half = HW.glass_len / 2
    local zh = d + half * math.sin(rest)                 -- hinge depth
    local yh = half * math.cos(rest) + HW.centre_y       -- hinge height over the eye line
    local sn, cs = math.sin(th), math.cos(th)
    local g = { d = d, ppc = ppc, yh = yh, zh = zh, cx = cx, cy = cy }
    function g.O(x, y, z)                                -- eye space (cm) -> screen px, y down
        if z < 4 then z = 4 end
        local f = d / z
        return cx + x * ppc * f, cy - y * ppc * f
    end
    function g.P(x, s)                                   -- plate coords (cm, cm below hinge) -> px
        return g.O(x, yh - s * cs, zh - s * sn)
    end
    local hw, L, bar = HW.glass_hw, HW.glass_len, HW.hinge_bar
    g.glass = { { g.P(-hw, bar) }, { g.P(hw, bar) }, { g.P(hw, L) }, { g.P(-hw, L) } }
    return g
end

-- Filled rectangle / line given in plate coordinates.
local function pq(g, x1, s1, x2, s2, col, a)
    local ax, ay = g.P(x1, s1)
    local bx, by = g.P(x2, s1)
    local qx, qy = g.P(x2, s2)
    local dx, dy = g.P(x1, s2)
    d_quad_f(ax, ay, bx, by, qx, qy, dx, dy, col, a)
end
local function pl(g, x1, s1, x2, s2, col, w, a)
    local ax, ay = g.P(x1, s1)
    local bx, by = g.P(x2, s2)
    d_line_a(ax, ay, bx, by, col, w, a)
end
-- Filled quad / line given in eye space.
local function oq(g, x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4, col, a)
    local ax, ay = g.O(x1, y1, z1)
    local bx, by = g.O(x2, y2, z2)
    local qx, qy = g.O(x3, y3, z3)
    local dx, dy = g.O(x4, y4, z4)
    d_quad_f(ax, ay, bx, by, qx, qy, dx, dy, col, a)
end
local function ol(g, x1, y1, z1, x2, y2, z2, col, w, a)
    local ax, ay = g.O(x1, y1, z1)
    local bx, by = g.O(x2, y2, z2)
    d_line_a(ax, ay, bx, by, col, w, a)
end

local function hw_fastener(x, y, r, k, alpha)
    d_circle_f(x, y, r, HW_DARK, alpha)
    d_circle(x, y, r, HW_EDGE, math.max(1, 0.8 * k))
    d_line_a(x - r * 0.42, y, x + r * 0.42, y, HW_HI, math.max(1, 0.65 * k), alpha * 0.8)
end

-- Overhead unit: underside with the projector window, and the rear face.
-- `glow` (0..1) is how brightly the projector window shines.
local function draw_overhead_unit(g, k, a, glow)
    local W, yh, zh = HW.ohu_hw, g.yh, g.zh
    local zb = zh - HW.ohu_depth
    local top = yh + HW.ohu_height
    local lw = math.max(1, 1.2 * k)

    -- Underside: dark at the hinge lip, lighter towards the rear edge.
    local n = 5
    for i = 0, n - 1 do
        local t0, t1 = i / n, (i + 1) / n
        local za, zc = lerp(zh, zb, t0), lerp(zh, zb, t1)
        oq(g, -W, yh, za, W, yh, za, W, yh, zc, -W, yh, zc,
           lerp_col(OHU_UNDER_NEAR, OHU_UNDER_FAR, (t0 + t1) / 2), a)
    end

    -- Projector exit window, recessed in the underside, with its glow.
    local wx, wz0, wz1 = 8.2, zh - 1.8, zh - 7.4
    oq(g, -wx, yh, wz0, wx, yh, wz0, wx, yh, wz1, -wx, yh, wz1, WINDOW_DARK, a)
    if glow > 0.01 then
        local m = 4
        for i = 0, m - 1 do
            local za, zc = lerp(wz0, wz1, i / m), lerp(wz0, wz1, (i + 1) / m)
            oq(g, -wx + 0.4, yh, za, wx - 0.4, yh, za, wx - 0.4, yh, zc, -wx + 0.4, yh, zc,
               WINDOW_GLOW, a * glow * (0.16 - 0.03 * i))
        end
    end
    ol(g, -wx, yh, wz0, wx, yh, wz0, HW_EDGE, lw, a * 0.50)
    ol(g, -wx, yh, wz1, wx, yh, wz1, HW_DARK, lw, a)
    ol(g, -wx, yh, wz0, -wx, yh, wz1, HW_DARK, lw, a)
    ol(g, wx, yh, wz0, wx, yh, wz1, HW_EDGE, lw, a * 0.40)

    -- Chamfered front lip along the hinge line, where the combiner is attached.
    oq(g, -W, yh, zh, W, yh, zh, W, yh, zh - 0.8, -W, yh, zh - 0.8, OHU_LIP, a * 0.55)
    ol(g, -W, yh, zh, W, yh, zh, HW_HI, lw, a * 0.60)

    -- Rear face, lit by the cabin: lighter at the bottom, darker towards the roof.
    local m = 6
    for i = 0, m - 1 do
        local t0, t1 = i / m, (i + 1) / m
        local ya, yb = lerp(yh, top, t0), lerp(yh, top, t1)
        oq(g, -W, ya, zb, W, ya, zb, W, yb, zb, -W, yb, zb,
           lerp_col(OHU_BACK_LOW, OHU_BACK_HIGH, (t0 + t1) / 2), a)
    end
    ol(g, -W, yh, zb, W, yh, zb, HW_HI, lw, a * 0.45)           -- lower rear edge catches light
    ol(g, -W, yh, zh, -W, yh, zb, HW_DARK, lw, a)               -- side edges
    ol(g, W, yh, zh, W, yh, zb, HW_DARK, lw, a)
    ol(g, -W, yh, zb, -W, top, zb, HW_DARK, lw, a)
    ol(g, W, yh, zb, W, top, zb, HW_DARK, lw, a)

    -- Cooling vents either side of the identification plate.
    for j = 0, 3 do
        local y = yh + 1.4 + j * 0.9
        ol(g, -10.2, y, zb, -4.8, y, zb, HW_DARK, math.max(1.5, 1.6 * k), a * 0.9)
        ol(g, 4.8, y, zb, 10.2, y, zb, HW_DARK, math.max(1.5, 1.6 * k), a * 0.9)
    end
    -- Identification plate (original XPHUD marking, not an Airbus or vendor mark).
    local py0, py1 = yh + 1.9, yh + 4.1
    oq(g, -3.6, py0, zb, 3.6, py0, zb, 3.6, py1, zb, -3.6, py1, zb, HW_BODY, a)
    ol(g, -3.6, py0, zb, 3.6, py0, zb, HW_EDGE, lw, a * 0.6)
    ol(g, -3.6, py1, zb, 3.6, py1, zb, HW_DARK, lw, a)
    local lx, ly = g.O(0, (py0 + py1) / 2, zb)
    draw_text(lx, text_top_centred(ly, 0.8 * k), "XPHUD  A32X", HW_HI, 0.8 * k, 0)

    local ppc_rear = g.ppc * g.d / zb
    for _, sx in ipairs({ -1, 1 }) do
        for _, y in ipairs({ yh + 1.0, top - 1.0 }) do
            local fx, fy_ = g.O(sx * (W - 1.0), y, zb)
            hw_fastener(fx, fy_, 0.38 * ppc_rear, k, a)
        end
    end
end

-- Hinge bar and the two pivot blocks that join the overhead unit to the frame.
-- These stay in place while the glass swings.
local function draw_hinge(g, k, a)
    local hw, bar, rw = HW.glass_hw, HW.hinge_bar, HW.rail_w
    local ox = hw + rw
    local edge = math.max(1, 1.2 * k)
    local n = 4
    for i = 0, n - 1 do
        pq(g, -ox, bar * i / n, ox, bar * (i + 1) / n,
           lerp_col({ 0.24, 0.255, 0.265 }, { 0.045, 0.05, 0.055 }, (i + 0.5) / n), a)
    end
    pl(g, -ox, 0.04, ox, 0.04, HW_HI, edge, a * 0.55)
    pl(g, -ox, bar, ox, bar, HW_DARK, edge, a)

    for _, side in ipairs({ -1, 1 }) do
        local xi, xo = side * ox, side * (ox + 1.7)
        pq(g, xi, -0.5, xo, 2.9, HW_BODY, a)
        pl(g, xi, -0.5, xo, -0.5, HW_HI, edge, a * 0.5)
        pl(g, xo, -0.5, xo, 2.9, HW_DARK, edge, a)
        pl(g, xi, 2.9, xo, 2.9, HW_DARK, edge, a)
        local px, py = g.P(side * (ox + 0.85), 1.2)
        local qx = g.P(side * (ox + 0.85) + 0.55, 1.2)
        local r = math.abs(qx - px)
        d_circle_f(px, py, r, HW_DARK, a)
        d_circle(px, py, r, HW_EDGE, edge)
        d_circle_f(px, py, r * 0.45, HW_BODY, a)
        d_line_a(px - r * 0.3, py, px + r * 0.3, py, HW_HI, edge, a * 0.85)
    end
end

-- Frame around the glass: side rails, lower rail and a latch tab.
local function draw_frame(g, k, a)
    local hw, L, bar, rw, rb = HW.glass_hw, HW.glass_len, HW.hinge_bar, HW.rail_w, HW.rail_bot
    local ox = hw + rw
    local edge = math.max(1, 1.2 * k)
    for _, side in ipairs({ -1, 1 }) do
        pq(g, side * hw, bar, side * ox, L + rb, HW_BODY, a)
        pl(g, side * (hw + 0.2), bar, side * (hw + 0.2), L, HW_DARK, edge, a)
        pl(g, side * (hw + 0.55), bar, side * (hw + 0.55), L, HW_HI, edge, a * 0.35)
    end
    pq(g, -ox, L, ox, L + rb, HW_BODY, a)
    pl(g, -ox, L + 0.12, ox, L + 0.12, HW_HI, edge, a * 0.5)
    pl(g, -ox, L + rb, ox, L + rb, HW_DARK, edge, a)
    local ax, ay = g.P(-2.4, L + rb)
    local bx, by = g.P(2.4, L + rb)
    local cx2, cy2 = g.P(1.7, L + rb + 1.0)
    local dx, dy = g.P(-1.7, L + rb + 1.0)
    d_quad_f(ax, ay, bx, by, cx2, cy2, dx, dy, HW_BODY, a)
    d_line_a(dx, dy, cx2, cy2, HW_DARK, edge, a)
    local fx, fy_ = g.P(0, L + rb + 0.5)
    local fr = math.abs(g.P(0.28, L + rb + 0.5) - fx)
    hw_fastener(fx, fy_, fr, k, a)
end

-- Glass: faint tint, soft shadow under the hinge, reflection streaks, edge.
local function draw_glass(g, k, ga)
    if not cfg.show_glass or ga <= 0.001 then return end
    local hw, L, bar = HW.glass_hw, HW.glass_len, HW.hinge_bar

    -- Night mode suppresses pane tint and edge reflections, not the flight
    -- symbology. This is a visual aid only; it is not photometric adaptation.
    local night_glass = cfg.night_profile and 0.32 or 1.0
    local tint = clamp(cfg.glass_alpha or 0.035, 0, 0.18) * night_glass * ga
    if tint > 0.001 then pq(g, -hw, bar, hw, L, GLASS_TINT, tint) end

    local night_edge = cfg.night_profile and 0.55 or 1.0
    local edge = clamp(cfg.glass_edge_alpha or 0.22, 0, 0.8) * night_edge * ga
    if edge <= 0.001 then return end
    local w = math.max(1.0, 1.0 * k)

    -- The overhead unit shades the top of the pane.
    if cfg.show_hardware then
        local n = 6
        for i = 0, n - 1 do
            pq(g, -hw, bar + 3.4 * i / n, hw, bar + 3.4 * (i + 1) / n, { 0, 0, 0 },
               0.20 * (1 - (i + 0.5) / n) * ga * (cfg.night_profile and 0.6 or 1.0))
        end
    end

    -- Reflection streaks (cabin light on the glass) and a pale glareshield
    -- reflection low in the pane.  Strength follows the glass edge opacity.
    local refl = edge * 0.30
    local function streak(x0, wd, shift, a2)
        local ax, ay = g.P(x0, bar)
        local bx, by = g.P(x0 + wd, bar)
        local cx2, cy2 = g.P(x0 + wd + shift, L)
        local dx, dy = g.P(x0 + shift, L)
        d_quad_f(ax, ay, bx, by, cx2, cy2, dx, dy, GLASS_HI, a2)
    end
    streak(-8.6, 2.4, 7.5, refl * 0.40)
    streak(-5.4, 0.9, 7.5, refl * 0.28)
    local n = 5
    for i = 0, n - 1 do
        pq(g, -hw, L - 3.0 + 3.0 * i / n, hw, L - 3.0 + 3.0 * (i + 1) / n, GLASS_HI,
           refl * 0.20 * (i + 0.5) / n)
    end

    -- Perimeter and bevel.
    pl(g, -hw, bar, hw, bar, GLASS_EDGE, w, edge)
    pl(g, -hw, L, hw, L, GLASS_EDGE, w, edge)
    pl(g, -hw, bar, -hw, L, GLASS_EDGE, w, edge)
    pl(g, hw, bar, hw, L, GLASS_EDGE, w, edge)
    local ins = 0.28
    pl(g, -hw + ins, bar + ins, hw - ins, bar + ins, GLASS_HI, math.max(1, 0.65 * k), edge * 0.42)
    pl(g, -hw + ins, bar + ins, -hw + ins, L - ins, GLASS_HI, math.max(1, 0.65 * k), edge * 0.30)
    pl(g, -hw + ins, L - ins, hw - ins, L - ins, GLASS_SHADE, math.max(1, 0.8 * k), edge * 0.36)
    pl(g, hw - ins, bar + ins, hw - ins, L - ins, GLASS_SHADE, math.max(1, 0.8 * k), edge * 0.30)
    -- Cut edge of the glass along the bottom catches the light.
    pl(g, -hw + 0.4, L - 0.06, hw - 0.4, L - 0.06, GLASS_HI, math.max(1.5, 1.4 * k), edge * 0.85)
end

-- Draw the complete overhead unit + combiner for one frame.
--   swing  0..1  combiner deploy swing (1 = deployed)
--   fade   0..1  hardware fade-in while the unit powers up
--   glow   0..1  brightness of the projector window (0 when nothing is valid)
local function draw_combiner_assembly(cx, cy, S, k, swing, fade, glow)
    local g = assembly_geometry(cx, cy, S, swing)
    local ga = smoothstep(swing / 0.35)

    local a = 0
    if cfg.show_hardware then
        -- A night profile dims only the physical parts. The green HUD symbols
        -- keep their independent "Symbology brightness" control.
        local night_hardware = cfg.night_profile and 0.42 or 1.0
        a = clamp(cfg.hardware_alpha or DEFAULTS.hardware_alpha, 0, 1) * night_hardware * fade
    end
    if a > 0.01 then draw_overhead_unit(g, k, a, glow) end
    draw_glass(g, k, ga)
    if a > 0.01 then
        if ga > 0.02 then draw_frame(g, k, a * ga) end
        draw_hinge(g, k, a)
    end
    return g
end

-- Calibration pattern: level-attitude symbols drawn with the live drawing code,
-- plus the boresight and the glass perimeter, for checking centring and scale
-- against the cockpit view.  Replaces the live symbology while it is shown.
local calibration_on = false

local function draw_calibration(g, cx, cy, S, k, th)
    draw_horizon(cx, cy, S, k, th, 0, 0)
    draw_bank(cx, cy, S, k, th, 0, 0)
    draw_center(cx, cy, S, th)
    local thin = math.max(1, th * 0.5)
    d_line_a(cx - 0.45 * S, cy, cx + 0.45 * S, cy, COL.caution, thin, 0.6)
    d_line_a(cx, cy - 0.45 * S, cx, cy + 0.45 * S, COL.caution, thin, 0.6)
    local q = g.glass
    for i = 1, 4 do
        local a, b = q[i], q[(i % 4) + 1]
        d_line_a(a[1], a[2], b[1], b[2], COL.caution, thin, 0.9)
    end
    draw_text(cx, cy + 0.30 * S, "CALIBRATION - LEVEL ATTITUDE", COL.caution, 0.9 * k, 0, true)
    draw_text(cx, cy + 0.30 * S + 16 * k, "boresight, horizon, bank scale and glass outline",
              COL.units, 0.75 * k, 0, true)
end

local FLAP_LABEL = { [0] = "0", "1", "2", "3", "FULL" }

local function draw_cfg(cx, cy, S, k)
    local x = cx - 0.49 * S
    local y = cy + 0.36 * S
    local gear = D.gear
    if gear ~= nil then
        y = y + draw_text(x, y, (gear >= 0.5) and "GEAR DN" or "GEAR UP", COL.units, 1.0 * k, -1) + 2
    end
    local fl
    if D.flap_lvr ~= nil then
        fl = FLAP_LABEL[math.floor(D.flap_lvr + 0.5)]
    elseif D.flap_rat ~= nil and D.flap_rat > 0.005 then
        fl = string.format("%d%%", math.floor(D.flap_rat * 100 + 0.5))
    end
    if fl then draw_text(x, y, "FLAPS " .. fl, COL.units, 1.0 * k, -1) end
end

local DEBUG_KEYS = {
    "ias", "alt", "hdg", "pitch", "roll", "vs", "fpa", "drift", "ias_trend", "mach",
    "vls", "vmax", "vaprot", "valpha", "vgd", "spd_tgt", "alt_tgt", "hdg_sel", "hdg_sel_t", "hdg_sel_x", "hdg_rel_trk",
    "ils_on", "ils_crs", "loc_on_t", "loc_val_t", "gs_on_t", "gs_val_t", "loc_on_x", "loc_val_x", "gs_on_x", "gs_val_x",
    "fd1", "fd_pitch", "fd_roll", "loc_on", "loc_val", "gs_on", "gs_val",
    "ralt", "dh", "baro_std", "baro_unit", "v_ias", "v_alt", "v_att", "v_hdg",
}

local function draw_debug(cx, cy, S, k)
    local x = cx - 0.49 * S
    local y = cy - 0.36 * S
    local rows = {}
    for _, key in ipairs(DEBUG_KEYS) do
        local v = D[key]
        rows[#rows + 1] = string.format("%-9s %s %s", key, SRC[key] or "-",
                                        v and string.format("%.2f", v) or "n/a")
    end
    if D.hdg_sel_t ~= nil and D.hdg_sel_x ~= nil then
        local hdg_delta = wrap180(D.hdg_sel_t - D.hdg_sel_x)
        rows[#rows + 1] = string.format("HDG T-X d  %+0.2f deg", hdg_delta)
    end
    rows[#rows + 1] = string.format("HDG source  %s", SRC.hdg_sel or "-")
    local fpa, drift = fpv_angles()
    rows[#rows + 1] = string.format("FPV used  g=%s d=%s",
        fpa and string.format("%.1f", fpa) or "--", drift and string.format("%.1f", drift) or "--")
    local gs = D.gs_ms or 0
    if gs > 2.5 then
        local g = math.deg(atan2(D.vy or 0, gs))
        local tr = math.deg(atan2(D.vx or 0, -(D.vz or 0)))
        local dr = wrap180(tr - (D.psi_true or 0))
        rows[#rows + 1] = string.format("FPV xplane g=%.1f d=%.1f", g, dr)
    end
    for i = 1, 3 do
        for _, c in ipairs(FMA_LAYERS[i]) do
            local s = read_str("AirbusFBW/FMA" .. i .. c)
            if s and s:find("%S") then rows[#rows + 1] = string.format("FMA%d%s [%d] %s", i, c, #s, s) end
        end
    end
    local colh = 34
    local col, perc = 0, 0
    for _, r in ipairs(rows) do
        if perc >= colh then col = col + 1; perc = 0 end
        draw_text(x + col * 0.30 * S, y + perc * 12 * k, r, COL.units, 0.8 * k, -1, true)
        perc = perc + 1
    end
end

-- --------------------------------------------------------------- HUD draw --

-- ------------------------------------------------------ display animation --
-- All motion is a 2D screen-space approximation. It never drives aircraft
-- systems and does not claim to reproduce the real HUD's physical kinematics.
local DISPLAY_ANIM = {
    mode = "boot",       -- boot -> deploying -> deployed -> stowing -> stowed
    started = nil,
    boot_seconds = 1.8,
    travel_seconds = 1.25,
}

local function anim_now()
    return tonumber(D.running) or 0
end

local function set_display_target(visible)
    local now = anim_now()
    if not cfg.animate_deployment then
        DISPLAY_ANIM.mode = visible and "deployed" or "stowed"
        DISPLAY_ANIM.started = now
        return
    end
    if visible then
        if DISPLAY_ANIM.mode == "stowed" or DISPLAY_ANIM.mode == "stowing" then
            DISPLAY_ANIM.mode = "deploying"
            DISPLAY_ANIM.started = now
        end
    else
        if DISPLAY_ANIM.mode == "deployed" or DISPLAY_ANIM.mode == "deploying"
            or DISPLAY_ANIM.mode == "boot" then
            DISPLAY_ANIM.mode = "stowing"
            DISPLAY_ANIM.started = now
        end
    end
end

local function display_animation()
    local now = anim_now()
    if DISPLAY_ANIM.mode == "boot" then
        if not cfg.startup_splash then
            DISPLAY_ANIM.mode = "deployed"
            return 1, false
        end
        if not DISPLAY_ANIM.started then DISPLAY_ANIM.started = now end
        if now - DISPLAY_ANIM.started < DISPLAY_ANIM.boot_seconds then
            return 0, true
        end
        DISPLAY_ANIM.mode = "deploying"
        DISPLAY_ANIM.started = now
    end

    if DISPLAY_ANIM.mode == "deploying" then
        local p = smoothstep((now - (DISPLAY_ANIM.started or now)) / DISPLAY_ANIM.travel_seconds)
        if p >= 1 then DISPLAY_ANIM.mode = "deployed" end
        return p, false
    elseif DISPLAY_ANIM.mode == "stowing" then
        local p = 1 - smoothstep((now - (DISPLAY_ANIM.started or now)) / DISPLAY_ANIM.travel_seconds)
        if p <= 0 then DISPLAY_ANIM.mode = "stowed" end
        return p, false
    elseif DISPLAY_ANIM.mode == "stowed" then
        return 0, false
    end
    return 1, false
end

local function draw_startup_splash(cx, cy, S, k)
    local green = COL.text
    local dim = COL.units
    local y = cy - 0.045 * S
    local w = 0.23 * S
    local h = 0.105 * S
    -- Original XPHUD identity mark; intentionally not the Airbus corporate logo.
    d_line(cx - w, y, cx - 0.72*w, y - h, green, math.max(2, 2.2*k))
    d_line(cx - 0.72*w, y - h, cx + 0.72*w, y - h, green, math.max(2, 2.2*k))
    d_line(cx + 0.72*w, y - h, cx + w, y, green, math.max(2, 2.2*k))
    d_line(cx + w, y, cx + 0.72*w, y + h, green, math.max(2, 2.2*k))
    d_line(cx + 0.72*w, y + h, cx - 0.72*w, y + h, green, math.max(2, 2.2*k))
    d_line(cx - 0.72*w, y + h, cx - w, y, green, math.max(2, 2.2*k))
    draw_text(cx, y - 0.012*S, "XPHUD", green, 2.0*k, 0, true)
    draw_text(cx, y + 0.17*S, "A32X  /  HEAD-UP DISPLAY", dim, 0.78*k, 0, true)
    draw_text(cx, y + 0.225*S, "INITIALISING", dim, 0.66*k, 0, true)
    local pulse = 0.5 + 0.5 * math.sin((anim_now() % 0.8) / 0.8 * 2 * math.pi)
    local barw = 0.19 * S
    d_line(cx - barw, y + 0.265*S, cx + barw, y + 0.265*S, dim, math.max(1, 1.4*k))
    d_line(cx - barw, y + 0.265*S, cx - barw + 2*barw*pulse, y + 0.265*S,
           green, math.max(2, 2.2*k))
end

local function draw_hud_elements(deploy_progress, show_splash)
    COL = PALETTES[cfg.theme] or PALETTES.green
    MASTER_A = cfg.hud_alpha or 1.0

    -- Availability is based on the numeric datarefs actually being read.
    -- Capt*Valid can be zero / intermittent in some ToLiss builds even while
    -- the captain PFD values are live and correct.  Treat a present source as
    -- available; use the yellow flags only when the corresponding value is
    -- genuinely unavailable (neither ToLiss nor X-Plane supplied it).
    local v_ias = D.ias ~= nil and SRC.ias ~= "-"
    local v_alt = D.alt ~= nil and SRC.alt ~= "-"
    local v_att = D.pitch ~= nil and D.roll ~= nil
                  and SRC.pitch ~= "-" and SRC.roll ~= "-"
    local v_hdg = D.hdg ~= nil and SRC.hdg ~= "-"
    local w, h = SCREEN_WIDTH, SCREEN_HIGHT
    -- "Eye distance" scales the whole assembly (glass, symbology, hardware):
    -- the further from the pilot's face, the smaller it is drawn.
    local S = math.min(cfg.size, math.min(w, h) * 0.9) * eye_scale()
    local cx = clamp(w / 2 + (cfg.pos_x or 0), 0, w)
    local cy = clamp(h / 2 + (cfg.pos_y or 0), 0, h)
    local k = S / 500
    local th = math.max(1.5, cfg.line_w * k)

    if show_splash then
        draw_startup_splash(cx, cy, S, k)
        return
    end

    -- Deploy / stow: the overhead unit fades in, the combiner swings down on its
    -- hinge, and only then does the symbology fade in.  Illustrative only; it
    -- does not read or drive any real HUD mechanism.
    local p = clamp(deploy_progress or 1, 0, 1)
    if p <= 0 then return end
    local swing = smoothstep(p / 0.7)
    local fade = smoothstep(p / 0.15)
    local symbol_alpha = smoothstep((p - 0.7) / 0.3)

    -- Hardware and glass are not dimmed by the symbology brightness control.
    -- With nothing valid (aircraft unpowered / ADIRS off) a real HUD is dark:
    -- the projector window stays unlit but the combiner remains visible.
    local powered = v_ias or v_alt or v_att or v_hdg
    MASTER_A = 1.0
    local g = draw_combiner_assembly(cx, cy, S, k, swing, fade,
                                     powered and (cfg.hud_alpha or 1.0) * symbol_alpha or 0)
    MASTER_A = (cfg.hud_alpha or 1.0) * symbol_alpha

    if calibration_on then
        draw_calibration(g, cx, cy, S, k, th)
        return
    end
    if not powered then
        if cfg.show_debug then draw_debug(cx, cy, S, k) end
        return
    end
    if symbol_alpha <= 0.001 then return end

    local pitch, roll = D.pitch or 0, D.roll or 0
    local gamma, drift = fpv_angles()

    if v_att then
        if cfg.show_horizon then draw_horizon(cx, cy, S, k, th, pitch, roll) end
        if cfg.show_bank    then draw_bank(cx, cy, S, k, th, roll, D.slip) end
        if cfg.show_fpv and gamma then draw_fpv(cx, cy, S, k, th, pitch, roll, gamma, drift) end
        if cfg.show_fd      then draw_fd(cx, cy, S, k, th) end
    end
    if cfg.show_center then draw_center(cx, cy, S, th) end

    if cfg.show_spd and v_ias then draw_speed(cx, cy, S, k, th) end
    if cfg.show_alt and v_alt then draw_alt(cx, cy, S, k, th) end
    if cfg.show_vs  and v_alt then draw_vs(cx, cy, S, k) end
    draw_side_info(cx, cy, S, k)
    if cfg.show_hdg and v_hdg then draw_hdg(cx, cy, S, k, th, drift, pitch, roll) end
    if cfg.show_ils  then draw_ils(cx, cy, S, k, th) end
    if cfg.show_ralt then draw_ralt(cx, cy, S, k, th) end
    if cfg.show_fma  then draw_fma(cx, cy, S, k, th) end
    if cfg.show_cfg  then draw_cfg(cx, cy, S, k) end
    if cfg.show_flags then draw_flags(cx, cy, S, k, th, v_ias, v_alt, v_att, v_hdg) end
    if cfg.show_debug then draw_debug(cx, cy, S, k) end
end

-- Top-level draw callback: guarded so a runtime error can never disable
-- FlyWithLua as a whole.
function xa32_draw()
    SH = SCREEN_HIGHT
    local ok, err = pcall(function()
        read_inputs()
        if (D.running or 0) <= 0 then return end              -- flight not started yet
        if not cfg.visible and DISPLAY_ANIM.mode ~= "stowing" then return end
        if cfg.hide_external and (D.view_ext or 0) == 1 then return end

        -- Set a known 2D overlay state before drawing. Alpha testing is OFF
        -- and alpha blending is ON so the combiner tint and bevel stay translucent.
        if type(XPLMSetGraphicsState) == "function" then
            XPLMSetGraphicsState(0, 0, 0, 0, 1, 0, 0)
        end

        local progress, splash = display_animation()
        if not cfg.visible and DISPLAY_ANIM.mode == "stowed" then return end
        draw_hud_elements(progress, splash)
    end)
    if not ok then
        draw_error_count = draw_error_count + 1
        if draw_error_count <= 5 then
            logMsg("XPHUD A32X: draw error (" .. draw_error_count .. "): " .. tostring(err))
        end
    end
end

-- --------------------------------------------------- commands / control --

local function sync_visible_out()
    if have_visible_dr then
        xa32_visible_dr = cfg.visible and 1 or 0
        vis_last = xa32_visible_dr
    end
end

function xa32_toggle()
    cfg.visible = not cfg.visible
    set_display_target(cfg.visible)
    sync_visible_out()
    settings_dirty = true
end

function xa32_set_visible(v)
    cfg.visible = v and true or false
    set_display_target(cfg.visible)
    sync_visible_out()
    settings_dirty = true
end

function xa32_center()
    cfg.pos_x, cfg.pos_y = 0, 0
    settings_dirty = true
end

-- keep cfg.visible in step with external writes to XPHUD_A32X/Visible
function xa32_sync_visible()
    if not have_visible_dr then return end
    if not vis_primed then
        -- frame 1: the shared dataref is not persistent, so make it reflect the
        -- loaded preference instead of letting it override the saved setting
        xa32_visible_dr = cfg.visible and 1 or 0
        vis_last = xa32_visible_dr
        vis_primed = true
        return
    end
    local cur = xa32_visible_dr
    if cur ~= vis_last then
        cfg.visible = (cur == 1)
        set_display_target(cfg.visible)
        vis_last = cur
        settings_dirty = true
    end
end

function xa32_autosave()
    if settings_dirty then
        save_prefs()
        settings_dirty = false
    end
end

have_visible_dr = pcall(function()
    define_shared_DataRef("XPHUD_A32X/Visible", "Int")
    dataref("xa32_visible_dr", "XPHUD_A32X/Visible", "writable")
end)

-- --------------------------------------------------- settings window --

local function cycle(order, current)
    for i, v in ipairs(order) do
        if v == current then return order[(i % #order) + 1] end
    end
    return order[1]
end

-- FlyWithLua's imgui takes packed 0xAABBGGRR colours.
local function u32c(r, g, b, a)
    local function q(x) if x < 0 then x = 0 elseif x > 1 then x = 1 end return math.floor(x * 255 + 0.5) end
    return q(a) * 0x1000000 + q(b) * 0x10000 + q(g) * 0x100 + q(r)
end

local BRAND = {
    accent   = u32c(0.40, 1.00, 0.50, 1.00),
    accent_b = u32c(0.65, 1.00, 0.70, 1.00),
    head     = u32c(0.38, 0.83, 1.00, 1.00),
    text     = u32c(0.90, 0.93, 0.96, 1.00),
    dim      = u32c(0.56, 0.61, 0.68, 1.00),
    bg       = u32c(0.00, 0.00, 0.00, 0.92),
    frame    = u32c(0.13, 0.16, 0.20, 1.00),
    frame_h  = u32c(0.19, 0.24, 0.30, 1.00),
    frame_a  = u32c(0.25, 0.32, 0.40, 1.00),
    button   = u32c(0.15, 0.19, 0.25, 1.00),
    button_h = u32c(0.20, 0.40, 0.54, 1.00),
    button_a = u32c(0.16, 0.72, 0.35, 1.00),
    danger_h = u32c(0.55, 0.20, 0.18, 1.00),
    danger_a = u32c(0.90, 0.28, 0.24, 1.00),
    border   = u32c(0.28, 0.34, 0.42, 0.50),
    sep      = u32c(0.28, 0.34, 0.42, 0.60),
}

local function push_col(name, col)
    local t = imgui.constant and imgui.constant.Col
    local id = t and t[name]
    if id ~= nil then imgui.PushStyleColor(id, col); return 1 end
    return 0
end
local function pop_cols(n) for _ = 1, n do imgui.PopStyleColor() end end

local function push_theme()
    local n = 0
    n = n + push_col("Text",             BRAND.text)
    n = n + push_col("WindowBg",         BRAND.bg)
    n = n + push_col("ChildBg",          BRAND.bg)
    n = n + push_col("Border",           BRAND.border)
    n = n + push_col("FrameBg",          BRAND.frame)
    n = n + push_col("FrameBgHovered",   BRAND.frame_h)
    n = n + push_col("FrameBgActive",    BRAND.frame_a)
    n = n + push_col("CheckMark",        BRAND.accent)
    n = n + push_col("SliderGrab",       BRAND.accent)
    n = n + push_col("SliderGrabActive", BRAND.accent_b)
    n = n + push_col("Button",           BRAND.button)
    n = n + push_col("ButtonHovered",    BRAND.button_h)
    n = n + push_col("ButtonActive",     BRAND.button_a)
    n = n + push_col("Header",           BRAND.button)
    n = n + push_col("HeaderHovered",    BRAND.button_h)
    n = n + push_col("HeaderActive",     BRAND.button_a)
    n = n + push_col("Separator",        BRAND.sep)
    return n
end

local function danger_button(label)
    local n = push_col("ButtonHovered", BRAND.danger_h)
    n = n + push_col("ButtonActive",  BRAND.danger_a)
    local clicked = imgui.Button(label)
    pop_cols(n)
    return clicked
end

local function section(label)
    imgui.TextUnformatted("")
    local n = push_col("Text", BRAND.head)
    imgui.TextUnformatted(label)
    pop_cols(n)
    imgui.Separator()
end
local function caption(label)
    local n = push_col("Text", BRAND.dim)
    imgui.TextUnformatted(label)
    pop_cols(n)
end

local ELEMENTS = {
    { "show_fma",     "FMA (flight modes)" },      { "show_spd",    "Speed tape" },
    { "show_alt",     "Altitude tape" },           { "show_vs",     "Vertical speed" },
    { "show_hdg",     "Heading scale + track" },   { "show_horizon","Horizon + pitch ladder" },
    { "show_bank",    "Roll scale + slip" },       { "show_fpv",    "Flight path vector" },
    { "show_fd",      "Flight director cue" },     { "show_ils",    "ILS deviation" },
    { "show_ralt",    "Radio altitude" },          { "show_center", "Boresight brackets" },
    { "show_mach",    "Mach" },                    { "show_gs",     "Ground speed" },
    { "show_baro",    "Baro setting" },            { "show_targets","Selected SPD / ALT / HDG" },
    { "show_trend",   "Speed trend" },             { "show_vmarks", "Speed limits (VLS, a-PROT, VMAX...)" },
    { "show_flags",   "Failure flags" },           { "show_cfg",    "Gear / flap lever" },
}

local function settings_body()
    local changed, v

    imgui.SetWindowFontScale(1.5)
    local nh = push_col("Text", BRAND.accent)
    imgui.TextUnformatted("XPHUD  A32X")
    pop_cols(nh)
    imgui.SetWindowFontScale(1.0)
    caption(EDITION)
    caption("original XPHUD by xbard (MIT) - unofficial edition, not affiliated with ToLiss or Airbus")
    imgui.Separator()

    section("DISPLAY")
    caption("bind XPHUD_A32X/Toggle and XPHUD_A32X/Settings for quick access")
    changed, v = imgui.Checkbox("HUD visible", cfg.visible)
    if changed then xa32_set_visible(v) end
    imgui.SameLine(250)
    changed, v = imgui.Checkbox("Hide in external views", cfg.hide_external)
    if changed then cfg.hide_external = v; settings_dirty = true end
    changed, v = imgui.Checkbox("Glass combiner / edge", cfg.show_glass)
    if changed then cfg.show_glass = v; settings_dirty = true end
    changed, v = imgui.Checkbox("Overhead unit, hinge and combiner frame", cfg.show_hardware)
    if changed then cfg.show_hardware = v; settings_dirty = true end
    changed, v = imgui.SliderFloat("Hardware opacity", cfg.hardware_alpha, 0.0, 1.0, "%.2f")
    if changed then cfg.hardware_alpha = v; settings_dirty = true end
    changed, v = imgui.SliderFloat("Eye distance (visual cm)", cfg.eye_distance_cm, 45, 120, "%.0f")
    if changed then cfg.eye_distance_cm = v; settings_dirty = true end
    caption("Larger = the combiner sits further from the pilot's face (drawn smaller,")
    caption("with less perspective). A 2D depth cue, not a measured cockpit dimension.")
    changed, v = imgui.Checkbox("Calibration pattern (replaces symbology, not saved)", calibration_on)
    if changed then calibration_on = v end
    changed, v = imgui.Checkbox("Night visual profile (dim glass and frame)", cfg.night_profile)
    if changed then cfg.night_profile = v; settings_dirty = true end
    caption("Night profile softens the physical overlay; adjust symbol brightness separately.")
    changed, v = imgui.Checkbox("Startup splash screen", cfg.startup_splash)
    if changed then cfg.startup_splash = v; settings_dirty = true end
    changed, v = imgui.Checkbox("Animate combiner deploy / stow", cfg.animate_deployment)
    if changed then cfg.animate_deployment = v; settings_dirty = true end
    changed, v = imgui.SliderFloat("HUD size px", cfg.size, 300, 1200, "%.0f")
    if changed then cfg.size = v; settings_dirty = true end
    if imgui.Button("Centre HUD") then xa32_center() end
    local hx, hy = SCREEN_WIDTH / 2, SCREEN_HIGHT / 2
    changed, v = imgui.SliderFloat("X offset px", cfg.pos_x, -hx, hx, "%.0f")
    if changed then cfg.pos_x = v; settings_dirty = true end
    changed, v = imgui.SliderFloat("Y offset px (down +)", cfg.pos_y, -hy, hy, "%.0f")
    if changed then cfg.pos_y = v; settings_dirty = true end
    changed, v = imgui.SliderFloat("Line width px", cfg.line_w, 1, 6, "%.1f")
    if changed then cfg.line_w = v; settings_dirty = true end
    changed, v = imgui.SliderFloat("Text size", cfg.text_scale, 0.7, 2.5, "%.2f")
    if changed then cfg.text_scale = v; settings_dirty = true end
    changed, v = imgui.SliderFloat("Symbology brightness", cfg.hud_alpha, 0.2, 1.0, "%.2f")
    if changed then cfg.hud_alpha = v; settings_dirty = true end
    changed, v = imgui.SliderFloat("Glass tint opacity", cfg.glass_alpha, 0.0, 0.18, "%.3f")
    if changed then cfg.glass_alpha = v; settings_dirty = true end
    changed, v = imgui.SliderFloat("Glass edge opacity", cfg.glass_edge_alpha, 0.0, 0.8, "%.2f")
    if changed then cfg.glass_edge_alpha = v; settings_dirty = true end
    changed, v = imgui.SliderFloat("Readout box shading", cfg.plate_alpha, 0.0, 1.0, "%.2f")
    if changed then cfg.plate_alpha = v; settings_dirty = true end

    section("THEME")
    caption("green = Airbus single-colour HUD (default); click to cycle")
    if imgui.Button("Theme: " .. cfg.theme) then
        cfg.theme = cycle(THEME_ORDER, cfg.theme); settings_dirty = true
    end

    section("ELEMENTS")
    for i, e in ipairs(ELEMENTS) do
        changed, v = imgui.Checkbox(e[2], cfg[e[1]])
        if changed then cfg[e[1]] = v; settings_dirty = true end
        if i % 2 == 1 then imgui.SameLine(250) end
    end

    section("SCALES")
    changed, v = imgui.SliderFloat("Pitch scale: deg over 0.4 x size", cfg.ladder_deg, 8, 30, "%.0f")
    if changed then cfg.ladder_deg = v; settings_dirty = true end
    changed, v = imgui.SliderFloat("Speed tape half-window kt", cfg.spd_range_kt, 20, 80, "%.0f")
    if changed then cfg.spd_range_kt = v; settings_dirty = true end
    changed, v = imgui.SliderFloat("Altitude tape half-window ft", cfg.alt_range_ft, 200, 1000, "%.0f")
    if changed then cfg.alt_range_ft = v; settings_dirty = true end
    changed, v = imgui.SliderFloat("Radio altitude shown below ft", cfg.ralt_max_ft, 500, 3000, "%.0f")
    if changed then cfg.ralt_max_ft = v; settings_dirty = true end

    section("CALIBRATION")
    caption("units and signs of a few ToLiss datarefs could not be confirmed offline;")
    caption("if a cue moves the wrong way, flip it here (see the diagnostics readout)")
    if imgui.Button("FPV source: " .. cfg.fpv_src) then
        cfg.fpv_src = cycle(FPV_ORDER, cfg.fpv_src); settings_dirty = true
    end
    imgui.SameLine()
    caption("auto = ToLiss PFD values, xplane = sim velocity vector")
    changed, v = imgui.Checkbox("Flip LOC", cfg.inv_loc)
    if changed then cfg.inv_loc = v; settings_dirty = true end
    imgui.SameLine(250)
    changed, v = imgui.Checkbox("Flip G/S", cfg.inv_gs)
    if changed then cfg.inv_gs = v; settings_dirty = true end
    changed, v = imgui.Checkbox("Flip FD pitch", cfg.inv_fd_pitch)
    if changed then cfg.inv_fd_pitch = v; settings_dirty = true end
    imgui.SameLine(250)
    changed, v = imgui.Checkbox("Flip FD roll", cfg.inv_fd_roll)
    if changed then cfg.inv_fd_roll = v; settings_dirty = true end
    if imgui.Button("HDG target source: " .. cfg.hdg_sel_source) then
        cfg.hdg_sel_source = cycle(HDG_SOURCE_ORDER, cfg.hdg_sel_source); settings_dirty = true
    end
    caption("auto = X-Plane magnetic heading dial first; ToLiss is fallback")
    changed, v = imgui.SliderFloat("HDG target display offset deg", cfg.hdg_sel_offset, -10, 10, "%+.1f")
    if changed then cfg.hdg_sel_offset = v; settings_dirty = true end
    changed, v = imgui.Checkbox("Heading/track scale on horizon", cfg.hdg_scale_horizon)
    if changed then cfg.hdg_scale_horizon = v; settings_dirty = true end
    if imgui.Button("ILS deviation source: " .. cfg.ils_source) then
        cfg.ils_source = cycle(ILS_SOURCE_ORDER, cfg.ils_source); settings_dirty = true
    end
    caption("auto = use ToLiss when its deviation flags are valid; otherwise X-Plane")
    changed, v = imgui.SliderFloat("ILS deviation gain", cfg.ils_gain, 0.25, 4.0, "%.2f")
    if changed then cfg.ils_gain = v; settings_dirty = true end
    changed, v = imgui.SliderFloat("FD roll order deg for full deflection", cfg.fd_roll_deg, 10, 60, "%.0f")
    if changed then cfg.fd_roll_deg = v; settings_dirty = true end

    section("DIAGNOSTICS")
    changed, v = imgui.Checkbox("Live HUD dataref readout", cfg.show_debug)
    if changed then cfg.show_debug = v; settings_dirty = true end
    caption("Capture is read-only. CSV files are saved in Output/preferences/.")
    caption("Includes raw ToLiss and X-Plane candidates, XPLM type masks,")
    caption("selected source, FMA strings and simulator running time.")
    if imgui.Button("Capture diagnostic snapshot") then
        if diag_snapshot() then
            logMsg("XPHUD A32X: diagnostic snapshot saved to " .. tostring(diag_file_path))
        else
            logMsg("XPHUD A32X: diagnostic snapshot failed: " .. tostring(diag_error))
        end
    end
    if diag_recording then
        imgui.SameLine()
        if danger_button("Stop CSV recording") then diag_stop_recording() end
        caption("Recording at approximately 1 sample/second.")
    else
        imgui.SameLine()
        if imgui.Button("Start CSV recording") then
            diag_start_recording()
            if diag_recording then
                logMsg("XPHUD A32X: diagnostic recording started: " .. tostring(diag_file_path))
            else
                logMsg("XPHUD A32X: diagnostic recording failed: " .. tostring(diag_error))
            end
        end
    end
    if diag_file_path then caption("Last file: " .. diag_file_path) end
    if diag_error then caption("Capture error: " .. diag_error) end
    caption("Record short test segments: powered ground, IRS aligned, HDG/TRK,")
    caption("ILS tuned/untuned and LOC/GS deviations. Stop recording between tests.")

    section("")
    if imgui.Button("Save now") then save_prefs(); settings_dirty = false end
    imgui.SameLine()
    if danger_button("Restore defaults") then
        for key, dv in pairs(DEFAULTS) do cfg[key] = dv end
        sync_visible_out(); settings_dirty = true
    end
    caption("Original XPHUD by xbard - HeliHUD by Steve Hanley (FS2004, 2003)")
    caption("HUD after Petr Medek's HeliHud")
end

local settings_err = 0

function xa32_settings_builder()
    local nth = push_theme()
    if imgui.DrawList_AddRectFilled and imgui.GetWindowPos then
        local wx, wy = imgui.GetWindowPos()
        imgui.DrawList_AddRectFilled(wx, wy,
            wx + imgui.GetWindowWidth(), wy + imgui.GetWindowHeight(), BRAND.bg)
    end
    local ok, err = pcall(settings_body)
    imgui.SetWindowFontScale(1.0)
    pop_cols(nth)
    if not ok then
        settings_err = settings_err + 1
        if settings_err <= 5 then
            logMsg("XPHUD A32X: settings draw error (" .. settings_err .. "): " .. tostring(err))
        end
    end
end

function xa32_settings_onclose()
    settings_open = false
    settings_wnd = nil
    save_prefs(); settings_dirty = false
end

function xa32_open_settings()
    if not SUPPORTS_FLOATING_WINDOWS then
        logMsg("XPHUD A32X: settings window needs a FlyWithLua build with imgui support.")
        return
    end
    if settings_open and settings_wnd then return end
    settings_wnd = float_wnd_create(560, 760, 1, true)
    float_wnd_set_title(settings_wnd, EDITION)
    float_wnd_set_imgui_builder(settings_wnd, "xa32_settings_builder")
    float_wnd_set_onclose(settings_wnd, "xa32_settings_onclose")
    settings_open = true
end

-- ------------------------------------------------------------- wiring --

create_command("XPHUD_A32X/Toggle",   "Show/hide the XPHUD A32X overlay",        "xa32_toggle()",        "", "")
create_command("XPHUD_A32X/Settings", "Open the XPHUD A32X settings window",     "xa32_open_settings()", "", "")
create_command("XPHUD_A32X/Center",   "Snap the XPHUD A32X HUD back to centre",  "xa32_center()",        "", "")

add_macro("XPHUD A32X: toggle HUD",      "xa32_toggle()")
add_macro("XPHUD A32X: settings window", "xa32_open_settings()")

do_every_draw("xa32_draw()")
do_every_frame("xa32_sync_visible()")
function xa32_diag_tick() diag_tick() end
do_every_frame("xa32_diag_tick()")
do_often("xa32_autosave()")

-- Test seam: only exposed when a test harness sets XPHUD_TEST_HOOKS before
-- loading the script.  Nothing is added to the global table in the simulator.
if rawget(_G, "XPHUD_TEST_HOOKS") then
    xa32_test = {
        cfg = cfg, DEFAULTS = DEFAULTS, PREFS_VERSION = PREFS_VERSION,
        wrap180 = wrap180, wrap360 = wrap360,
        save_prefs = save_prefs, load_prefs = load_prefs, migrate_prefs = migrate_prefs,
        prefs_file = prefs_file, write_file_atomic = write_file_atomic,
        assembly_geometry = assembly_geometry, eye_scale = eye_scale,
        smoothstep = smoothstep, HW = HW,
        set_calibration = function(v) calibration_on = v and true or false end,
    }
end

logMsg(EDITION .. ": started")
