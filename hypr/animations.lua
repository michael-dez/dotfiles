-- bcpc -- animation curves and timings.
--
-- The target feel: motion that accelerates hard and then stops dead. Nothing
-- overshoots and nothing wobbles. So both springs below sit just above critical
-- damping, which for mass m and stiffness k is
--
--     dampening = 2 * sqrt(k * m)
--
-- Below that value a spring overshoots; at or above it settles without ever
-- crossing the target. Raising stiffness (and dampening with it) makes the
-- motion faster without making it bouncier.
--
-- `speed` is in ds (1ds = 100ms) and scales the whole curve, so it -- not the
-- spring constants -- is the knob to reach for if these feel too quick or slow.
--
-- Steam games are exempt via the `no_anim` rule in decoration.lua.

hl.config({
    animations = {
        enabled = true,
    },
})

-- --- curves ---------------------------------------------------------------
-- 2*sqrt(300) = 34.64, so dampening 35 is a hair overdamped: no overshoot.
hl.curve("settle", { type = "spring", mass = 1, stiffness = 300, dampening = 35 })
-- 2*sqrt(420) = 40.99. Stiffer, for motion the pointer is already driving.
hl.curve("snap",   { type = "spring", mass = 1, stiffness = 420, dampening = 41.5 })

-- Bezier points are the two *middle* control points; the endpoints are fixed
-- at {0,0} and {1,1}, so these read like their CSS cubic-bezier() equivalents.
-- `linear` is not defined here because Hyprland ships it built in.
hl.curve("easeOut",   { type = "bezier", points = { {0.22, 1}, {0.36, 1} } })  -- quintic, long settle
hl.curve("easeInOut", { type = "bezier", points = { {0.42, 0}, {0.58, 1} } })  -- symmetric

-- --- the tree -------------------------------------------------------------
-- Unset leaves inherit their parent, so `global` is the floor and everything
-- below only exists where that one uniform curve is the wrong answer.
hl.animation({ leaf = "global", enabled = true, speed = 4, bezier = "easeOut" })

-- Opening scales up from 92% under a spring; closing is a fast, nearly linear
-- shrink. The asymmetry is deliberate -- windows should arrive with some weight
-- and leave without ceremony -- so windowsOut runs at about half windowsIn.
hl.animation({ leaf = "windows",    enabled = true, speed = 3.2, spring = "snap" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 3.4, spring = "settle", style = "popin 92%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.8, bezier = "easeOut", style = "popin 95%" })

-- Fades are quick and mostly linear; a fade that eases is a fade you notice.
hl.animation({ leaf = "fade",       enabled = true, speed = 2.2, bezier = "easeOut" })
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 2.0, bezier = "easeOut" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 1.4, bezier = "linear" })
-- fadeSwitch/fadeShadow/fadeDim/border all fire on a focus change, so they share
-- a speed -- otherwise the border, the shadow and the dim settle at four
-- different moments and one focus change reads as four separate events.
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 1.8, bezier = "easeOut" })
hl.animation({ leaf = "fadeShadow", enabled = true, speed = 1.8, bezier = "easeOut" })
hl.animation({ leaf = "fadeDim",    enabled = true, speed = 1.8, bezier = "easeOut" })
hl.animation({ leaf = "border",     enabled = true, speed = 1.8, bezier = "easeOut" })

-- Layers are the Noctalia bar, the launcher and notifications. Chrome fades
-- rather than slides, so it does not compete with window motion for attention.
hl.animation({ leaf = "layers",        enabled = true, speed = 2.8, bezier = "easeOut" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 2.8, bezier = "easeOut", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.6, bezier = "linear",  style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 2.0, bezier = "easeOut" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.4, bezier = "linear" })

-- A flat horizontal slide on a symmetric ease, so the motion looks the same
-- going left as going right. Not a spring -- a spring across the whole desktop
-- makes the workspace feel like it is on a rubber band.
hl.animation({ leaf = "workspaces",       enabled = true, speed = 3.6, bezier = "easeInOut", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3.0, bezier = "easeOut",   style = "slidevert" })
