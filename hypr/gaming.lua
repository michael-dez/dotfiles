-- bcpc -- rules for games played locally, on DP-3 (540Hz) or DP-1 (ultrawide).
--
-- Nothing here matches workspace 11, so none of it can reach a Moonlight
-- stream; the streaming equivalents live in stream.lua and are scoped to that
-- workspace for the same reason in reverse.

-- Keep the cursor inside the game. With a 540Hz panel beside a 3440-wide one,
-- a mouselook that runs off the edge onto the other monitor mid-fight is a real
-- hazard, and most games only half-manage the pointer lock themselves. This is
-- the wiki's documented answer.
hl.window_rule({
    name  = "local-game-pointer",
    match = { content = "game", fullscreen = true },

    confine_pointer = true,
})

-- No desktop chrome behind a fullscreen game. Cheaper than it looks: blur in
-- particular is a per-frame cost paid for something entirely hidden.
hl.window_rule({
    name  = "local-game-chrome",
    match = { content = "game", fullscreen = true },

    border_size = 0,
    rounding    = 0,
    no_blur     = true,
})

-- CAVEAT, verify before trusting: `content` comes from the Wayland content-type
-- protocol, and an XWayland game may never set it -- in which case both rules
-- above match nothing and are dead config rather than broken config. Check with
-- a game running:
--
--     hyprctl clients -j | jq '[.[] | {class, content}]'
--
-- If content reports "none" for the game, swap the match to a class pattern
-- (Proton titles are `steam_app_<id>`):
--
--     match = { class = "^steam_app_", fullscreen = true }
