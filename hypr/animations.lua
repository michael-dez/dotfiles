-- bcpc -- animation curves and timings (springs just above critical damping). docs/hyprland.md#animationslua
hl.config({
    animations = {
        enabled = true,
    },
})

hl.curve("settle", { type = "spring", mass = 1, stiffness = 300, dampening = 35 })
hl.curve("snap",   { type = "spring", mass = 1, stiffness = 420, dampening = 41.5 })

hl.curve("easeOut",   { type = "bezier", points = { {0.22, 1}, {0.36, 1} } })  -- quintic, long settle
hl.curve("easeInOut", { type = "bezier", points = { {0.42, 0}, {0.58, 1} } })  -- symmetric

hl.animation({ leaf = "global", enabled = true, speed = 4, bezier = "easeOut" })

hl.animation({ leaf = "windows",    enabled = true, speed = 3.2, spring = "snap" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 3.4, spring = "settle", style = "popin 92%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.8, bezier = "easeOut", style = "popin 95%" })

hl.animation({ leaf = "fade",       enabled = true, speed = 2.2, bezier = "easeOut" })
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 2.0, bezier = "easeOut" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 1.4, bezier = "linear" })
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 1.8, bezier = "easeOut" })
hl.animation({ leaf = "fadeShadow", enabled = true, speed = 1.8, bezier = "easeOut" })
hl.animation({ leaf = "fadeDim",    enabled = true, speed = 1.8, bezier = "easeOut" })
hl.animation({ leaf = "border",     enabled = true, speed = 1.8, bezier = "easeOut" })

hl.animation({ leaf = "layers",        enabled = true, speed = 2.8, bezier = "easeOut" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 2.8, bezier = "easeOut", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.6, bezier = "linear",  style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 2.0, bezier = "easeOut" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.4, bezier = "linear" })

hl.animation({ leaf = "workspaces",       enabled = true, speed = 3.6, bezier = "easeInOut", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3.0, bezier = "easeOut",   style = "slidevert" })
