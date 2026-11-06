# XPHUD Native 3D hardware prototype

This directory contains an **experimental optional X-Plane plugin** and an original OBJ8 combiner-support model. It is not part of the stable Lua-only release.

## What it does

- Loads an original OBJ8 frame/support via XPLM object instancing.
- Places it relative to the loaded aircraft using X-Plane position and attitude datarefs.
- Requires both a ToLiss aircraft path and the AirbusFBW/APHDG_Capt marker dataref before showing the object. The marker is checked for presence only; it is never read or written.
- Hides the object in external views.
- Adds a Plugins-menu calibration panel for XYZ position and pitch/yaw/roll offsets.
- Saves calibration to Output/preferences/xphud_native3d.cfg.

## Important limitations

This is **physical-looking 3D hardware only**. It is an aircraft-relative world instance, not an object embedded inside the ToLiss cockpit. It does not use ATTR_hud_glass, is not collimated, does not provide optical infinity, and does not solve eye-point registration or parallax. The existing Lua symbology remains a separate screen-space overlay and is not drawn onto this pane.

The default position (-0.58, 1.15, -7.0) metres is a rough placeholder, not a measured A320 cockpit datum. Use Plugins → XPHUD Native 3D to nudge the object and save the calibration. Position steps are 1 cm / 5 cm; angular steps are 0.5 degrees. Exact placement must be calibrated in the simulator for the user's aircraft, cockpit, view and seat position.

## Build

Requires the official Laminar Research X-Plane SDK 4.3.0, CMake 3.20+ and a C++17 compiler.

    cmake -S native3d -B build/native3d -DXPLANE_SDK_ROOT=/path/to/SDK
    cmake --build build/native3d --config Release

The Native 3D prototype GitHub Actions workflow downloads the official SDK and builds Linux, Windows, macOS Intel and Apple Silicon variants. Only use a binary from a successful official-SDK workflow run; local mock-header builds are not installable builds.

## Experimental manual installation

Copy the platform binary into:

    X-Plane 12/Resources/plugins/XPHUD_Native3D/64/lin.xpl   (Linux)
    X-Plane 12/Resources/plugins/XPHUD_Native3D/64/win.xpl   (Windows)
    X-Plane 12/Resources/plugins/XPHUD_Native3D/64/mac.xpl   (macOS)

Copy xphud_native_combiner.obj and xphud_native_combiner.png from native3d/objects/ to:

    X-Plane 12/Resources/plugins/XPHUD_Native3D/objects/

Restart X-Plane and open Plugins → XPHUD Native 3D. Remove the XPHUD_Native3D folder to uninstall. The existing FlyWithLua HUD remains independent; disable this plugin at any time from Plugin Admin.

## Distribution and safety

- No ToLiss aircraft package file, mesh, texture or proprietary aircraft material is included or modified.
- The plugin never writes aircraft-system, autopilot or navigation datarefs.
- The OBJ8 model and texture are original project assets released under the repository licence.
- This prototype is excluded from the stable release and SkunkCrafts depot until its official-SDK builds and in-simulator validation are complete.
