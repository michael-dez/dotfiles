-- Keybinds converted from i3/config. mod = Right Alt (MOD5, via lv3:ralt_switch in bcpc.lua).
-- Why, and the i3 bindings not converted: docs/hyprland.md#keybindslua
local mod = "MOD5"

hl.bind(mod .. " + Return", hl.dsp.exec_cmd("kitty"))                                  -- was xfce4-terminal
hl.bind(mod .. " + d",      hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"))     -- was rofi drun
hl.bind(mod .. " + w",      hl.dsp.exec_cmd("firefox"))
hl.bind(mod .. " + n",      hl.dsp.exec_cmd("thunar"))

hl.bind(mod .. " + q",         hl.dsp.window.close())
hl.bind(mod .. " + f",         hl.dsp.window.fullscreen({ mode = "fullscreen" }))

hl.bind(mod .. " + SHIFT + q", hl.dsp.window.kill())
hl.bind(mod .. " + SHIFT + space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + space",     hl.dsp.window.cycle_next())                             -- ~ focus mode_toggle

hl.bind(mod .. " + minus", hl.dsp.layout("preselect r"))    -- was split h
hl.bind(mod .. " + equal", hl.dsp.layout("preselect d"))    -- was split v
hl.bind(mod .. " + e",     hl.dsp.layout("togglesplit"))    -- was layout toggle split

hl.bind(mod .. " + s", hl.dsp.group.toggle())   -- was layout stacking
hl.bind(mod .. " + g", hl.dsp.group.next())     -- was layout tabbed

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

local stream = require("stream")

for _, w in ipairs(workspaces) do
    for _, key in ipairs({ w.row, w.kp_off, w.kp_on }) do
        hl.bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = w.ws }))
        hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = w.ws }))
        hl.bind(mod .. " + CTRL + " .. key,  function() stream.pull_workspace(w.ws) end)
    end
end

hl.bind(mod .. " + CTRL + k", hl.dsp.workspace.move({ monitor = "+1" }))
hl.bind(mod .. " + CTRL + j", hl.dsp.workspace.move({ monitor = "-1" }))

hl.bind(mod .. " + SHIFT + c", hl.dsp.exec_cmd("hyprctl reload"))   -- was i3 reload
hl.bind(mod .. " + SHIFT + e", hl.dsp.exec_cmd("wlogout"))          -- was scripts/powermenu
hl.bind(mod .. " + SHIFT + x", hl.dsp.exec_cmd("hyprlock"))         -- was Mod4+Shift+l blur-lock

hl.bind(mod .. " + SHIFT + s", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/sunshine/hooks/stream-end.sh"))

hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute   @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),    { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),    { locked = true, repeating = true })
hl.bind(mod .. " + XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%+"), { locked = true, repeating = true })
hl.bind(mod .. " + XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-"), { locked = true, repeating = true })

hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl pause"),      { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("ddcutil setvcp 10 + 5"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("ddcutil setvcp 10 - 5"), { locked = true, repeating = true })

hl.bind("Print",         hl.dsp.exec_cmd("grim ~/$(date +%Y-%m-%d-%H%M%S)-screenshot.png"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd('grim -g "$(slurp)" ~/$(date +%Y-%m-%d-%H%M%S)-screenshot.png'))

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

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

    hl.bind("Return", hl.dsp.submap("reset"))
    hl.bind("Escape", hl.dsp.submap("reset"))
end)
