-- Render the HUD overlay to an SVG using the FlyWithLua mock.
--
--   lua5.4 tests/lua/render_svg.lua OUT.svg [WIDTH HEIGHT [PROGRESS]]
--
-- PROGRESS (0..1, optional) freezes the combiner deploy animation part-way.
-- The SVG contains only what the script draws (transparent background); the
-- preview tool composites it over a stand-in cockpit scene.

local out_path = arg[1] or "hud_overlay.svg"
local width = tonumber(arg[2]) or 1920
local height = tonumber(arg[3]) or 1080
local progress = tonumber(arg[4])

local here = (arg[0]:match("^(.*)[/\\]") or ".") .. "/"
package.path = here .. "?.lua;" .. package.path
local mock = dofile(here .. "fwl_mock.lua")

-- Environment switches (used by tools/preview_hud.py):
--   XPHUD_TEST_TMP      scratch directory; preferences are read from
--                       <dir>/Output/preferences/xphud_toliss_a32x.prefs
--   XPHUD_SCENARIO      "approach" (default) or "unpowered" (no datarefs at all)
--   XPHUD_CALIBRATION   "1" shows the calibration pattern
local tmp = os.getenv("XPHUD_TEST_TMP") or "."
local opts = { width = width, height = height, prefs_dir = tmp .. "/" }
if os.getenv("XPHUD_SCENARIO") == "unpowered" then opts.datarefs = {}; opts.strings = {} end
_G.XPHUD_TEST_HOOKS = (os.getenv("XPHUD_CALIBRATION") == "1") or nil
local sim = mock.new(opts)
sim.env.XPHUD_TEST_HOOKS = _G.XPHUD_TEST_HOOKS
sim.load(here .. "../../xphud_toliss_a32x.lua")
if os.getenv("XPHUD_CALIBRATION") == "1" then sim.env.xa32_test.set_calibration(true) end

local calls
if progress then
    sim.frame(1.0)                       -- start boot splash
    sim.frame(3.5)                       -- splash done -> deploying (t0 = 3.5)
    calls = sim.frame(3.5 + progress * 1.25)
else
    calls = sim.settle()
end

local f = assert(io.open(out_path, "w"))
f:write(mock.to_svg(calls, width, height))
f:close()
print(string.format("wrote %s (%d primitives)", out_path, #calls))
