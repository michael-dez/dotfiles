-- bcpc -- Hyprland main config (Lua; fragments below are required last-wins).
-- Why allow_tearing, monitor fallback rule: docs/hyprland.md#hyprlandlua
hl.monitor({ output = "DP-3", mode = "1920x1080@539.56", position = "0x0",    scale = 1 })
hl.monitor({ output = "DP-1", mode = "3440x1440@179.99", position = "1920x0", scale = 1 })

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.workspace_rule({ workspace = "1", monitor = "DP-3", default = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-1", default = true })

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")

hl.config({
    misc = {
        vrr                   = 0,
        disable_hyprland_logo = true,
    },

    general = {
        gaps_in     = 4,
        gaps_out    = 8,
        border_size = 2,
        layout      = "dwindle",

        allow_tearing = true,
    },
})

hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("noctalia -d")
end)

require("decoration")   -- blur, dim, shadow, border colour, steam opt-out
require("animations")   -- curves and timings
require("bcpc")         -- host input + environment
require("gaming")       -- local play on DP-3 / DP-1
require("stream")       -- workspace 11, the headless output, Moonlight
require("keybinds")     -- binds last: they reference everything above
