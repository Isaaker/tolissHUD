#!/usr/bin/env python3
"""Render a PNG preview of the HUD without X-Plane.

Runs ``xphud_toliss_a32x.lua`` against the FlyWithLua mock in ``tests/lua``
(needs a ``lua5.4`` command, or the ``lupa`` module), draws the recorded 2D
primitives over a *stand-in* cockpit scene and screenshots the result with
Playwright / Chromium.

The backdrop is a crude placeholder (sky, runway, windshield frame, glareshield);
it is not ToLiss artwork and is only meant for judging how the translucent
overlay sits against a dark cockpit surround and a bright outside world.

    python3 tools/preview_hud.py out.png [--size 1920x1080] [--progress 0.5]
                                         [--pos-y 0] [--scene day|night]
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RENDER = ROOT / "tests" / "lua" / "render_svg.lua"


def run_lua(out_svg: Path, width: int, height: int, progress: float | None, tmp: Path,
            scenario: str, calibration: bool) -> None:
    extra = [] if progress is None else [str(progress)]
    env_vars = {"XPHUD_TEST_TMP": str(tmp), "XPHUD_SCENARIO": scenario,
                "XPHUD_CALIBRATION": "1" if calibration else "0"}
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if lua:
        subprocess.run([lua, str(RENDER), str(out_svg), str(width), str(height), *extra],
                       check=True, env=env_vars)
        return
    try:
        from lupa.lua54 import LuaRuntime  # type: ignore
    except ImportError:
        sys.exit("preview_hud: need a lua5.4 binary or the 'lupa' Python package")
    import os
    os.environ.update(env_vars)
    rt = LuaRuntime(unpack_returned_tuples=True)
    args = [str(out_svg), str(width), str(height), *extra]
    rt.execute("arg = ...", rt.table_from({0: str(RENDER), **{i + 1: a for i, a in enumerate(args)}}))
    rt.execute(RENDER.read_text(encoding="utf-8"))


def scene(width: int, height: int, night: bool) -> str:
    """A rough captain's-eye scene: headliner, windshield, runway, glareshield."""
    w, h = width, height
    horizon = h * 0.47
    sky_top, sky_bot = ("#0a1226", "#1c2a48") if night else ("#4f86c8", "#bcd6ee")
    ground = "#0b0f0c" if night else "#5f7455"
    runway = "#15171a" if night else "#55585c"
    lights = "#ffd27a" if night else "#f2eee0"
    out = [
        f'<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{sky_top}"/><stop offset="1" stop-color="{sky_bot}"/></linearGradient>'
        f'<linearGradient id="gs" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#22262b"/>'
        f'<stop offset="1" stop-color="#0d0f12"/></linearGradient>'
        f'<linearGradient id="hl" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#14171b"/>'
        f'<stop offset="1" stop-color="#2a2f35"/></linearGradient></defs>',
        f'<rect width="{w}" height="{h}" fill="url(#sky)"/>',
        f'<rect y="{horizon}" width="{w}" height="{h - horizon}" fill="{ground}"/>',
    ]
    # runway + centre line + approach lights
    vx, vy = w * 0.5, horizon
    out.append(f'<polygon points="{vx - 6},{vy} {vx + 6},{vy} {vx + w * 0.16},{h * 0.80} {vx - w * 0.16},{h * 0.80}" fill="{runway}"/>')
    for i in range(14):
        t = (i + 1) / 14
        y = vy + (h * 0.80 - vy) * t ** 1.6
        ww = 2 + 24 * t ** 1.6
        out.append(f'<rect x="{vx - ww / 2}" y="{y}" width="{ww}" height="{1 + 4 * t}" fill="{lights}" opacity="0.8"/>')
    for side in (-1, 1):
        for i in range(10):
            t = (i + 1) / 10
            y = vy + (h * 0.80 - vy) * t ** 1.6
            x = vx + side * (10 + w * 0.15 * t ** 1.6)
            out.append(f'<circle cx="{x}" cy="{y}" r="{1 + 2.5 * t}" fill="{lights}"/>')
    # headliner / overhead panel, windshield pillars, glareshield
    out.append(f'<rect width="{w}" height="{h * 0.085}" fill="url(#hl)"/>')
    out.append(f'<polygon points="0,0 {w * 0.12},0 {w * 0.075},{h * 0.86} 0,{h * 0.86}" fill="#16191d"/>')
    out.append(f'<polygon points="{w},0 {w * 0.88},0 {w * 0.925},{h * 0.86} {w},{h * 0.86}" fill="#16191d"/>')
    out.append(f'<polygon points="{w * 0.48},0 {w * 0.52},0 {w * 0.515},{h * 0.86} {w * 0.485},{h * 0.86}" fill="#16191d" opacity="0.0"/>')
    out.append(f'<rect y="{h * 0.86}" width="{w}" height="{h * 0.14}" fill="url(#gs)"/>')
    out.append(f'<rect y="{h * 0.86}" width="{w}" height="3" fill="#3b4148"/>')
    if night:
        out.append(f'<rect width="{w}" height="{h}" fill="#000" opacity="0.18"/>')
    return "\n".join(out)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("output", type=Path)
    ap.add_argument("--size", default="1920x1080")
    ap.add_argument("--progress", type=float, default=None, help="freeze deploy animation (0..1)")
    ap.add_argument("--scene", choices=("day", "night"), default="day")
    ap.add_argument("--crop", default=None, help="x,y,w,h crop in pixels (after rendering)")
    ap.add_argument("--pref", action="append", default=[], metavar="KEY=VALUE",
                    help="override a saved preference, e.g. --pref eye_distance_cm=100 (repeatable)")
    ap.add_argument("--unpowered", action="store_true", help="no datarefs: aircraft unpowered")
    ap.add_argument("--calibration", action="store_true", help="show the calibration pattern")
    args = ap.parse_args()
    width, height = (int(v) for v in args.size.lower().split("x"))

    from playwright.sync_api import sync_playwright

    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        overlay = tmp / "overlay.svg"
        if args.pref:
            prefs = tmp / "Output" / "preferences"
            prefs.mkdir(parents=True)
            (prefs / "xphud_toliss_a32x.prefs").write_text(
                "prefs_version=2\n" + "\n".join(args.pref) + "\n# end of preferences\n", encoding="utf-8")
        run_lua(overlay, width, height, args.progress, tmp,
                "unpowered" if args.unpowered else "approach", args.calibration)
        page = tmp / "page.html"
        page.write_text(
            f'<!doctype html><meta charset="utf-8"><style>html,body{{margin:0;background:#000}}'
            f'svg{{position:absolute;left:0;top:0}}</style>'
            f'<svg width="{width}" height="{height}">{scene(width, height, args.scene == "night")}</svg>'
            f'{overlay.read_text(encoding="utf-8")}',
            encoding="utf-8",
        )
        with sync_playwright() as pw:
            browser = pw.chromium.launch()
            pg = browser.new_page(viewport={"width": width, "height": height})
            pg.goto(page.as_uri())
            clip = None
            if args.crop:
                x, y, cw, ch = (int(v) for v in args.crop.split(","))
                clip = {"x": x, "y": y, "width": cw, "height": ch}
            pg.screenshot(path=str(args.output), clip=clip)
            browser.close()
    print(f"wrote {args.output}")


if __name__ == "__main__":
    main()
