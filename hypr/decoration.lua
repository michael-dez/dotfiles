-- bcpc -- blur, dim, shadow and border colour.
--
-- Hyprland's blur has no percentage scale: `size` is a radius in pixels and
-- `passes` is how many times it is applied. size 3 / passes 2 is a light blur.
-- `vibrancy` is the one genuinely 0-1 knob. Raise `size` for a heavier effect.
--
-- Terminal translucency lives in kitty.conf (background_opacity), not here --
-- a window-level opacity rule would dim the text as well as the background.

-- --- colour ---------------------------------------------------------------
-- Scale every channel of a "#rrggbb" by `factor` and return Hyprland's rgb()
-- form. Written as a function rather than a pasted-in hex so the muted value
-- follows the base: change BORDER_BASE and the border follows it down.
local function mute(hex, factor)
    local r, g, b = hex:match("^#?(%x%x)(%x%x)(%x%x)$")
    assert(r, "mute(): expected #rrggbb, got " .. tostring(hex))

    local function scale(channel)
        return math.floor(tonumber(channel, 16) * factor + 0.5)
    end

    return ("rgb(%02x%02x%02x)"):format(scale(r), scale(g), scale(b))
end

-- mPrimary from noctalia/palettes/Iceberg.json, which is also where kitty gets
-- its colours. Hardcoded rather than read from that file: it is JSON, Lua has
-- no bundled parser, and the palette changes about once a year.
--
-- Noctalia can generate this block itself -- see its `hyprland` builtin
-- template -- but noctalia/settings.toml enables only `kitty`, so nothing is
-- writing general.col at runtime and this is the sole owner of the value.
local BORDER_BASE = "#84a0c6"
local BORDER_MUTE = 0.8            -- 20% less bright -> rgb(6a809e)

hl.config({
    general = {
        col = {
            active_border = mute(BORDER_BASE, BORDER_MUTE),
            -- inactive_border deliberately left at Hyprland's 0xff444444. A
            -- neutral grey is what makes the muted blue still read as "this
            -- one is focused" at a glance.
        },
    },

    decoration = {
        rounding = 6,

        -- Dim is a brightness knock-back on every window that is not focused.
        -- 0.15 rather than Hyprland's 0.5 default: on a 3440-wide panel most of
        -- the screen is unfocused at any moment, and at 0.5 the desktop looks
        -- switched off. The easing of this is `fadeDim` in animations.lua.
        dim_inactive = true,
        dim_strength = 0.15,

        -- Shadows are on by default, but at range 4 with a near-black colour
        -- they are invisible against anything but a light wallpaper. Wide, soft
        -- and low-opacity reads better, pushed slightly downward so windows look
        -- lit from above.
        --
        -- render_power is a falloff exponent, 1-4, where *lower* is softer.
        -- range 20 is deliberately wider than gaps_out (8), so shadows fall
        -- across neighbouring windows rather than stopping inside the gap.
        shadow = {
            enabled        = true,
            range          = 20,
            render_power   = 2,
            offset         = { 0, 5 },
            color          = "rgba(00000059)",   -- ~35% black, focused
            color_inactive = "rgba(0000003d)",   -- ~24% black, everything else
        },

        blur = {
            enabled           = true,
            size              = 4,
            passes            = 2,
            vibrancy          = 0.17,
            new_optimizations = true,
        },
    },
})

-- --- steam games opt out --------------------------------------------------
-- Global on purpose: this is the only exemption that has to reach both local
-- play (gaming.lua, DP-3/DP-1) and a Moonlight stream (stream.lua, workspace
-- 11), so unlike those two files it is scoped to the game, not the display.
--
-- Two rules rather than one because `match` is an AND -- every prop in a single
-- match table must hold -- and the two ways to spot a game are alternatives:
--
--   content = "game"      the Wayland content-type protocol, which an XWayland
--                         title may never set (see the CAVEAT in gaming.lua)
--   class = "^steam_app_" what Steam names a Proton/XWayland title, which is
--                         exactly the case `content` tends to miss
--
-- `^steam$` -- the client's own library and store windows -- is deliberately
-- not here; those are desktop windows and should look like desktop windows.
--
-- no_anim covers the curves in animations.lua as well as anything set here.
-- Not exempted: the border colour, which is a global and has no per-window
-- "leave it alone" form. In practice a fullscreen game has no border to colour
-- (gaming.lua sets border_size = 0, stream.lua sets no_border), so only a
-- *windowed* Steam game sees the muted blue.
-- Each gets its own name because a name identifies a rule -- it is the handle
-- `set_enabled()` works through -- so two rules cannot share one.
for suffix, match in pairs({ content = { content = "game" },
                             class   = { class = "^steam_app_" } }) do
    hl.window_rule({
        name  = "steam-game-chrome-" .. suffix,
        match = match,

        no_dim    = true,
        no_shadow = true,
        no_anim   = true,
    })
end

-- No per-window rule is needed to turn blur ON. Hyprland blurs behind any
-- translucent surface whenever decoration.blur.enabled is true, so kitty gets
-- it purely from its own background_opacity. There is no positive `blur` rule --
-- only `no_blur`, to exempt a window. Example:
--
--     hl.window_rule({ match = { class = "^(steam)$" }, no_blur = true })
