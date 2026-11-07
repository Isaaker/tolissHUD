-- Minimal FlyWithLua / X-Plane mock used to run xphud_toliss_a32x.lua outside
-- the simulator.  It is a test aid only: it records every 2D primitive that the
-- script draws so tests can inspect them and tools can rasterise them to SVG.
--
-- Plain Lua 5.4 (no third-party modules).  Nothing here talks to X-Plane.

local M = {}

-- XPLM type masks used by the script.
local T_INT, T_FLOAT = 1, 2

-- A representative ToLiss A320 approach, used for screenshots and tests.
M.SCENARIO_APPROACH = {
    ["AirbusFBW/IASCapt"] = 142, ["AirbusFBW/MachCapt"] = 0.22,
    ["AirbusFBW/ALTCapt"] = 1850, ["AirbusFBW/HDGCapt"] = 273,
    ["toliss_airbus/pfdoutputs/captain/pitch_angle"] = 3.2,
    ["toliss_airbus/pfdoutputs/captain/roll_angle"] = -4.0,
    ["toliss_airbus/pfdoutputs/captain/vertical_speed"] = -700,
    ["toliss_airbus/pfdoutputs/captain/flight_path_angle"] = -3.0,
    ["toliss_airbus/pfdoutputs/captain/drift_angle"] = 4.0,
    ["AirbusFBW/IASTrendCapt"] = 2,
    ["toliss_airbus/pfdoutputs/general/VLS_value"] = 128,
    ["toliss_airbus/pfdoutputs/general/VMax_value"] = 215,
    ["toliss_airbus/pfdoutputs/general/VAProt_value"] = 118,
    ["toliss_airbus/pfdoutputs/general/VAlphaMax_value"] = 112,
    ["toliss_airbus/pfdoutputs/general/VGreenDot_value"] = 140,
    ["toliss_airbus/pfdoutputs/general/ap_speed_value"] = 140,
    ["toliss_airbus/pfdoutputs/general/ap_alt_target_value"] = 3000,
    ["AirbusFBW/APHDG_Capt"] = 270, ["AirbusFBW/FD1Engage"] = 1,
    ["toliss_airbus/pfdoutputs/general/fd1_pitch_cmd"] = 1.0,
    ["toliss_airbus/pfdoutputs/general/fd1_roll_cmd"] = 3.0,
    ["AirbusFBW/AP1Engage"] = 1, ["AirbusFBW/ATHRmode"] = 1,
    ["AirbusFBW/ILSonCapt"] = 1, ["AirbusFBW/ILSCrs"] = 270,
    ["AirbusFBW/LOConCapt"] = 1, ["AirbusFBW/LOCvalCapt"] = 0.4,
    ["AirbusFBW/GSonCapt"] = 1, ["AirbusFBW/GSvalCapt"] = -0.3,
    ["sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot"] = 1500,
    ["AirbusFBW/BaroStdCapt"] = 0,
    ["sim/cockpit2/gauges/actuators/barometer_setting_in_hg_pilot"] = 29.92,
    ["sim/cockpit2/gauges/indicators/slip_deg"] = 1.0,
    ["sim/cockpit2/gauges/indicators/ground_speed_kt"] = 138,
    ["AirbusFBW/GearLever"] = 1, ["AirbusFBW/FlapRequestPos"] = 2,
    ["sim/flightmodel/position/local_vx"] = -70, ["sim/flightmodel/position/local_vz"] = 4,
    ["sim/flightmodel/position/local_vy"] = -3.6, ["sim/flightmodel/position/psi"] = 273,
    ["sim/graphics/view/view_is_external"] = 0,
}

M.SCENARIO_FMA = {
    ["AirbusFBW/FMA1g"] = "SPEED       G/S        LOC        CAT3       AP1+2     ",
    ["AirbusFBW/FMA2b"] = "                                 DUAL       1FD2      ",
    ["AirbusFBW/FMA3a"] = "                                            A/THR     ",
}

local INT_PATHS = {
    ["AirbusFBW/FD1Engage"] = true, ["AirbusFBW/AP1Engage"] = true,
    ["AirbusFBW/ATHRmode"] = true, ["AirbusFBW/ILSonCapt"] = true,
    ["AirbusFBW/LOConCapt"] = true, ["AirbusFBW/GSonCapt"] = true,
    ["AirbusFBW/GearLever"] = true, ["AirbusFBW/BaroStdCapt"] = true,
    ["sim/graphics/view/view_is_external"] = true,
}

--- Create a fresh mock sim and a sandboxed environment for the script.
-- opts.width / opts.height  screen size in pixels (default 1920x1080)
-- opts.datarefs             path -> number (merged over the approach scenario)
-- opts.strings              path -> string  (FMA text)
-- opts.prefs_dir            directory used as SYSTEM_DIRECTORY (must exist)
function M.new(opts)
    opts = opts or {}
    local sim = {
        calls = {}, logs = {}, time = 1.0, colour = { 1, 1, 1, 1 }, width_px = 1,
        datarefs = {}, strings = {}, commands = {}, macros = {},
    }
    for k, v in pairs(opts.datarefs or M.SCENARIO_APPROACH) do sim.datarefs[k] = v end
    for k, v in pairs(opts.strings or M.SCENARIO_FMA) do sim.strings[k] = v end

    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.SCREEN_WIDTH = opts.width or 1920
    env.SCREEN_HIGHT = opts.height or 1080       -- (sic) FlyWithLua spelling
    env.SYSTEM_DIRECTORY = opts.prefs_dir or ""
    env.SUPPORTS_FLOATING_WINDOWS = false
    env.require = function() return true end
    env.logMsg = function(s) sim.logs[#sim.logs + 1] = tostring(s) end

    local function rec(kind, ...)
        sim.calls[#sim.calls + 1] = {
            kind = kind, args = { ... },
            r = sim.colour[1], g = sim.colour[2], b = sim.colour[3], a = sim.colour[4],
            w = sim.width_px,
        }
    end
    env.graphics = {
        set_color = function(r, g, b, a) sim.colour = { r, g, b, a or 1 } end,
        set_width = function(w) sim.width_px = w end,
        draw_line = function(...) rec("line", ...) end,
        draw_triangle = function(...) rec("tri", ...) end,
        draw_circle = function(...) rec("circle", ...) end,
        draw_filled_circle = function(...) rec("disc", ...) end,
    }
    for _, name in ipairs({ "Times_Roman_24", "Helvetica_18", "Helvetica_12", "Helvetica_10" }) do
        env["draw_string_" .. name] = function(x, y, s) rec("text", x, y, s, name) end
    end
    env.XPLMSetGraphicsState = function() end

    -- X-Plane dataref API: handle = table, type mask int/float.
    env.XPLMFindDataRef = function(path)
        if sim.datarefs[path] ~= nil or sim.strings[path] ~= nil then
            return { path = path }
        end
        return nil
    end
    env.XPLMGetDataRefTypes = function(h)
        if sim.strings[h.path] then return 8 end
        return INT_PATHS[h.path] and T_INT or T_FLOAT
    end
    local function getter(h) return sim.datarefs[h.path] end
    env.XPLMGetDataf, env.XPLMGetDatad, env.XPLMGetDatai = getter, getter, getter

    env.dataref = function(name, path)
        sim.string_bindings = sim.string_bindings or {}
        sim.string_bindings[name] = path
        env[name] = sim.strings[path]
    end
    env.define_shared_DataRef = function() end
    env.create_command = function(name) sim.commands[name] = true end
    env.add_macro = function(name) sim.macros[name] = true end
    env.do_every_draw = function() end
    env.do_every_frame = function() end
    env.do_often = function() end

    --- Advance the simulated clock and refresh the bound string datarefs.
    function sim.set_time(t)
        sim.time = t
        sim.datarefs["sim/time/total_running_time_sec"] = t
        for name, path in pairs(sim.string_bindings or {}) do env[name] = sim.strings[path] end
    end
    sim.set_time(sim.time)

    function sim.load(script_path)
        local chunk, err = loadfile(script_path, "t", env)
        if not chunk then error(err) end
        chunk()
        return env
    end

    --- Run one draw callback and return the primitives it produced.
    function sim.frame(t)
        if t then sim.set_time(t) end
        sim.calls = {}
        env.xa32_draw()
        return sim.calls
    end

    --- Bring the HUD from boot splash to the fully deployed state.
    function sim.settle()
        sim.frame(1.0)      -- boot splash starts
        sim.frame(3.5)      -- splash over: deploy starts
        return sim.frame(8.0)   -- deploy finished
    end

    sim.env = env
    return sim
end

--- Serialise recorded primitives to an SVG overlay (y axis flipped back).
function M.to_svg(calls, width, height, background)
    local out = {
        string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">',
            width, height, width, height),
    }
    if background then out[#out + 1] = background end
    local function rgba(c, boost)
        return string.format("rgba(%d,%d,%d,%.3f)",
            math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5), c.a)
    end
    local function y(v) return height - v end
    local sizes = { Times_Roman_24 = 24, Helvetica_18 = 18, Helvetica_12 = 12, Helvetica_10 = 10 }
    for _, c in ipairs(calls) do
        local a = c.args
        if c.kind == "line" then
            out[#out + 1] = string.format(
                '<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="%s" stroke-width="%.2f" stroke-linecap="butt"/>',
                a[1], y(a[2]), a[3], y(a[4]), rgba(c), c.w)
        elseif c.kind == "tri" then
            out[#out + 1] = string.format('<polygon points="%.2f,%.2f %.2f,%.2f %.2f,%.2f" fill="%s"/>',
                a[1], y(a[2]), a[3], y(a[4]), a[5], y(a[6]), rgba(c))
        elseif c.kind == "disc" then
            out[#out + 1] = string.format('<circle cx="%.2f" cy="%.2f" r="%.2f" fill="%s"/>',
                a[1], y(a[2]), a[3], rgba(c))
        elseif c.kind == "circle" then
            out[#out + 1] = string.format(
                '<circle cx="%.2f" cy="%.2f" r="%.2f" fill="none" stroke="%s" stroke-width="%.2f"/>',
                a[1], y(a[2]), a[3], rgba(c), a[4] or c.w)
        elseif c.kind == "text" then
            local s = tostring(a[3]):gsub("&", "&amp;"):gsub("<", "&lt;")
            out[#out + 1] = string.format(
                '<text x="%.2f" y="%.2f" fill="%s" font-family="Menlo,DejaVu Sans Mono,monospace" '
                .. 'font-size="%d" xml:space="preserve">%s</text>',
                a[1], y(a[2]), rgba(c), sizes[a[4]] or 12, s)
        end
    end
    out[#out + 1] = "</svg>"
    return table.concat(out, "\n")
end

return M
