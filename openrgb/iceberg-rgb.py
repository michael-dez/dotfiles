#!/usr/bin/env python3
# bcpc -- terminal-palette gradient across every OpenRGB device, as an SDK client.
#   ->  ~/.local/bin/iceberg-rgb  (run by iceberg-rgb.service)
# Design, colour handling, measured GPU I2C cost, why --save-profile needs the daemon stopped: docs/rgb.md

import argparse
import json
import math
import os
import re
import select
import signal
import socket
import struct
import subprocess
import sys
import time

# --- layout -----------------------------------------------------------------
# Front view, origin top-left, y down, ~cm. GPU_PATH waypoints are (LED index, x, y). Map: docs/rgb.md#iceberg-rgbpy
GPU_PATH = (
    (0, 3.0, -1.0), (6, 9.0, 3.0),                      # logo
    (7, 10.0, 4.0), (9.5, 16.0, 4.0), (17, 16.0, 22.0),  # loop: top, right
    (19.5, 10.0, 22.0), (29, 10.0, 4.0),                 # bottom, left
)
BOARD = (13.0, 26.0)
DRAM = dict(x=24.0, top=0.0, bottom=12.0)
# Terminal palette indices for the gradient stops, in order, looping back
# to the first. Iceberg's cool half: cyan -> blue -> lavender.
PALETTE = (6, 4, 5)

KITTY_THEMES = (
    "~/.config/kitty/themes/noctalia.conf",
    "~/.config/kitty/colors.conf",
)
# Iceberg, for when neither kitty file exists.
FALLBACK = {4: "#84a0c6", 5: "#a093c7", 6: "#89b8c2"}

# --- SDK protocol --------------------------------------------------------------
REQUEST_CONTROLLER_COUNT = 0
REQUEST_CONTROLLER_DATA = 1
REQUEST_PROTOCOL_VERSION = 40
SET_CLIENT_NAME = 50
DEVICE_LIST_UPDATED = 100
UPDATELEDS = 1050
UPDATESINGLELED = 1052
SETCUSTOMMODE = 1100

# The newest wire format this parser understands. The server answers with
# min(this, its own), so a newer server stays readable.
PROTOCOL = 4

DEVICE_TYPES = {0: "motherboard", 1: "dram", 2: "gpu", 6: "mouse", 10: "gamepad"}


class Reader:
    def __init__(self, buf):
        self.buf, self.pos = buf, 0

    def take(self, fmt):
        vals = struct.unpack_from("<" + fmt, self.buf, self.pos)
        self.pos += struct.calcsize("<" + fmt)
        return vals[0] if len(vals) == 1 else vals

    def string(self):
        n = self.take("H")
        s = self.buf[self.pos:self.pos + n].rstrip(b"\0").decode(errors="replace")
        self.pos += n
        return s


class Controller:
    def __init__(self, index, data, version):
        r = Reader(data)
        r.take("I")  # data size
        self.index = index
        self.type = DEVICE_TYPES.get(r.take("i"), "other")
        self.name = r.string()
        if version >= 1:
            r.string()  # vendor
        r.string()  # description
        r.string()  # version
        r.string()  # serial
        self.location = r.string()
        num_modes = r.take("H")
        r.take("i")  # active mode
        for _ in range(num_modes):
            r.string()
            # value, flags, speed min/max, [brightness min/max],
            # colors min/max, speed, [brightness], direction, color mode
            r.take("iIII" + ("II" if version >= 3 else "") + "III" + ("I" if version >= 3 else "") + "II")
            r.take("%dI" % r.take("H"))
        for _ in range(r.take("H")):
            r.string()
            r.take("iIII")  # type, leds min/max/count
            if r.take("H"):  # matrix map
                h, w = r.take("II")
                r.pos += 4 * h * w
            if version >= 4:
                for _ in range(r.take("H")):
                    r.string()
                    r.take("iII")
        self.num_leds = r.take("H")
        for _ in range(self.num_leds):
            r.string()
            r.take("I")
        r.take("%dI" % r.take("H"))  # current colors
        if r.pos != len(data):
            # A layout this parser does not know would otherwise surface as
            # wrong LED counts, not as an error.
            raise ValueError("controller %d: parsed %d of %d bytes" % (index, r.pos, len(data)))


class Client:
    def __init__(self, host, port, name):
        self.sock = socket.create_connection((host, port), timeout=10)
        self.sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self.list_changed = False
        self.send(SET_CLIENT_NAME, name.encode() + b"\0")
        self.send(REQUEST_PROTOCOL_VERSION, struct.pack("<I", PROTOCOL))
        self.version = min(PROTOCOL, struct.unpack("<I", self.wait(REQUEST_PROTOCOL_VERSION))[0])

    def send(self, packet, payload=b"", device=0):
        self.sock.sendall(b"ORGB" + struct.pack("<III", device, packet, len(payload)) + payload)

    def recv_exact(self, n):
        buf = b""
        while len(buf) < n:
            chunk = self.sock.recv(n - len(buf))
            if not chunk:
                raise ConnectionError("OpenRGB server closed the connection")
            buf += chunk
        return buf

    def recv(self):
        magic, device, packet, size = struct.unpack("<4sIII", self.recv_exact(16))
        if magic != b"ORGB":
            raise ConnectionError("bad packet magic %r" % magic)
        payload = self.recv_exact(size)
        if packet == DEVICE_LIST_UPDATED:
            self.list_changed = True
        return packet, payload

    def wait(self, packet):
        while True:
            got, payload = self.recv()
            if got == packet:
                return payload

    def poll(self):
        # The server pushes DEVICE_LIST_UPDATED unprompted (a controller
        # plugged in, or a rescan). Drain it without blocking the frame.
        while select.select([self.sock], [], [], 0)[0]:
            self.recv()

    def controllers(self):
        self.list_changed = False
        self.send(REQUEST_CONTROLLER_COUNT)
        count = struct.unpack("<I", self.wait(REQUEST_CONTROLLER_COUNT))[0]
        out = []
        for i in range(count):
            self.send(REQUEST_CONTROLLER_DATA, struct.pack("<I", self.version), device=i)
            out.append(Controller(i, self.wait(REQUEST_CONTROLLER_DATA), self.version))
        return out

    def direct(self, ctrl):
        self.send(SETCUSTOMMODE, device=ctrl.index)

    def update(self, ctrl, colors):
        body = struct.pack("<H", len(colors)) + b"".join(bytes((r, g, b, 0)) for r, g, b in colors)
        self.send(UPDATELEDS, struct.pack("<I", len(body) + 4) + body, device=ctrl.index)

    def update_one(self, ctrl, led, color):
        self.send(UPDATESINGLELED, struct.pack("<iBBBx", led, *color), device=ctrl.index)

    def sync(self):
        # A request/response pair proves the server has *read* everything
        # sent before it, and so updated its copy of each controller's
        # colours -- which is what a profile save captures. It says nothing
        # about the hardware: 1.0 writes that on per-device threads.
        self.send(REQUEST_CONTROLLER_COUNT)
        self.wait(REQUEST_CONTROLLER_COUNT)


# --- colour -----------------------------------------------------------------
def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def linear_to_oklab(r, g, b):
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = (math.copysign(abs(v) ** (1 / 3), v) for v in (l, m, s))
    return (
        0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    )


def oklab_to_linear(L, a, b):
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return (
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    )


def led_bytes(lab, brightness, saturation):
    L, a, b = lab
    rgb = [max(0.0, c) for c in oklab_to_linear(L, a * saturation, b * saturation)]
    peak = max(rgb) or 1.0
    return tuple(round(255 * brightness * c / peak) for c in rgb)


def dip(t, depth, at):
    """Brightness multiplier at t in [0, 1] between two stops.

    Full at both stops, darkest at `at`, easing in and out along a half
    cosine on each side so there is no visible corner. at=0.5 dims the blend
    between two colours; toward 1 each colour fades as it runs out, and the
    next one comes up quickly behind it.

    `depth` is in perceived brightness, not LED duty: OKLab lightness is
    roughly the cube root of light output, so the duty factor is cubed.
    Linear would barely register -- half duty reads as ~80% as bright.
    """
    if depth <= 0:
        return 1.0
    # Kept off the stops themselves: a trough at 0 or 1 is a hard edge.
    at = min(0.95, max(0.05, at))
    u = t / at if t < at else (1 - t) / (1 - at)
    return (1 - depth * (1 - math.cos(math.pi * u)) / 2) ** 3


def read_palette():
    for path in KITTY_THEMES:
        path = os.path.expanduser(path)
        try:
            with open(path) as f:
                text = f.read()
        except OSError:
            continue
        found = {int(n): h for n, h in re.findall(r"^\s*color(\d+)\s+(#[0-9a-fA-F]{6})", text, re.M)}
        if all(i in found for i in PALETTE):
            return path, [found[i] for i in PALETTE]
    return None, [FALLBACK[i] for i in PALETTE]


# 4096, not the 512 this started with: a 30 s cycle at 20 fps is 600
# frames, so 512 entries left a quarter of frames repeating the one before
# and the rest stepping on -- an uneven stutter, worst where --dim makes
# brightness change fastest. Now every frame moves by about 7 entries.
def build_lut(hexes, brightness, saturation, dim=0.0, dim_at=0.5, size=4096):
    labs = [linear_to_oklab(*(srgb_to_linear(int(h[i:i + 2], 16) / 255) for i in (1, 3, 5))) for h in hexes]
    lut = []
    for i in range(size):
        pos = i / size * len(labs)
        a, b = labs[int(pos)], labs[(int(pos) + 1) % len(labs)]
        # Smoothstep rather than linear: the eye reads a linear blend as
        # lingering on the midpoints and snapping through the stops.
        t = pos - int(pos)
        blend = t * t * (3 - 2 * t)
        lut.append(led_bytes(tuple(x + (y - x) * blend for x, y in zip(a, b)),
                             brightness * dip(t, dim, dim_at), saturation))
    return lut


# --- placement ----------------------------------------------------------------
def spread(n, lo, hi):
    return [lo + (hi - lo) * (i / (n - 1) if n > 1 else 0.5) for i in range(n)]


def along(path, i):
    for (i0, x0, y0), (i1, x1, y1) in zip(path, path[1:]):
        if i <= i1:
            t = min(1.0, max(0.0, (i - i0) / (i1 - i0)))
            return x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
    return path[-1][1:]


def place(ctrls):
    """(x, y) for every LED of every controller that joins the wave."""
    placed = {}
    for c in ctrls:
        if c.type == "gpu":
            placed[c.index] = [along(GPU_PATH, i) for i in range(c.num_leds)]
        elif c.type == "dram":
            placed[c.index] = [(DRAM["x"], y) for y in spread(c.num_leds, DRAM["top"], DRAM["bottom"])]
        elif c.type == "motherboard":
            placed[c.index] = [BOARD] * c.num_leds
    return placed


# --- main loop ------------------------------------------------------------------
# Roughly perceptual per channel: OKLab lightness goes as the cube root of
# light output, so a step from 4 to 8 counts for far more than 200 to 204.
PERCEIVED = [(v / 255) ** (1 / 3) for v in range(256)]


def lag(shown, target):
    return max(abs(PERCEIVED[a] - PERCEIVED[b]) for a, b in zip(shown, target))


def gaming():
    try:
        out = subprocess.run(
            ["busctl", "--user", "get-property", "com.feralinteractive.GameMode",
             "/com/feralinteractive/GameMode", "com.feralinteractive.GameMode", "ClientCount"],
            capture_output=True, text=True, timeout=2).stdout
        return int(out.split()[1]) > 0
    except (OSError, subprocess.SubprocessError, IndexError, ValueError):
        return False


class Wave:
    def __init__(self, args):
        self.args = args
        self.paused = False  # by signal
        self.gaming = False  # by gamemode
        self.palette_path, self.palette_mtime = None, None
        self.reload_palette()

    def reload_palette(self):
        path, hexes = read_palette()
        self.palette_path = path
        self.palette_mtime = os.stat(path).st_mtime if path else None
        self.lut = build_lut(hexes, self.args.brightness, self.args.saturation, self.args.dim, self.args.dim_at)
        print("palette %s from %s" % (" ".join(hexes), path or "built-in fallback"), flush=True)

    def palette_changed(self):
        path, _ = read_palette()
        try:
            mtime = os.stat(path).st_mtime if path else None
        except OSError:
            mtime = None
        return path != self.palette_path or mtime != self.palette_mtime

    def phases(self, placed):
        # Project onto the travel direction, in wavelengths. Tilting it up
        # off horizontal is what carries the wave from the GPU up the DIMMs,
        # LED 5 to LED 1, instead of giving each stick one flat colour.
        dx, dy = math.cos(math.radians(self.args.angle)), math.sin(math.radians(self.args.angle))
        return {i: [(x * dx + y * dy) / self.args.wavelength for x, y in pts] for i, pts in placed.items()}

    def colors(self, phases, t):
        n = len(self.lut)
        shift = t / self.args.period
        return [self.lut[int((p - shift) % 1.0 * n) % n] for p in phases]


def connect(args, deadline=None):
    while True:
        try:
            return Client(args.host, args.port, "iceberg-rgb")
        except OSError as e:
            if deadline is not None and time.monotonic() > deadline:
                raise
            print("waiting for OpenRGB server: %s" % e, flush=True)
            time.sleep(2)


def setup(client, wave):
    ctrls = client.controllers()
    placed = place(ctrls)
    for c in ctrls:
        if c.index in placed or c.type == "gamepad":
            client.direct(c)
        print("%-9s %2d LEDs  %s  %s" % (c.type, c.num_leds, "wave" if c.index in placed else
                                        "static" if c.type == "gamepad" else "skipped", c.name), flush=True)
    # The DualSense lightbar gets one colour, once. Steam drives the same
    # lightbar while a game has the controller; streaming frames at it would
    # flicker between the two, and cost battery over Bluetooth for nothing.
    for c in ctrls:
        if c.type == "gamepad":
            client.update(c, [wave.lut[0]] + [(0, 0, 0)] * (c.num_leds - 1))
    return ctrls, wave.phases(placed)


def settle(client, quiet=3.0):
    # A server that has just started is still detecting, announcing each
    # device as it lands. Saving then captures however many had arrived --
    # observed: the first save from the playbook came out with none at all.
    # SDK protocol 4 has no "detection complete" packet, so wait for the
    # announcements to stop. Bounded, so a server with nothing attached
    # falls through to check_profile's error rather than hanging the playbook.
    give_up = time.monotonic() + 60
    while True:
        client.list_changed = False
        end = time.monotonic() + quiet
        while time.monotonic() < end:
            client.poll()
            time.sleep(0.1)
        if not client.list_changed and (client.controllers() or time.monotonic() > give_up):
            return


def check_profile(name):
    path = os.path.expanduser("~/.config/OpenRGB/profiles/%s.json" % name)
    try:
        with open(path) as f:
            count = len(json.load(f).get("controllers", []))
    except (OSError, ValueError):
        count = 0
    if not count:
        # Left in place, an empty file would satisfy the playbook's
        # `creates:` guard and never be remade.
        if os.path.exists(path):
            os.remove(path)
        raise SystemExit("profile %s came out empty; removed it" % name)
    return path, count


def run(args):
    wave = Wave(args)
    signal.signal(signal.SIGUSR1, lambda *_: setattr(wave, "paused", True))
    signal.signal(signal.SIGUSR2, lambda *_: setattr(wave, "paused", False))
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))

    # A one-shot save is run by the playbook right after it starts the
    # server, so it waits a little for the port, but never forever.
    deadline = time.monotonic() + 30 if args.save_profile else None
    while True:
        client = connect(args, deadline)
        try:
            if args.save_profile:
                settle(client)
            ctrls, phases = setup(client, wave)
            by_index = {c.index: c for c in ctrls}
            if args.save_profile:
                for i, ph in phases.items():
                    client.update(by_index[i], wave.colors(ph, 0.0))
                client.sync()
                # The CLI autoconnects to the running server as its local
                # client and saves the server's live state, frame zero.
                subprocess.run(["openrgb", "--save-profile", args.save_profile], check=True, timeout=60,
                               stdout=subprocess.DEVNULL)
                print("saved profile %s: %s, %d devices" % ((args.save_profile,) + check_profile(args.save_profile)),
                      flush=True)
                return
            last = {}
            gpus = {i for i in phases if by_index[i].type == "gpu"}
            credit = 0.0
            # Check gamemode on the first pass, not 5 s in: restarted
            # mid-game, this must not light the GPU bus up even briefly.
            next_check = 0
            while True:
                now = time.monotonic()
                if not (wave.paused or wave.gaming):
                    # Whole writes only; the fraction carries to the next
                    # tick. Capped so a stall cannot bank a burst.
                    credit = min(credit + args.gpu_writes / args.fps, args.gpu_writes)
                    for i, ph in phases.items():
                        frame = wave.colors(ph, now)
                        if i not in gpus or i not in last:
                            # Everything else, and each GPU's first frame
                            # (nothing is known to be on it yet), in full.
                            if frame != last.get(i):
                                client.update(by_index[i], frame)
                                last[i] = frame
                            continue
                        shown = last[i]
                        behind = sorted(((lag(shown[k], frame[k]), k) for k in range(len(frame))), reverse=True)
                        for gap, k in behind[:int(credit)]:
                            if gap == 0:
                                break
                            client.update_one(by_index[i], k, frame[k])
                            shown[k] = frame[k]
                            credit -= 1
                client.poll()
                if client.list_changed:
                    print("device list changed, re-reading", flush=True)
                    break
                if now >= next_check:
                    next_check = now + 5
                    if wave.gaming != gaming():
                        wave.gaming = not wave.gaming
                        print("gamemode %s" % ("active, holding frame" if wave.gaming else "idle, resuming"), flush=True)
                    if wave.palette_changed():
                        wave.reload_palette()
                        last.clear()
                time.sleep(max(0.0, 1 / args.fps - (time.monotonic() - now)))
        except (OSError, ConnectionError, struct.error, ValueError) as e:
            if args.save_profile:
                raise
            print("lost OpenRGB server: %s" % e, flush=True)
            time.sleep(2)
        finally:
            client.sock.close()


def main():
    p = argparse.ArgumentParser(description="Terminal-palette gradient across every OpenRGB device.")
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--port", type=int, default=6742)
    p.add_argument("--fps", type=float, default=20, help="frame rate for everything but the GPU")
    p.add_argument("--gpu-writes", type=float, default=58,
                   help="GPU single-LED writes per second; 58 is ~12%% of a core, see header")
    p.add_argument("--period", type=float, default=30, help="seconds for the gradient to move one wavelength")
    p.add_argument("--wavelength", type=float, default=40, help="layout units per full palette cycle")
    p.add_argument("--angle", type=float, default=-20, help="travel direction in degrees; negative is upward")
    p.add_argument("--brightness", type=float, default=1.0, help="0-1")
    p.add_argument("--saturation", type=float, default=1.6, help="OKLab chroma multiplier")
    p.add_argument("--dim", type=float, default=0.0,
                   help="how far brightness dips between colours, 0 (off) to 1 (black)")
    p.add_argument("--dim-at", type=float, default=0.5,
                   help="where the dip bottoms out between two colours: 0.5 midway, toward 1 the end of each")
    p.add_argument("--save-profile", metavar="NAME", help="paint frame zero, save it as an OpenRGB profile, exit")
    run(p.parse_args())


if __name__ == "__main__":
    main()
