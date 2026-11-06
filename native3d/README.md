# XPHUD Native 3D hardware prototype

This directory contains an **experimental optional X-Plane plugin** and an original OBJ8 combiner-support model. It is not part of the stable Lua-only release.

## What it does

- Loads an original OBJ8 frame/support via XPLM object instancing.
- Places it relative to the loaded aircraft using X-Plane position and attitude datarefs.
- Anchors its initial position to X-Plane's aircraft pilot-eye reference datarefs: `sim/aircraft/view/acf_peX`, `acf_peY` and `acf_peZ`.
- Detects ToLiss using either the aircraft path or the `AirbusFBW/APHDG_Capt` marker. The marker is checked for presence only; it is never read or written.
- Hides the object in external views.
- Adds a Plugins-menu calibration panel for XYZ offsets and pitch/yaw/roll.
- Adds a diagnostic entry that reports aircraft detection, OBJ loading, instance creation and the pilot-eye coordinates to `Log.txt`.
- Saves calibration to `Output/preferences/xphud_native3d.cfg`.

## Positioning change

The first prototype used a guessed aircraft-origin position (`-0.58, 1.15, -7.0 m`). That was not measured against the ToLiss cockpit and could place the model outside the captain's forward field of view.

The new preset is an offset from X-Plane's pilot-eye reference:
- X: `0.000 m`
- Y: `-0.425 m`
- Z: `-0.800 m`

The OBJ combiner pane is centred at approximately Y=0.425 m and Z=0.116 m from its origin. This preset therefore puts the pane centre roughly level with the reference eye point and about 0.68 m forward of it. This is a **geometric starting estimate**, not a measured ToLiss/A320 installation coordinate. Reset to the eye-point preset from the plugin menu to restore it.

XYZ menu adjustments are now offsets from the pilot-eye reference, not absolute coordinates from the aircraft CG. X is positive right, Y positive up and Z positive aft. Use 1 cm / 5 cm position steps and 0.5 degree angular steps. The diagnostic menu item writes the current pilot-eye datarefs and calculated aircraft-frame origin to `Log.txt`.

The aircraft-coordinate conversion follows Laminar Research's published transformation:
https://developer.x-plane.com/article/screencoordinates/

## Important limitations

This is **physical-looking 3D hardware only**. It is an aircraft-relative world instance, not an object embedded inside the ToLiss cockpit. It does not use `ATTR_hud_glass`, is not collimated, does not provide optical infinity, and does not solve eye-point registration or parallax. The existing Lua symbology remains a separate screen-space overlay and is not drawn onto this pane.

If the object still does not appear, open `Plugins → XPHUD Native 3D → Print diagnostics to Log.txt` and inspect the last `XPHUD Native3D:` entries in X-Plane's `Log.txt`. This distinguishes a failed ToLiss gate, missing pilot-eye datarefs, OBJ load failure, and instance-creation failure from a placement/calibration problem.

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
