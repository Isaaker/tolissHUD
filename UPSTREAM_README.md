# XPHUD for FlyWithLua

**v2.0.0** &mdash; a universal head-up display for X-Plane 12. Home:
[xpconnect.me](https://xpconnect.me). Distributed through XPConnect.

XPHUD draws a head-up display as a FlyWithLua script, so it runs on any current
X-Plane 12 install with no SDK and no per-aircraft setup. It detects what you are
flying and shows the matching element set:

- a **helicopter** hover trainer (the movement-vector arrow it grew out of),
- a **fixed-wing** flight-path HUD built around the velocity vector, and
- a **weapons / combat** overlay that appears whenever the aircraft carries
  stores.

Every value comes from a stock, publicly documented X-Plane dataref.

> XPHUD is the general-purpose descendant of xbard's **HeliHud for FlyWithLua**,
> which continues as its own release at
> <https://codeberg.org/xbard/XP_HeliHud>. It also carries a force-trim for
> spring-centred cyclics, after Carsten Lynker's HeliTrim.

## Install

1. Have [FlyWithLua NG+](https://forums.x-plane.org/index.php?/files/file/82888-flywithlua-ng-next-generation-plus-edition-for-x-plane-12-win-lin-mac/)
   installed.
2. Copy `xphud.lua` into:
   `X-Plane 12/Resources/plugins/FlyWithLua/Scripts/xphud.lua`
3. Start X-Plane, or in a running sim use **Plugins → FlyWithLua → Reload all
   Lua scripts**.

## Controls

- **Plugins → FlyWithLua → Macros → XPHUD: toggle HUD** — show/hide.
- **Plugins → FlyWithLua → Macros → XPHUD: settings window** — open the settings
  panel (every element, units, colours, sizes, ranges).
- Commands you can bind to a joystick/keyboard:
  - `XPHUD/Toggle` — show/hide the HUD
  - `XPHUD/Settings` — open the settings window
  - `XPHUD/Center` — snap the HUD back to screen centre
  - `XPHUD/TrimForce` — force-trim release (hold)
  - `XPHUD/TrimSet` — set trim to the current stick (one press)
  - `XPHUD/TrimOff` — release trim (panic / hand back to the stick)
- Shared dataref `XPHUD/Visible` (int, writable) for external control.

Settings persist to `Output/preferences/xphud.prefs` and are saved automatically
as you change them.

## Positioning

By default the HUD sits centred. To move it (handy for chase / external views),
use the **X / Y offset** sliders in the settings window; the **Centre HUD**
button snaps it back. The HUD never intercepts a mouse click, so cockpit switches
behind it stay clickable, and the position is saved with your other settings.

## Elements

The heli, fixed-wing and weapons sets switch automatically with the loaded
aircraft. The **Aircraft:** button in settings forces the heli/fixed-wing choice;
the **Weapons:** button forces the combat overlay on or off. Everything is
individually toggleable.

**Shared** — centre brackets + pitch/roll box, VSI ball, VSI and IAS tapes, wind
arrow + speed, ground speed, slip ball + yaw string, torque (split per engine
when they differ), heading / baro-altitude / radar-altitude row, horizon + pitch
ladder, bank scale + slip trapezoid, heading tape + ground-track diamond,
acceleration cue, OAT / G / baro.

**Helicopter** — movement vector arrow (the hover trainer), landing bars, rotor
RPM (NR%), and a VRS warning driven by X-Plane's own vortex-ring-state model.

**Fixed-wing** — flight path vector (the inertial velocity vector, riding the
pitch ladder at the flown climb angle and drifting with the wind), AoA bracket
(on-speed indexer against the aircraft's stall-warn alpha; hidden when the
aircraft author never set one), ILS localizer + glideslope deviation dots
(following whatever source the pilot's HSI is on), gear / flap cues (hidden
entirely on fixed-gear or flapless aircraft), and an airspeed trend caret
projecting speed 10 s ahead beside the IAS tape.

**Weapons / combat** (shown when the aircraft carries stores) — a **master-arm**
and per-category arming state (guns / rockets / missiles / bombs); a **gun
pipper** drawn at X-Plane's own gun-sight solution, with rounds remaining and a
firing flash; a **stores** summary (count, selected station, fire mode); a
**target designator** box at the selected weapon's azimuth/elevation to its
target, with slant range; an **AA heat-seeker** reticle that reads **LOCK** on
tone; an **incoming-missile** warning; and **chaff / flare** counters. All of it
reads stock `sim/weapons` and `sim/cockpit2/weapons` datarefs, so it works on any
armed aircraft with no setup.

Three colour themes: **modern** glass-cockpit, **classic** 2011 palette, and
**green** monochrome military. A master **HUD opacity** control and a **box
shading** control tune how bold or faded the whole thing reads. Units switch
between knots / km/h / m/s / mph, feet / metres, and fpm / m/s.

## Force-trim

A spring-centred joystick has no way to hold a helicopter's off-centre cyclic, so
you fight the stick constantly. Force-trim fixes that: it overrides the control
ratios so a captured stick position becomes the new logical centre. Bind either
style to a cyclic button:

- **`XPHUD/TrimForce` (hold)** — hold the button, reposition (recentre) your
  physical stick, release. That attitude now holds with a centred stick. This is
  the real force-trim-release feel and it avoids a capture bump.
- **`XPHUD/TrimSet` (one press)** — one press captures the current stick as the
  centre. Simpler, with a brief control bump at the tap.

The HUD shows a **TRIM** annunciator and a hollow diamond at the trimmed cyclic
position while it is engaged. `XPHUD/TrimOff` (or the settings **Release trim
now** button) always hands control straight back to the stick. The feature is
gated so it only touches the controls while you actively trim, and it defaults to
inert until you bind a button. Sensitivity is adjustable in the settings window.

By default force-trim leaves the **anti-torque pedals** untouched and trims only
the cyclic, since most pedal hardware holds its own position and does not need a
trimmed centre. Tick **Trim anti-torque pedals** in the settings window if you
want the pedals captured too (for spring-centred pedals).

## Notes / limitations

- Drawing uses FlyWithLua's 2D OpenGL callback, which runs fine under X-Plane's
  Vulkan/Metal compatibility layer.
- FlyWithLua only offers a few fixed bitmap fonts, so the **Text size** slider
  snaps to the nearest available size rather than scaling smoothly. This is the
  one visible trade-off versus a native-SDK build.
- Aircraft detection uses `sim/aircraft2/metadata/is_helicopter` (and `is_vtol`)
  for the heli/fixed-wing split and `sim/weapons/weapon_count` for the combat
  overlay. The rare add-on that misdeclares itself just needs the **Aircraft:**
  or **Weapons:** override in settings.
- XPHUD coexists with other trim/assist scripts (HeliTrim, Heli hovering assist,
  ...). It writes the joystick control-ratio and override datarefs through raw
  XPLM accessors, so it will not be quarantined for sharing them. Only run one
  trim system at a time, though: whichever writes last each frame wins, so two
  active trims will fight.

## Credit & licence

Built by xbard, on the shoulders of giants:

- The original **HeliHUD** was designed, developed and released by **Steve
  Hanley** for Microsoft Flight Simulator 2004 in September 2003, as freeware.
- **HUD** after Petr Medek's HeliHud (2011, <https://github.com/me2d13/helihud>)
- **Force-trim** after Carsten Lynker's HeliTrim (bundled with FlyWithLua)

Medek's HeliHud and Lynker's HeliTrim are MIT-licensed. This is a separate
implementation written for FlyWithLua, released under the **MIT licence** — see
[LICENSE](LICENSE).
