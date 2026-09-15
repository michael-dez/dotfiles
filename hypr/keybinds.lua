-- Hyprland keybinds converted from i3/config.
--
-- i3 used $mod = Mod1 (Alt, either side). Here `mod` is RIGHT ALT only.
--
-- Hyprland modmasks cannot distinguish left from right, so bcpc.lua sets
-- kb_options=lv3:ralt_switch, which xkb maps Right Alt to ISO_Level3_Shift =
-- Mod5. Left Alt keeps working normally as ALT for application shortcuts.
-- Cost: Right Alt no longer types AltGr third-level characters.
--
-- Where a binding had no Wayland equivalent it is noted inline rather than
-- silently dropped. See the NOT CONVERTED section at the bottom.

local mod = "MOD5"

-- --- launch ---------------------------------------------------------------
hl.bind(mod .. " + Return", hl.dsp.exec_cmd("kitty"))                                  -- was xfce4-terminal
hl.bind(mod .. " + d",      hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"))     -- was rofi drun
hl.bind(mod .. " + w",      hl.dsp.exec_cmd("firefox"))
hl.bind(mod .. " + n",      hl.dsp.exec_cmd("thunar"))

-- --- window management ----------------------------------------------------
hl.bind(mod .. " + q",         hl.dsp.window.close())
hl.bind(mod .. " + f",         hl.dsp.window.fullscreen({ mode = "fullscreen" }))

-- Force-kill, for when MOD5+q above is being ignored. `close` is only a polite
-- request -- an xdg_toplevel close event, or WM_DELETE_WINDOW for an XWayland
-- client -- and a hung game never gets round to servicing it. `kill` is
-- forcekillactive: SIGKILL straight to the focused window's PID, verified by
-- dispatching it at a throwaway kitty and watching the shell report 137.
--
-- Scope note, so this is not mistaken for more of a safety net than it is: it
-- rescues a wedged *client*. It does nothing for a wedged *system*, because a
-- compositor short of memory or CPU cannot run the bind in the first place.
-- Alt+SysRq+F is the escape hatch for that case -- see system/99-sysrq.conf.
hl.bind(mod .. " + SHIFT + q", hl.dsp.window.kill())
hl.bind(mod .. " + SHIFT + space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + space",     hl.dsp.window.cycle_next())                             -- ~ focus mode_toggle

-- i3 split h/v -> dwindle keeps one toggle for the next split direction
hl.bind(mod .. " + minus", hl.dsp.layout("preselect r"))    -- was split h
hl.bind(mod .. " + equal", hl.dsp.layout("preselect d"))    -- was split v
hl.bind(mod .. " + e",     hl.dsp.layout("togglesplit"))    -- was layout toggle split

-- i3 stacking/tabbed -> Hyprland groups are the nearest native equivalent
hl.bind(mod .. " + s", hl.dsp.group.toggle())   -- was layout stacking
hl.bind(mod .. " + g", hl.dsp.group.next())     -- was layout tabbed

-- --- focus / move ---------------------------------------------------------
-- vim keys and arrows drive the same four directions, so build both from one
-- table rather than eight near-identical lines each.
local directions = {
    { keys = { "h", "Left" },  dir = "left"  },
    { keys = { "j", "Down" },  dir = "down"  },
    { keys = { "k", "Up" },    dir = "up"    },
    { keys = { "l", "Right" }, dir = "right" },
}

for _, d in ipairs(directions) do
    for _, key in ipairs(d.keys) do
        hl.bind(mod .. " + " .. key,           hl.dsp.focus({ direction = d.dir }))
        hl.bind(mod .. " + SHIFT + " .. key,   hl.dsp.window.move({ direction = d.dir }))
    end
end

-- --- workspaces -----------------------------------------------------------
-- Each workspace has three keys: the number row, the numpad with numlock OFF
-- (i3 reached these by bindcode), and the numpad with numlock ON (i3 used the
-- Mod2 duplicates). Workspace 10 sits on the 0 key.
local workspaces = {
    { ws = 1,  row = "1", kp_off = "KP_End",    kp_on = "KP_1" },
    { ws = 2,  row = "2", kp_off = "KP_Down",   kp_on = "KP_2" },
    { ws = 3,  row = "3", kp_off = "KP_Next",   kp_on = "KP_3" },
    { ws = 4,  row = "4", kp_off = "KP_Left",   kp_on = "KP_4" },
    { ws = 5,  row = "5", kp_off = "KP_Begin",  kp_on = "KP_5" },
    { ws = 6,  row = "6", kp_off = "KP_Right",  kp_on = "KP_6" },
    { ws = 7,  row = "7", kp_off = "KP_Home",   kp_on = "KP_7" },
    { ws = 8,  row = "8", kp_off = "KP_Up",     kp_on = "KP_8" },
    { ws = 9,  row = "9", kp_off = "KP_Prior",  kp_on = "KP_9" },
    { ws = 10, row = "0", kp_off = "KP_Insert", kp_on = "KP_0" },
}

-- CTRL is the stream's half of these: it brings workspace N *to* the virtual
-- output rather than sending focus away to the monitor that holds it. Without
-- it a desktop stream can only ever see workspace 11 -- focusing any other
-- workspace moves focus to a physical monitor, so the client goes on showing
-- workspace 11 while every keystroke lands in a window on the desk. See
-- pull_workspace() in stream.lua; off-stream it is a plain focus, which is what
-- these keys would otherwise have done.
--
-- `hl.bind` takes a Lua function, not only a dispatcher object, which is what
-- lets one binding decide between two behaviours at press time instead of
-- needing two keys.
local stream = require("stream")

for _, w in ipairs(workspaces) do
    for _, key in ipairs({ w.row, w.kp_off, w.kp_on }) do
        hl.bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = w.ws }))
        hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = w.ws }))
        hl.bind(mod .. " + CTRL + " .. key,  function() stream.pull_workspace(w.ws) end)
    end
end

-- --- multi-monitor --------------------------------------------------------
-- i3 had "move workspace to output next" / "... to output eDP". No eDP on a
-- desktop, so both directions are next/previous monitor instead.
hl.bind(mod .. " + CTRL + k", hl.dsp.workspace.move({ monitor = "+1" }))
hl.bind(mod .. " + CTRL + j", hl.dsp.workspace.move({ monitor = "-1" }))

-- --- session --------------------------------------------------------------
hl.bind(mod .. " + SHIFT + c", hl.dsp.exec_cmd("hyprctl reload"))   -- was i3 reload
hl.bind(mod .. " + SHIFT + e", hl.dsp.exec_cmd("wlogout"))          -- was scripts/powermenu
hl.bind(mod .. " + SHIFT + x", hl.dsp.exec_cmd("hyprlock"))         -- was Mod4+Shift+l blur-lock
                                                                    -- NOTE: moved off SHIFT+l,
                                                                    -- which is now "move right"

-- Escape hatch for a stranded Sunshine stream. If Moonlight dies without
-- disconnecting cleanly, Sunshine never fires its undo hook and the headless
-- "sunshine" output stays alive -- invisible, holding workspace 11 and anything
-- on it. This runs the teardown by hand. Safe to press when not streaming; the
-- hook is a no-op if the output is already gone, and it now says so in
-- ~/.local/state/sunshine-hooks.log either way.
hl.bind(mod .. " + SHIFT + s", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/sunshine/hooks/stream-end.sh"))

-- --- media ----------------------------------------------------------------
-- `locked` keeps these working over a lockscreen; `repeating` is the old
-- bindel "e" flag. Volume steps 5% bare, 1% with mod for fine adjustment.
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute   @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),    { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),    { locked = true, repeating = true })
hl.bind(mod .. " + XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%+"), { locked = true, repeating = true })
hl.bind(mod .. " + XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-"), { locked = true, repeating = true })

hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl pause"),      { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Monitor brightness over DDC/CI (desktop has no backlight, so not xbacklight)
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("ddcutil setvcp 10 + 5"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("ddcutil setvcp 10 - 5"), { locked = true, repeating = true })

-- --- screenshot -----------------------------------------------------------
hl.bind("Print",         hl.dsp.exec_cmd("grim ~/$(date +%Y-%m-%d-%H%M%S)-screenshot.png"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd('grim -g "$(slurp)" ~/$(date +%Y-%m-%d-%H%M%S)-screenshot.png'))

-- --- mouse ----------------------------------------------------------------
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- --- resize submap (i3 had this commented out; restored) ------------------
hl.bind(mod .. " + r", hl.dsp.submap("resize"))

hl.define_submap("resize", function()
    local steps = {
        { keys = { "h", "Left" },  x = -20, y = 0  },
        { keys = { "j", "Down" },  x = 0,   y = 20 },
        { keys = { "k", "Up" },    x = 0,   y = -20 },
        { keys = { "l", "Right" }, x = 20,  y = 0  },
    }

    for _, s in ipairs(steps) do
        for _, key in ipairs(s.keys) do
            hl.bind(key, hl.dsp.window.resize({ x = s.x, y = s.y, relative = true }), { repeating = true })
        end
    end

    -- Without one of these you are stuck in the submap; recover from a TTY with
    -- `hyprctl dispatch 'hl.dsp.submap("reset")'`.
    hl.bind("Return", hl.dsp.submap("reset"))
    hl.bind("Escape", hl.dsp.submap("reset"))
end)

-- --- NOT CONVERTED --------------------------------------------------------
-- $mod+Shift+r   i3 "restart in place" - no Hyprland equivalent; reload covers
--                config changes, and Hyprland cannot re-exec preserving layout.
-- $mod+a         "focus parent" - dwindle has no parent-focus concept.
-- $mod+Shift+n   scripts/empty_workspace - i3-specific (used i3-msg).
-- $mod+p         switch-audio-port - X11/i3blocks specific; use Noctalia's
--                audio panel or `wpctl set-default`.
-- $mod+Shift+p   scripts/power-profiles - rofi+X11; powerprofilesctl works but
--                the menu script does not.
-- F1             scripts/keyhint-2 - rendered an X11 image of this cheat sheet.
-- i3blocks pkill signals - i3blocks is not running; Noctalia owns the bar.
