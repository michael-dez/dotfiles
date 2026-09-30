#!/usr/bin/env python3
# bcpc -- terminal-palette gradient across every OpenRGB device.
#                              ->  ~/.local/bin/iceberg-rgb  (run by iceberg-rgb.service)
#
# A client of the OpenRGB SDK server (openrgb-server.service), not a plugin
# and not a profile. A profile is a snapshot: it can hold a gradient, but it
# cannot move one, and OpenRGB's own hardware modes run per device with no
# idea where the others are. So this places every LED at a physical position
# in the case and paints one colour field across all of them, drifting
# slowly left to right.
#
# The static profile is still made here -- `--save-profile Iceberg` paints
# frame zero and saves it -- because the server loads that profile at
# startup, which covers the window before this daemon connects and any time
# it is stopped. The save itself goes through the `openrgb` CLI: 1.0 honours
# SAVE_PROFILE only from its own local client and silently drops it from
# any other SDK client, this one included. Run it with the daemon stopped,
# or the daemon's next frame lands in the snapshot instead.
#
# Stdlib only. The SDK wire format is small enough that the AUR
# python-openrgb package would be a dependency for ~100 lines of struct
# packing, and it lags the server's protocol version anyway.
#
# --- colours -------------------------------------------------------------
# Read from kitty's generated theme, so they follow whatever palette
# Noctalia last applied (see the Noctalia comments in roles/bcpc/tasks/
# config.yml), and re-read when that file changes. Hex values are sRGB,
# meant for a screen; an LED's PWM duty is linear light. Feeding #84a0c6
# straight to an LED gives a near-white wash, so each stop is decoded to
# linear light, interpolated in OKLab (even-looking blends, no grey dip
# between hues), and scaled so its brightest channel is full on.
#
# --- cost ----------------------------------------------------------------
# This process is a table lookup per LED per frame -- noise. The cost is in
# the server, and it is almost all the GPU. Measured on bcpc by animating
# one device at a time and reading the server's CPU time from /proc:
#
#   DRAM x2, board, keyboard @ 20 fps   a few % of one core, all together
#                                       (keyboard since dropped, see below)
#   GPU @ 2 / 4 / 8 fps                 12% / 22% / 42%, nearly all kernel
#
# i.e. ~5% of a core per GPU frame per second. The card's LEDs sit on the
# NVIDIA driver's I2C adapter, where each of the 29 LEDs costs ~1.8 ms of
# busy kernel time per write. OpenRGB 1.0 queues writes on per-device
# threads, so the SDK gives no back-pressure and a round-trip cannot see
# any of this -- /proc/<pid>/stat is the only honest meter. Hence the GPU
# gets its own low frame rate (--gpu-fps), unchanged frames are never sent,
# and the whole thing freezes while gamemode has a client, so nothing
# touches the GPU's I2C bus while a game is running.
#
# gamemode is polled over D-Bus (ClientCount, ~6 ms a read, every 5 s)
# rather than driven by [custom] hooks in gamemode.ini. A hook only fires on
# the transition, so a daemon restarted mid-game would come back animating;
# a poll cannot miss the state. SIGUSR1 / SIGUSR2 still freeze and resume by
# hand, e.g. `systemctl --user kill -s USR1 iceberg-rgb`.

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
# Front view into the case, origin top-left, y pointing down, units roughly
# centimetres. Only relative positions matter: they decide which LEDs share
# a colour, and which way the gradient appears to travel.
#
#     logo                        ::  DIMMs. LED 1 is the top, the end
#        `-.                      ::  furthest from the GPU. The 0x73 stick
#           +--+                  ::  stands in front of the 0x71 one, so
#           |  |  GPU front,      ::  from here they overlap.
#           |  |  a loop of LEDs
#           +--+
#           [==]  chipset accent, directly beneath the GPU
#
# The GPU's 29 LEDs are one run in index order, mapped on the hardware with
# colour-block test patterns rather than taken from any datasheet: LEDs 0-6
# trace the logo toward the front of the card, then 7-28 go clockwise round
# the front from its top-left corner -- the top edge to about 9.5, the right
# edge to about 17, and back up the left side to where the loop started.
# Waypoints are (LED index, x, y); LEDs between two waypoints are spaced
# evenly along the line joining them.
GPU_PATH = (
    (0, 3.0, -1.0), (6, 9.0, 3.0),                      # logo
    (7, 10.0, 4.0), (9.5, 16.0, 4.0), (17, 16.0, 22.0),  # loop: top, right
    (19.5, 10.0, 22.0), (29, 10.0, 4.0),                 # bottom, left
)
BOARD = (13.0, 26.0)
DRAM = dict(x=24.0, top=0.0, bottom=12.0)
# No keyboard. The Wooting 60HE+ is fitted with switches that have no LED
# window, and OpenRGB driving its RGB interface is reported to clash with
# some of Wooting's own settings, so roles/bcpc/tasks/openrgb.yml turns its
# detector off and the server never sees it.

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


def build_lut(hexes, brightness, saturation, size=512):
    labs = [linear_to_oklab(*(srgb_to_linear(int(h[i:i + 2], 16) / 255) for i in (1, 3, 5))) for h in hexes]
    lut = []
    for i in range(size):
        pos = i / size * len(labs)
        a, b = labs[int(pos)], labs[(int(pos) + 1) % len(labs)]
        # Smoothstep rather than linear: the eye reads a linear blend as
        # lingering on the midpoints and snapping through the stops.
        t = pos - int(pos)
        t = t * t * (3 - 2 * t)
        lut.append(led_bytes(tuple(x + (y - x) * t for x, y in zip(a, b)), brightness, saturation))
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
        self.lut = build_lut(hexes, self.args.brightness, self.args.saturation)
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
            last, due = {}, {}
            interval = {i: 1 / (args.gpu_fps if by_index[i].type == "gpu" else args.fps) for i in phases}
            # Check gamemode on the first pass, not 5 s in: restarted
            # mid-game, this must not light the GPU bus up even briefly.
            next_check = 0
            while True:
                now = time.monotonic()
                if not (wave.paused or wave.gaming):
                    for i, ph in phases.items():
                        if now < due.get(i, 0):
                            continue
                        due[i] = now + interval[i]
                        # Sampled from the one wall clock, so a device on a
                        # lower frame rate steps along the same wave rather
                        # than lagging behind it.
                        frame = wave.colors(ph, now)
                        if frame != last.get(i):
                            client.update(by_index[i], frame)
                            last[i] = frame
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
    p.add_argument("--gpu-fps", type=float, default=2, help="GPU frame rate; ~5%% of a core each, see header")
    p.add_argument("--period", type=float, default=30, help="seconds for the gradient to move one wavelength")
    p.add_argument("--wavelength", type=float, default=40, help="layout units per full palette cycle")
    p.add_argument("--angle", type=float, default=-20, help="travel direction in degrees; negative is upward")
    p.add_argument("--brightness", type=float, default=1.0, help="0-1")
    p.add_argument("--saturation", type=float, default=1.6, help="OKLab chroma multiplier")
    p.add_argument("--save-profile", metavar="NAME", help="paint frame zero, save it as an OpenRGB profile, exit")
    run(p.parse_args())


if __name__ == "__main__":
    main()
