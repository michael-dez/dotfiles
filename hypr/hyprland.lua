-- bcpc -- Hyprland main config.
--
-- CachyOS has no cachyos-hyprland-settings package, so this file is ours rather
-- than an override on a shipped one. Host-specific fragments are require()d at
-- the bottom so they win over anything above.
--
-- Lua rather than hyprlang because upstream deprecated hyprlang in 0.55; every
-- wiki page now leads with that notice. Each require() is its own error scope,
-- so a mistake in one file does not take the whole config down with it.

-- --- monitors -------------------------------------------------------------
-- ZOWIE (540Hz, 1080p) on the LEFT, Alienware ultrawide on the RIGHT.
hl.monitor({ output = "DP-3", mode = "1920x1080@539.56", position = "0x0",    scale = 1 })
hl.monitor({ output = "DP-1", mode = "3440x1440@179.99", position = "1920x0", scale = 1 })

-- Empty output = the fallback, used only when no other rule matches. It does
-- not race the `sunshine` rule in stream.lua the way the equivalent hyprlang
-- line did, because matching is by specificity rather than by file order.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- Bind a workspace to each panel so windows have somewhere predictable to land.
hl.workspace_rule({ workspace = "1", monitor = "DP-3", default = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-1", default = true })

-- --- session --------------------------------------------------------------
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
    },
})

-- --- autostart ------------------------------------------------------------
-- The Lua equivalent of exec-once. hl.exec_cmd spawns asynchronously, so no
-- trailing `& disown` is needed.
hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("noctalia -d")
end)

-- --- fragments ------------------------------------------------------------
-- Last wins, so these override the defaults above. Paths resolve relative to
-- this file's directory (~/.config/hypr), and Lua's module lookup follows the
-- symlinks install.yml creates.
require("decoration")   -- blur, dim, shadow, border colour, steam opt-out
require("animations")   -- curves and timings
require("bcpc")         -- host input + environment
require("gaming")       -- local play on DP-3 / DP-1
require("stream")       -- workspace 11, the headless output, Moonlight
require("keybinds")     -- binds last: they reference everything above
