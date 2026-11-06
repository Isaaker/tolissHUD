// XPHUD Native 3D hardware prototype. Copyright (c) 2026 Control_TWR.
// Optional physical-looking hardware only; Lua symbology remains a separate 2D overlay.
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <XPLMDataAccess.h>
#include <XPLMInstance.h>
#include <XPLMMenus.h>
#include <XPLMPlanes.h>
#include <XPLMPlugin.h>
#include <XPLMProcessing.h>
#include <XPLMScenery.h>
#include <XPLMUtilities.h>
#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <string>

#if !defined(XPLM300)
#error "XPHUD Native 3D requires XPLM300 or newer."
#endif

namespace {
constexpr const char *kObj = "Resources/plugins/XPHUD_Native3D/objects/xphud_native_combiner.obj";
constexpr const char *kMarker = "AirbusFBW/APHDG_Capt";

// XYZ are offsets from X-Plane's aircraft pilot-eye reference (acf_peX/Y/Z),
// not absolute aircraft coordinates. The pane centre is approximately at eye
// height and 0.68 m ahead of the reference eye point with this preset.
struct Cal {
    double x = 0.000;
    double y = -0.425;
    double z = -0.800;
    double pitch = 0.0;
    double heading = 0.0;
    double roll = 0.0;
    bool enabled = true;
} cal;

struct Refs {
    XPLMDataRef x = nullptr, y = nullptr, z = nullptr;
    XPLMDataRef psi = nullptr, theta = nullptr, phi = nullptr;
    XPLMDataRef eyeX = nullptr, eyeY = nullptr, eyeZ = nullptr;
} refs;

XPLMDataRef marker = nullptr;
XPLMObjectRef object = nullptr;
XPLMInstanceRef instance = nullptr;
XPLMMenuID menu = nullptr;
bool running = false, tried = false, toliss = false;
bool refsWarningLogged = false;
float retry = 0.0f, aircraftTimer = 1.0f, step = 0.01f;
int tokens[26]{};
constexpr float angleStep = 0.5f;

double limit(double v, double lo, double hi) {
    return std::max(lo, std::min(hi, v));
}

void log(const std::string &s) {
    XPLMDebugString(("XPHUD Native3D: " + s + "\n").c_str());
}

std::string configPath() {
    char root[1024]{};
    XPLMGetSystemPath(root);
    std::string p(root);
    if (!p.empty() && p.back() != '/' && p.back() != '\\') p += '/';
    return p + "Output/preferences/xphud_native3d.cfg";
}

void loadConfig() {
    std::ifstream in(configPath());
    std::string line;
    while (std::getline(in, line)) {
        const auto n = line.find('=');
        if (n == std::string::npos) continue;
        const auto key = line.substr(0, n);
        const auto value = line.substr(n + 1);
        char *end = nullptr;
        const double d = std::strtod(value.c_str(), &end);
        if (end == value.c_str() || *end || !std::isfinite(d)) continue;
        if (key == "x") cal.x = limit(d, -2.0, 2.0);
        else if (key == "y") cal.y = limit(d, -2.0, 2.0);
        else if (key == "z") cal.z = limit(d, -5.0, 2.0);
        else if (key == "pitch") cal.pitch = limit(d, -30.0, 30.0);
        else if (key == "heading") cal.heading = limit(d, -30.0, 30.0);
        else if (key == "roll") cal.roll = limit(d, -30.0, 30.0);
        else if (key == "enabled") cal.enabled = d != 0.0;
    }
}

void saveConfig() {
    std::ofstream out(configPath(), std::ios::trunc);
    if (!out) {
        log("Cannot save calibration preferences.");
        return;
    }
    out.setf(std::ios::fixed);
    out.precision(4);
    out << "# XYZ offsets from the aircraft pilot-eye reference (acf_peX/Y/Z).\n"
        << "x=" << cal.x << "\ny=" << cal.y << "\nz=" << cal.z
        << "\npitch=" << cal.pitch << "\nheading=" << cal.heading
        << "\nroll=" << cal.roll << "\nenabled=" << (cal.enabled ? 1 : 0) << "\n";
    log("Calibration saved.");
}

void printCal() {
    char b[256]{};
    std::snprintf(
        b, sizeof(b),
        "captain eye-point offset XYZ %.3f %.3f %.3f m / P-H-R %.2f %.2f %.2f deg / step %.3f m",
        cal.x, cal.y, cal.z, cal.pitch, cal.heading, cal.roll, step
    );
    log(b);
}

void getAircraftName(char *file, std::size_t fileSize, char *path, std::size_t pathSize) {
    if (file && fileSize) file[0] = '\0';
    if (path && pathSize) path[0] = '\0';
    XPLMGetNthAircraftModel(0, file, path);
}

void printDiagnostics() {
    char file[256]{}, path[1024]{};
    getAircraftName(file, sizeof(file), path, sizeof(path));

    const bool pathMatch = [&]() {
        std::string id = std::string(file) + " " + path;
        std::transform(id.begin(), id.end(), id.begin(),
            [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
        return id.find("toliss") != std::string::npos;
    }();

    marker = XPLMFindDataRef(kMarker);
    char b[512]{};
    std::snprintf(b, sizeof(b), "aircraft='%s' path='%s'", file, path);
    log(b);
    std::snprintf(b, sizeof(b), "ToLiss path match=%s; marker %s; gate=%s",
        pathMatch ? "yes" : "no", marker ? "found" : "not found",
        (pathMatch || marker) ? "open" : "closed");
    log(b);
    std::snprintf(b, sizeof(b), "OBJ=%s; instance=%s; enabled=%s",
        object ? "loaded" : (tried ? "load failed/not loaded" : "not attempted"),
        instance ? "created" : "not created", cal.enabled ? "yes" : "no");
    log(b);

    if (refs.eyeX && refs.eyeY && refs.eyeZ) {
        const double ex = XPLMGetDataf(refs.eyeX);
        const double ey = XPLMGetDataf(refs.eyeY);
        const double ez = XPLMGetDataf(refs.eyeZ);
        std::snprintf(b, sizeof(b), "pilot eye reference (aircraft XYZ): %.3f %.3f %.3f m",
            ex, ey, ez);
        log(b);
        std::snprintf(b, sizeof(b), "combiner origin (aircraft XYZ): %.3f %.3f %.3f m",
            ex + cal.x, ey + cal.y, ez + cal.z);
        log(b);
    } else {
        log("Pilot-eye datarefs acf_peX/Y/Z are unavailable.");
    }
    printCal();
}

void destroy() {
    if (instance) {
        XPLMDestroyInstance(instance);
        instance = nullptr;
    }
}

bool findRefs() {
    if (!refs.x) refs.x = XPLMFindDataRef("sim/flightmodel/position/local_x");
    if (!refs.y) refs.y = XPLMFindDataRef("sim/flightmodel/position/local_y");
    if (!refs.z) refs.z = XPLMFindDataRef("sim/flightmodel/position/local_z");
    if (!refs.psi) refs.psi = XPLMFindDataRef("sim/flightmodel/position/psi");
    if (!refs.theta) refs.theta = XPLMFindDataRef("sim/flightmodel/position/theta");
    if (!refs.phi) refs.phi = XPLMFindDataRef("sim/flightmodel/position/phi");
    if (!refs.eyeX) refs.eyeX = XPLMFindDataRef("sim/aircraft/view/acf_peX");
    if (!refs.eyeY) refs.eyeY = XPLMFindDataRef("sim/aircraft/view/acf_peY");
    if (!refs.eyeZ) refs.eyeZ = XPLMFindDataRef("sim/aircraft/view/acf_peZ");

    return refs.x && refs.y && refs.z && refs.psi && refs.theta && refs.phi
        && refs.eyeX && refs.eyeY && refs.eyeZ;
}

bool isToLiss(float dt) {
    aircraftTimer += std::max(0.0f, dt);
    if (aircraftTimer >= 1.0f) {
        aircraftTimer = 0.0f;
        char file[256]{}, path[1024]{};
        getAircraftName(file, sizeof(file), path, sizeof(path));

        std::string id = std::string(file) + " " + path;
        std::transform(id.begin(), id.end(), id.begin(),
            [](unsigned char c) { return static_cast<char>(std::tolower(c)); });

        // Either signal is sufficient. Some aircraft/plugin combinations expose
        // the AirbusFBW marker later or under a different load sequence.
        marker = XPLMFindDataRef(kMarker);
        toliss = id.find("toliss") != std::string::npos || marker != nullptr;
    }
    return toliss;
}

bool createInstance() {
    if (!object || instance) return instance != nullptr;
    const char *none[] = {nullptr};
    instance = XPLMCreateInstance(object, none);
    if (!instance) log("XPLMCreateInstance failed; retrying.");
    else log("OBJ instance created.");
    return instance != nullptr;
}

void loadObject() {
    if (object || tried) return;
    tried = true;
    object = XPLMLoadObject(kObj);
    if (!object) {
        log(std::string("Unable to load OBJ: ") + kObj);
        return;
    }
    log(std::string("OBJ loaded: ") + kObj);
    if (!createInstance()) {
        XPLMUnloadObject(object);
        object = nullptr;
    }
}

void nudge(int action) {
    switch (action) {
        case 1: cal.x -= step; break; // left
        case 2: cal.x += step; break; // right
        case 3: cal.y -= step; break; // down
        case 4: cal.y += step; break; // up
        case 5: cal.z -= step; break; // forward (-Z)
        case 6: cal.z += step; break; // aft (+Z)
        case 7: cal.pitch -= angleStep; break;
        case 8: cal.pitch += angleStep; break;
        case 9: cal.heading -= angleStep; break;
        case 10: cal.heading += angleStep; break;
        case 11: cal.roll -= angleStep; break;
        case 12: cal.roll += angleStep; break;
        default: return;
    }
    cal.x = limit(cal.x, -2.0, 2.0);
    cal.y = limit(cal.y, -2.0, 2.0);
    cal.z = limit(cal.z, -5.0, 2.0);
    cal.pitch = limit(cal.pitch, -30.0, 30.0);
    cal.heading = limit(cal.heading, -30.0, 30.0);
    cal.roll = limit(cal.roll, -30.0, 30.0);
    printCal();
}

void handler(void *, void *ref) {
    int action = -1;
    for (int i = 0; i < 26; ++i) {
        if (ref == &tokens[i]) {
            action = i;
            break;
        }
    }
    if (action < 0) return;

    if (action == 20) {
        cal.enabled = !cal.enabled;
        if (!cal.enabled) destroy();
        log(cal.enabled ? "Hardware enabled" : "Hardware disabled");
    } else if (action == 21) {
        step = step < 0.02f ? 0.05f : 0.01f;
        log(step < 0.02f ? "Position step 1 cm" : "Position step 5 cm");
    } else if (action == 22) {
        saveConfig();
    } else if (action == 23) {
        cal = Cal{};
        printCal();
    } else if (action == 24) {
        printCal();
    } else if (action == 25) {
        printDiagnostics();
    } else {
        nudge(action);
    }
}

void add(const char *label, int action) {
    XPLMAppendMenuItem(menu, label, &tokens[action], 1);
}

void createMenu() {
    const auto parent = XPLMFindPluginsMenu();
    const int index = XPLMAppendMenuItem(parent, "XPHUD Native 3D", nullptr, 1);
    menu = XPLMCreateMenu("XPHUD Native 3D", parent, index, handler, nullptr);
    if (!menu) {
        log("Could not create calibration menu.");
        return;
    }
    add("Toggle hardware", 20);
    add("Toggle position step (1 / 5 cm)", 21);
    add("X left", 1);
    add("X right", 2);
    add("Y down", 3);
    add("Y up", 4);
    add("Z forward", 5);
    add("Z aft", 6);
    add("Pitch -0.5", 7);
    add("Pitch +0.5", 8);
    add("Yaw -0.5", 9);
    add("Yaw +0.5", 10);
    add("Roll -0.5", 11);
    add("Roll +0.5", 12);
    add("Print calibration to Log.txt", 24);
    add("Print diagnostics to Log.txt", 25);
    add("Save calibration", 22);
    add("Reset to eye-point preset", 23);
}

// Laminar Research aircraft-to-world Euler transform. Aircraft axes:
// +X right, +Y up, +Z aft. The equations match the published X-Plane
// aircraft-coordinate conversion; do not replace with a hand-rolled heading offset.
void toWorld(double x, double y, double z, double phi, double theta, double psi,
             double &X, double &Y, double &Z) {
    constexpr double pi = 3.14159265358979323846;
    const double p = phi * pi / 180.0;
    const double t = theta * pi / 180.0;
    const double h = psi * pi / 180.0;

    const double xp = x * std::cos(p) + y * std::sin(p);
    const double yp = y * std::cos(p) - x * std::sin(p);
    const double zp = z;
    const double xt = xp;
    const double yt = yp * std::cos(t) - zp * std::sin(t);
    const double zt = zp * std::cos(t) + yp * std::sin(t);

    X = xt * std::cos(h) - zt * std::sin(h) + XPLMGetDataf(refs.x);
    Y = yt + XPLMGetDataf(refs.y);
    Z = zt * std::cos(h) + xt * std::sin(h) + XPLMGetDataf(refs.z);
}

float flightLoop(float dt, float, int, void *) {
    if (!running) return 1.0f;
    if (!isToLiss(dt) || !cal.enabled) {
        destroy();
        return 1.0f;
    }
    if (!findRefs()) {
        destroy();
        if (!refsWarningLogged) {
            log("Required aircraft-position or acf_peX/Y/Z pilot-eye datarefs unavailable.");
            refsWarningLogged = true;
        }
        return 1.0f;
    }
    refsWarningLogged = false;

    if (!object && !tried) {
        retry += dt;
        if (retry >= 0.1f) loadObject();
    }
    if (!object && tried) {
        retry += dt;
        if (retry >= 5.0f) {
            retry = 0.0f;
            tried = false;
        }
        return 1.0f;
    }
    if (object && !instance && !createInstance()) return 1.0f;
    if (!instance) return 1.0f;

    const double aircraftX = XPLMGetDataf(refs.eyeX) + cal.x;
    const double aircraftY = XPLMGetDataf(refs.eyeY) + cal.y;
    const double aircraftZ = XPLMGetDataf(refs.eyeZ) + cal.z;

    const double phi = XPLMGetDataf(refs.phi);
    const double theta = XPLMGetDataf(refs.theta);
    const double psi = XPLMGetDataf(refs.psi);
    double x = 0.0, y = 0.0, z = 0.0;
    toWorld(aircraftX, aircraftY, aircraftZ, phi, theta, psi, x, y, z);

    XPLMDrawInfo_t draw{};
    draw.structSize = sizeof(draw);
    draw.x = static_cast<float>(x);
    draw.y = static_cast<float>(y);
    draw.z = static_cast<float>(z);
    draw.pitch = static_cast<float>(theta + cal.pitch);
    draw.heading = static_cast<float>(psi + cal.heading);
    draw.roll = static_cast<float>(phi + cal.roll);
    const float empty[1] = {0.0f};
    XPLMInstanceSetPosition(instance, &draw, empty);
    return -1.0f;
}

void stop() {
    XPLMUnregisterFlightLoopCallback(flightLoop, nullptr);
    destroy();
    if (object) {
        XPLMUnloadObject(object);
        object = nullptr;
    }
    tried = false;
    running = false;
}
} // namespace

PLUGIN_API int XPluginStart(char *name, char *signature, char *description) {
    std::snprintf(name, 256, "%s", "XPHUD Native 3D");
    std::snprintf(signature, 256, "%s", "controltwr.xphud.native3d");
    std::snprintf(description, 256, "%s",
        "Experimental ToLiss A32X combiner hardware prototype.");
    loadConfig();
    createMenu();
    log("Loaded. XYZ offsets are relative to the X-Plane pilot-eye reference; Lua remains a screen-space overlay.");
    return 1;
}

PLUGIN_API void XPluginStop(void) {
    stop();
    if (menu) {
        XPLMDestroyMenu(menu);
        menu = nullptr;
    }
}

PLUGIN_API int XPluginEnable(void) {
    running = true;
    tried = false;
    retry = 0.0f;
    aircraftTimer = 1.0f;
    toliss = false;
    refsWarningLogged = false;
    XPLMRegisterFlightLoopCallback(flightLoop, -1.0f, nullptr);
    log("Enabled.");
    return 1;
}

PLUGIN_API void XPluginDisable(void) {
    stop();
}

PLUGIN_API void XPluginReceiveMessage(XPLMPluginID, int, void *) {}
