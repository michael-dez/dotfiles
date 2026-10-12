-- bcpc -- blur, dim, shadow, border colour, steam-game exemption.
-- steam_app_ class must be anchored at both ends. Why: docs/hyprland.md#decorationlua
local function mute(hex, factor)
    local r, g, b = hex:match("^#?(%x%x)(%x%x)(%x%x)$")
    assert(r, "mute(): expected #rrggbb, got " .. tostring(hex))

    local function scale(channel)
        return math.floor(tonumber(channel, 16) * factor + 0.5)
    end

    return ("rgb(%02x%02x%02x)"):format(scale(r), scale(g), scale(b))
end

local BORDER_BASE = "#84a0c6"
local BORDER_MUTE = 0.8            -- 20% less bright -> rgb(6a809e)

hl.config({
    general = {
        col = {
            active_border = mute(BORDER_BASE, BORDER_MUTE),
        },
    },

    decoration = {
        rounding = 6,

        dim_inactive = true,
        dim_strength = 0.15,

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

hl.window_rule({
    name  = "steam-game-chrome",
    match = { class = "^steam_app_.*$" },

    no_dim    = true,
    no_shadow = true,
    no_anim   = true,
})
