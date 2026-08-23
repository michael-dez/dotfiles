-- bcpc -- blur and window decoration.
--
-- Hyprland's blur has no percentage scale: `size` is a radius in pixels and
-- `passes` is how many times it is applied. size 3 / passes 2 is a light blur.
-- `vibrancy` is the one genuinely 0-1 knob. Raise `size` for a heavier effect.
--
-- Terminal translucency lives in kitty.conf (background_opacity), not here --
-- a window-level opacity rule would dim the text as well as the background.

hl.config({
    decoration = {
        rounding = 6,

        blur = {
            enabled           = true,
            size              = 3,
            passes            = 2,
            vibrancy          = 0.17,
            new_optimizations = true,
        },
    },
})

-- No per-window rule is needed to turn blur ON. Hyprland blurs behind any
-- translucent surface whenever decoration.blur.enabled is true, so kitty gets
-- it purely from its own background_opacity. There is no positive `blur` rule --
-- only `no_blur`, to exempt a window. Example:
--
--     hl.window_rule({ match = { class = "^(steam)$" }, no_blur = true })
