-- Offline tests for xphud_toliss_a32x.lua using the FlyWithLua mock.
--
--   lua5.4 tests/lua/run_tests.lua          (from the repository root)
--
-- Exits non-zero (raises an error) if any check fails.  These tests exercise
-- pure logic and the drawing code path; they do not replace the simulator test
-- matrix in TODO.md section 11.

local here = (arg and arg[0] or "tests/lua/run_tests.lua"):match("^(.*)[/\\]") or "."
here = here .. "/"
local SCRIPT = here .. "../../xphud_toliss_a32x.lua"
local mock = dofile(here .. "fwl_mock.lua")

local passed, failed = 0, 0
local function check(cond, name, detail)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. name .. (detail and (" -- " .. tostring(detail)) or ""))
    end
end
local function close(a, b, eps) return math.abs(a - b) <= (eps or 1e-9) end

-- Scratch directory with the Output/preferences layout the script expects.
local scratch = os.tmpname()
os.remove(scratch)
scratch = scratch .. "_xphud"
assert(os.execute('mkdir -p "' .. scratch .. '/Output/preferences"'))
local PREFS = scratch .. "/Output/preferences/xphud_toliss_a32x.prefs"

local function new_sim(opts)
    opts = opts or {}
    opts.prefs_dir = scratch .. "/"
    local sim = mock.new(opts)
    sim.env.XPHUD_TEST_HOOKS = true
    sim.load(SCRIPT)
    return sim
end
local function write_file(path, text)
    local f = assert(io.open(path, "w")); f:write(text); f:close()
end
local function read_file(path)
    local f = io.open(path, "r"); if not f then return nil end
    local t = f:read("a"); f:close(); return t
end
local function exists(path) local f = io.open(path, "r"); if f then f:close() return true end return false end
local function has_log(sim, needle)
    for _, l in ipairs(sim.logs) do if l:find(needle, 1, true) then return true end end
    return false
end
local function count(calls, kind)
    local n = 0
    for _, c in ipairs(calls) do if kind == nil or c.kind == kind then n = n + 1 end end
    return n
end

-- ---------------------------------------------------------------- loading --
do
    local sim = new_sim()
    check(sim.env.xa32_test ~= nil, "test hooks exposed when requested")
    check(sim.commands["XPHUD_A32X/Toggle"], "toggle command registered")
    check(not has_log(sim, "error"), "no error logged at load", table.concat(sim.logs, " | "))
    local plain = mock.new({ prefs_dir = scratch .. "/" })
    plain.load(SCRIPT)
    check(plain.env.xa32_test == nil, "no test hooks without opt-in")
end

-- ------------------------------------------------------------ angle wraps --
do
    local t = new_sim().env.xa32_test
    for _, case in ipairs({
        { 0, 0, 0 }, { 360, 0, 0 }, { 361, 1, 1 }, { -1, 359, -1 }, { 180, 180, -180 },
        { 179, 179, 179 }, { -180, 180, -180 }, { 540, 180, -180 }, { -361, 359, -1 },
        { 719.5, 359.5, -0.5 },
    }) do
        check(close(t.wrap360(case[1]), case[2]), "wrap360(" .. case[1] .. ")", t.wrap360(case[1]))
        check(close(t.wrap180(case[1]), case[3]), "wrap180(" .. case[1] .. ")", t.wrap180(case[1]))
    end
    -- shortest-angle difference across north
    check(close(t.wrap180(1 - 359), 2), "wrap180 across north (1 - 359)")
    check(close(t.wrap180(359 - 1), -2), "wrap180 across north (359 - 1)")
end

-- ---------------------------------------------------- combiner geometry --
local function point_in_quad(px, py, q)     -- convex quad, either winding
    local sign
    for i = 1, 4 do
        local a, b = q[i], q[(i % 4) + 1]
        local cross = (b[1] - a[1]) * (py - a[2]) - (b[2] - a[2]) * (px - a[1])
        if cross ~= 0 then
            local s = cross > 0
            if sign == nil then sign = s elseif sign ~= s then return false end
        end
    end
    return true
end

do
    local sim = new_sim()
    local t = sim.env.xa32_test
    local DIST = { 45, 55, 60, 70, 85, 100, 120 }
    for _, d in ipairs(DIST) do
        t.cfg.eye_distance_cm = d
        local scale = t.eye_scale()
        for _, size in ipairs({ 300, 600, 1000 }) do
            local S = size * scale
            local g = t.assembly_geometry(960, 540, S, 1)
            -- The glass must enclose the whole symbology area at every distance.
            local safe = {
                { 960 - 0.5 * S, 540 - 0.5 * S }, { 960 + 0.5 * S, 540 - 0.5 * S },
                { 960 + 0.5 * S, 540 + 0.49 * S }, { 960 - 0.5 * S, 540 + 0.49 * S },
            }
            for i, p in ipairs(safe) do
                check(point_in_quad(p[1], p[2], g.glass),
                      string.format("glass encloses symbology corner %d (d=%d size=%d)", i, d, size))
            end
        end
    end

    -- Perspective: lower edge nearer the pilot -> wider than the upper edge, and
    -- the convergence grows as the eye distance shrinks.
    local function taper(d)
        t.cfg.eye_distance_cm = d
        local g = t.assembly_geometry(960, 540, 500, 1)
        local top = g.glass[2][1] - g.glass[1][1]
        local bottom = g.glass[3][1] - g.glass[4][1]
        return bottom / top
    end
    check(taper(70) > 1.02, "deployed glass is a trapezoid (bottom wider)", taper(70))
    check(taper(45) > taper(70) and taper(70) > taper(120), "perspective convergence grows when closer")

    -- Moving the combiner away shrinks the whole assembly.
    t.cfg.eye_distance_cm = 60; local s60 = t.eye_scale()
    t.cfg.eye_distance_cm = 90; local s90 = t.eye_scale()
    check(close(s60, 1.0) and s90 < s60, "eye scale: 1.0 at 60 cm and smaller when further")
    t.cfg.eye_distance_cm = 70
    check(t.eye_scale() < 1.0, "default distance sits further than the 60 cm reference")
    check(t.DEFAULTS.eye_distance_cm == 70, "default eye distance is 70 cm")

    -- Every projected point is finite through the whole deploy swing.
    for _, d in ipairs(DIST) do
        t.cfg.eye_distance_cm = d
        for sw = 0, 1, 0.125 do
            local g = t.assembly_geometry(960, 540, 400, sw)
            for _, p in ipairs(g.glass) do
                check(p[1] == p[1] and p[2] == p[2] and math.abs(p[1]) < 1e6 and math.abs(p[2]) < 1e6,
                      string.format("finite glass corner (d=%d swing=%.3f)", d, sw))
            end
        end
    end
end

-- ------------------------------------------------------------- drawing --
local function max_dark_alpha(calls)       -- strongest alpha among dark (hardware) fills
    local m = 0
    for _, c in ipairs(calls) do
        if c.kind == "tri" and c.r < 0.3 and c.g < 0.3 and c.b < 0.3 and c.a > m then m = c.a end
    end
    return m
end

do
    local sim = new_sim()
    local calls = sim.settle()
    check(count(calls) > 100, "approach scenario draws a populated HUD", count(calls))
    check(count(calls, "text") > 10, "symbology text is drawn")
    check(not has_log(sim, "draw error"), "no draw error", table.concat(sim.logs, " | "))
    local with_hw = count(calls)
    local hw_alpha = max_dark_alpha(calls)

    -- Hardware opacity is independent of the symbology brightness control.
    sim.env.xa32_test.cfg.hud_alpha = 0.2
    local dim = sim.frame(9.0)
    check(close(max_dark_alpha(dim), hw_alpha, 1e-6),
          "hardware opacity unaffected by symbology brightness", max_dark_alpha(dim) .. " vs " .. hw_alpha)
    sim.env.xa32_test.cfg.hud_alpha = 1.0

    sim.env.xa32_test.cfg.show_hardware = false
    local no_hw = count(sim.frame(10.0))
    check(no_hw < with_hw - 40, "disabling hardware removes its primitives", no_hw .. " vs " .. with_hw)
    sim.env.xa32_test.cfg.show_hardware = true

    sim.env.xa32_test.cfg.show_glass = false
    local no_glass = count(sim.frame(11.0))
    check(no_glass < with_hw, "disabling glass removes its primitives")
    sim.env.xa32_test.cfg.show_glass = true

    -- Night profile dims the hardware.
    sim.env.xa32_test.cfg.night_profile = true
    local night = max_dark_alpha(sim.frame(12.0))
    check(night < hw_alpha * 0.6, "night profile dims hardware", night .. " vs " .. hw_alpha)
end

do   -- unpowered aircraft: combiner visible, no symbology text except the unit plate
    local sim = new_sim({ datarefs = {}, strings = {} })
    local calls = sim.settle()
    check(count(calls, "tri") > 50, "unpowered: hardware and glass still drawn")
    check(count(calls, "text") <= 1, "unpowered: no symbology text", count(calls, "text"))
end

do   -- deploy / stow animation
    local sim = new_sim()
    local full = count(sim.settle())
    sim.env.xa32_toggle()                        -- stow
    local mid = sim.frame(8.4)
    check(count(mid) > 0, "stowing animation draws while moving")
    sim.frame(8.4 + 0.8)
    local done = sim.frame(8.4 + 2.0)
    check(count(done) == 0, "nothing drawn once stowed", count(done))
    sim.env.xa32_toggle()                        -- deploy again
    local t0 = 11.0
    local first = sim.frame(t0)
    local early = sim.frame(t0 + 0.15)
    local late = sim.frame(t0 + 3.0)
    check(count(late) == full, "deployed frame matches the original", count(late) .. " vs " .. full)
    check(count(early, "text") < count(late, "text"), "symbology fades in after the combiner swings down")
    check(count(first) <= count(early) + 200, "deploy start is well-formed")
end

do   -- calibration pattern replaces live symbology
    local sim = new_sim()
    sim.settle()
    local live_text = count(sim.frame(9.0), "text")
    sim.env.xa32_test.set_calibration(true)
    local cal = sim.frame(9.5)
    local found = false
    for _, c in ipairs(cal) do
        if c.kind == "text" and tostring(c.args[3]):find("CALIBRATION", 1, true) then found = true end
    end
    check(found, "calibration pattern labelled")
    check(count(cal, "text") < live_text, "calibration replaces live symbology")
    sim.env.xa32_test.set_calibration(false)
end

do   -- small screens do not error
    for _, size in ipairs({ { 1280, 720 }, { 800, 600 }, { 3840, 2160 } }) do
        local sim = new_sim({ width = size[1], height = size[2] })
        local calls = sim.settle()
        check(count(calls) > 100 and not has_log(sim, "draw error"),
              string.format("draws at %dx%d", size[1], size[2]))
    end
end

-- ----------------------------------------------------------- preferences --
do
    os.remove(PREFS)
    local sim = new_sim()
    local t = sim.env.xa32_test
    t.cfg.eye_distance_cm = 88
    t.cfg.theme = "classic"
    t.save_prefs()
    local text = read_file(PREFS)
    check(text and text:find("prefs_version=" .. t.PREFS_VERSION, 1, true), "saved prefs carry a version")
    check(text and text:find("eye_distance_cm=88", 1, true), "saved prefs include eye distance")
    check(text and text:find("# end of preferences", 1, true), "saved prefs end with a marker")
    check(not exists(PREFS .. ".tmp"), "no temporary file left after save")
    check(not (text or ""):find("mount_standoff_cm", 1, true), "retired setting is not written")

    -- round trip
    t.cfg.eye_distance_cm = 70; t.cfg.theme = "green"
    t.load_prefs()
    check(t.cfg.eye_distance_cm == 88 and t.cfg.theme == "classic", "preferences round-trip")

    -- overwriting an existing file works (the Windows rename path)
    t.cfg.eye_distance_cm = 52
    t.save_prefs()
    check((read_file(PREFS) or ""):find("eye_distance_cm=52", 1, true) ~= nil, "second save replaces the file")
    check(not exists(PREFS .. ".tmp"), "no temporary file after overwrite")
end

do   -- legacy (version 1) file is migrated
    write_file(PREFS, "# old\nsize=640\nhardware_alpha=0.72\nmount_standoff_cm=6.5\ntheme=modern\n")
    local sim = new_sim()
    local c = sim.env.xa32_test.cfg
    check(c.size == 640 and c.theme == "modern", "legacy values still applied")
    check(close(c.hardware_alpha, sim.env.xa32_test.DEFAULTS.hardware_alpha), "old default opacity adopts new default", c.hardware_alpha)
    check(c.mount_standoff_cm == nil, "retired key is not loaded")
    check(has_log(sim, "no end marker"), "legacy file without marker is noted")

    write_file(PREFS, "hardware_alpha=0.5\n")
    local sim2 = new_sim()
    check(close(sim2.env.xa32_test.cfg.hardware_alpha, 0.5), "customised opacity survives migration")
end

do   -- validation and recovery
    write_file(PREFS, table.concat({
        "prefs_version=2", "eye_distance_cm=999", "size=nan", "show_glass=maybe", "theme=neon",
        "line_w=3.5", "garbage line", "# end of preferences", "",
    }, "\n"))
    local sim = new_sim()
    local c = sim.env.xa32_test.cfg
    check(c.eye_distance_cm == 120, "out-of-range value clamped", c.eye_distance_cm)
    check(c.size == sim.env.xa32_test.DEFAULTS.size, "invalid number falls back to default")
    check(c.show_glass == true, "invalid boolean falls back to default")
    check(c.theme == "green", "invalid option falls back to default")
    check(c.line_w == 3.5, "valid values next to invalid ones still load")
    check(has_log(sim, "out-of-range preference"), "clamping is logged")
    check(has_log(sim, "invalid numeric preference"), "invalid number is logged")
    check(has_log(sim, "invalid boolean preference"), "invalid boolean is logged")
    check(has_log(sim, "invalid option preference"), "invalid option is logged")

    -- interrupted write: valid prefix still loads
    write_file(PREFS, "prefs_version=2\nline_w=4.5\nsize=7")
    local sim2 = new_sim()
    check(sim2.env.xa32_test.cfg.line_w == 4.5, "valid entries survive a truncated file")
    check(has_log(sim2, "no end marker"), "truncation is noted")

    write_file(PREFS, "prefs_version=99\nline_w=2\n# end of preferences\n")
    local sim3 = new_sim()
    check(has_log(sim3, "newer version"), "newer preference version is noted")
end

os.remove(PREFS)
os.remove(PREFS .. ".tmp")
os.execute('rm -rf "' .. scratch .. '"')

print(string.format("lua tests: %d passed, %d failed", passed, failed))
if failed > 0 then error(string.format("%d Lua test(s) failed", failed)) end
